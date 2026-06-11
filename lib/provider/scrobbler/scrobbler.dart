import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrobblenaut/scrobblenaut.dart';
import 'package:sonolyth/collections/env.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';

class ScrobblerNotifier extends AsyncNotifier<Scrobblenaut?> {
  /// Cap on the offline retry queue so it can't grow without bound during a
  /// long stretch without connectivity.
  static const _maxPendingScrobbles = 100;

  final StreamController<SonolythTrackObject> _scrobbleController =
      StreamController<SonolythTrackObject>.broadcast();

  Future<void> _submit(
    Scrobblenaut scrobbler,
    Map<String, dynamic> payload,
  ) async {
    await scrobbler.track.scrobble(
      artist: payload["artist"],
      track: payload["track"],
      album: payload["album"],
      chosenByUser: true,
      duration: Duration(milliseconds: payload["durationMs"]),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        payload["timestamp"],
        isUtc: true,
      ),
    );
  }

  /// Retries queued scrobbles in order; Last.fm accepts an explicit timestamp
  /// so late submissions still land at the time the track was actually
  /// played. Stops at the first failure (still offline) and keeps the rest.
  ///
  /// Concurrent callers share one in-flight flush — the startup flush and the
  /// scrobble-event flush both read-modify-write the same KVStore list, and
  /// overlapping runs would double-submit or resurrect already-sent entries.
  Future<void>? _flushInFlight;

  Future<void> _flushPending(Scrobblenaut scrobbler) {
    return _flushInFlight ??=
        _doFlushPending(scrobbler).whenComplete(() => _flushInFlight = null);
  }

  Future<void> _doFlushPending(Scrobblenaut scrobbler) async {
    final pending = KVStoreService.pendingScrobbles;
    if (pending.isEmpty) return;
    final remaining = [...pending];
    for (final raw in pending) {
      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        remaining.remove(raw); // corrupt entry — drop it
        continue;
      }
      try {
        await _submit(scrobbler, payload);
        remaining.remove(raw);
      } catch (_) {
        break;
      }
    }
    if (remaining.length != pending.length) {
      await KVStoreService.setPendingScrobbles(remaining);
    }
  }
  @override
  build() async {
    final database = ref.watch(databaseProvider);

    final loginInfo = await (database.select(database.scrobblerTable)
          ..where((t) => t.id.equals(0)))
        .getSingleOrNull();

    final subscription =
        database.select(database.scrobblerTable).watch().listen((event) async {
      try {
        if (event.isNotEmpty) {
          state = await AsyncValue.guard(
            () async => Scrobblenaut(
              lastFM: await LastFM.authenticateWithPasswordHash(
                apiKey: Env.lastFmApiKey,
                apiSecret: Env.lastFmApiSecret,
                username: event.first.username,
                passwordHash: event.first.passwordHash.value,
              ),
            ),
          );
        } else {
          state = const AsyncValue.data(null);
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });

    final scrobblerSubscription =
        _scrobbleController.stream.listen((track) async {
      final scrobbler = state.asData?.value;
      if (scrobbler == null) return;
      if (track.artists.isEmpty) return;
      final payload = <String, dynamic>{
        "artist": track.artists.first.name,
        "track": track.name,
        "album": track.album.name,
        "durationMs": track.durationMs,
        "timestamp": DateTime.now().toUtc().millisecondsSinceEpoch,
      };
      try {
        await _flushPending(scrobbler);
        await _submit(scrobbler, payload);
      } catch (e, stackTrace) {
        AppLogger.reportError(e, stackTrace);
        final pending = KVStoreService.pendingScrobbles;
        if (pending.length < _maxPendingScrobbles) {
          await KVStoreService.setPendingScrobbles(
            [...pending, jsonEncode(payload)],
          );
        }
      }
    });

    ref.onDispose(() {
      subscription.cancel();
      scrobblerSubscription.cancel();
    });

    if (loginInfo == null) {
      return null;
    }

    final scrobbler = Scrobblenaut(
      lastFM: await LastFM.authenticateWithPasswordHash(
        apiKey: Env.lastFmApiKey,
        apiSecret: Env.lastFmApiSecret,
        username: loginInfo.username,
        passwordHash: loginInfo.passwordHash.value,
      ),
    );
    // Anything that failed to submit last session can go out now.
    unawaited(
      _flushPending(scrobbler).catchError((e, stack) {
        AppLogger.reportError(e, stack);
      }),
    );
    return scrobbler;
  }

  Future<void> login(
    String username,
    String password,
  ) async {
    final database = ref.read(databaseProvider);

    final lastFm = await LastFM.authenticate(
      apiKey: Env.lastFmApiKey,
      apiSecret: Env.lastFmApiSecret,
      username: username,
      password: password,
    );

    if (!lastFm.isAuth) throw Exception("Invalid credentials");

    await database.into(database.scrobblerTable).insert(
          ScrobblerTableCompanion.insert(
            id: const Value(0),
            username: username,
            passwordHash: DecryptedText(lastFm.passwordHash!),
          ),
        );
  }

  Future<void> logout() async {
    state = const AsyncValue.data(null);
    final database = ref.read(databaseProvider);
    await database.delete(database.scrobblerTable).go();
  }

  void scrobble(SonolythTrackObject track) {
    _scrobbleController.add(track);
  }

  Future<void> love(SonolythTrackObject track) async {
    await state.asData?.value?.track.love(
      artist: track.artists.asString(),
      track: track.name,
    );
  }

  Future<void> unlove(SonolythTrackObject track) async {
    await state.asData?.value?.track.unLove(
      artist: track.artists.asString(),
      track: track.name,
    );
  }
}

final scrobblerProvider =
    AsyncNotifierProvider<ScrobblerNotifier, Scrobblenaut?>(
  () => ScrobblerNotifier(),
);
