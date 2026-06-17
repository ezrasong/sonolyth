import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Spotify-style smart shuffle: shuffles the queue and continuously mixes in
/// recommendations (top tracks of the artists in the queue — including the
/// artists that arrive via earlier recommendations, so the pool drifts
/// organically). While enabled, the queue is topped up whenever playback
/// gets close to the end. Toggling it off removes the injected tracks.
class SmartShuffleNotifier extends Notifier<bool> {
  static const _prefsKey = "smart-shuffle-enabled";

  Set<String> _injectedTrackIds = {};

  /// Everything ever suggested this session — never suggest the same track
  /// twice, even after it was played or removed.
  Set<String> _suggestedEver = {};

  StreamSubscription? _subscription;
  StreamSubscription? _shuffleSubscription;
  Timer? _disableDebounce;
  bool _fetching = false;

  /// Guards the "follow shuffle out of smart shuffle" auto-disable so the
  /// transient `shuffle=false` mpv emits while a queue is (re)opened can't tear
  /// smart shuffle down before the saved shuffle mode is re-applied. We only
  /// react to shuffle being turned OFF once we've actually seen it ON while
  /// smart shuffle was enabled.
  bool _armed = false;

  /// Top up when fewer than this many tracks remain after the current one.
  static const _refillThreshold = 5;
  static const _initialBatch = 15;
  static const _refillBatch = 10;

  @override
  bool build() {
    // Shuffle can be switched off from places that don't know about smart
    // shuffle (Bluetooth/Android Auto setShuffleMode, the tray menu, the
    // collection page shuffle toggle). Smart shuffle without shuffle makes no
    // sense, so follow the player out of it. But opening/restoring a queue
    // flips shuffle off-then-on within milliseconds (mpv's open() resets it
    // before load() re-applies the sticky mode), so don't react to the bare
    // edge: debounce, then disable only if shuffle is GENUINELY still off.
    _shuffleSubscription = audioPlayer.shuffledStream.listen((shuffled) {
      if (shuffled) {
        _armed = true;
        _disableDebounce?.cancel();
      } else if (state && _armed) {
        _disableDebounce?.cancel();
        _disableDebounce = Timer(const Duration(milliseconds: 600), () {
          if (state && !ref.read(audioPlayerProvider).shuffled) disable();
        });
      }
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _shuffleSubscription?.cancel();
      _disableDebounce?.cancel();
    });
    // Smart shuffle is a sticky mode like Spotify's: restore it across restarts
    // so it survives an app kill instead of silently reverting to plain
    // shuffle. The restore is async (prefs) and deliberately does NOT inject a
    // fresh batch — the restored queue already has tracks; the threshold top-up
    // resumes naturally as playback advances.
    _restore();
    return false;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsKey) != true) return;
      // Already past restore: a real toggle happened first — don't clobber it.
      if (state) return;
      state = true;
      _armed = ref.read(audioPlayerProvider).shuffled;
      _subscription?.cancel();
      _subscription = audioPlayer.playlistStream.listen((_) => _maybeTopUp());
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  /// Mirror the injected-track set into [smartShuffleInjectedIdsProvider] so the
  /// queue UI can mark which tracks are recommendations vs. real queue tracks.
  void _syncInjected() {
    ref
        .read(smartShuffleInjectedIdsProvider.notifier)
        .update(_injectedTrackIds.toSet());
  }

  Future<void> _persist(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  Future<void> enable() async {
    final queueTracks = ref
        .read(audioPlayerProvider)
        .tracks
        .whereType<SonolythFullTrackObject>()
        .toList();
    if (queueTracks.isEmpty) return;

    state = true;
    unawaited(_persist(true));
    await audioPlayer.setShuffle(true);
    // Shuffle is now on by our own hand — arm the auto-disable so a later
    // user-initiated unshuffle still tears smart shuffle down.
    _armed = true;

    _subscription?.cancel();
    _subscription = audioPlayer.playlistStream.listen((_) => _maybeTopUp());

    // Recommendations arrive in the background — the toggle (and the media
    // notification button) must not hang on four top-tracks fetches.
    unawaited(_topUp(_initialBatch));
  }

  Future<void> disable({bool keepShuffle = false}) async {
    state = false;
    _armed = false;
    unawaited(_persist(false));
    _subscription?.cancel();
    _subscription = null;
    if (_injectedTrackIds.isNotEmpty) {
      // Keep whatever is currently playing, even if it was one of ours —
      // yanking the active track mid-listen is worse than leaving one
      // recommendation behind (Spotify does the same).
      final activeId = ref.read(audioPlayerProvider).activeTrack?.id;
      await ref
          .read(audioPlayerProvider.notifier)
          .removeTracks(_injectedTrackIds.where((id) => id != activeId));
      _injectedTrackIds = {};
      _syncInjected();
    }
    _suggestedEver = {};
    if (!keepShuffle) {
      await audioPlayer.setShuffle(false);
    }
  }

  /// Cycles shuffle off -> shuffle -> smart shuffle -> off, mirroring
  /// Spotify. Used by the in-app shuffle buttons and the media-notification
  /// shuffle button.
  Future<void> cycle() async {
    final shuffled = ref.read(audioPlayerProvider).shuffled;

    if (!shuffled && !state) {
      await audioPlayer.setShuffle(true);
    } else if (shuffled && !state) {
      await enable();
      // Smart shuffle can be unavailable (local-only queue, nothing playing).
      // Without this the cycle would jam at "shuffle on" forever — complete
      // it to "off" instead.
      if (!state) await audioPlayer.setShuffle(false);
    } else {
      await disable();
    }
  }

  Future<void> _maybeTopUp() async {
    if (!state || _fetching) return;

    final playerState = ref.read(audioPlayerProvider);
    final remaining =
        playerState.tracks.length - (playerState.currentIndex + 1);
    if (remaining >= _refillThreshold) return;

    await _topUp(_refillBatch);
  }

  Future<void> _topUp(int count) async {
    if (_fetching) return;
    _fetching = true;
    try {
      final plugin = await ref.read(metadataPluginProvider.future);
      if (plugin == null) return;

      final playerState = ref.read(audioPlayerProvider);
      final queueTracks =
          playerState.tracks.whereType<SonolythFullTrackObject>().toList();
      if (queueTracks.isEmpty) return;

      final existingIds = playerState.tracks.map((t) => t.id).toSet();
      // The queue may have been replaced (a new playlist was loaded) since
      // the last top-up; injected tracks that are gone must not be "removed"
      // again on disable, where the id could now belong to a track the new
      // queue legitimately contains.
      _injectedTrackIds.removeWhere((id) => !existingIds.contains(id));
      _syncInjected();
      final artistIds = queueTracks
          .expand((t) => t.artists.map((a) => a.id))
          .toSet()
          .toList()
        ..shuffle();

      final recommendations = <SonolythFullTrackObject>[];
      for (final artistId in artistIds.take(4)) {
        try {
          final topTracks = await plugin.artist.topTracks(artistId);
          recommendations.addAll(
            topTracks.items.where(
              (t) =>
                  !existingIds.contains(t.id) &&
                  !_suggestedEver.contains(t.id) &&
                  recommendations.every((r) => r.id != t.id),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
        if (recommendations.length >= count * 2) break;
      }

      if (recommendations.isEmpty || !state) return;

      recommendations.shuffle();
      final picked = recommendations.take(count).toList();
      _injectedTrackIds.addAll(picked.map((t) => t.id));
      _suggestedEver.addAll(picked.map((t) => t.id));
      _syncInjected();
      await ref.read(audioPlayerProvider.notifier).addTracks(picked);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    } finally {
      _fetching = false;
    }
  }
}

final smartShuffleProvider = NotifierProvider<SmartShuffleNotifier, bool>(
  SmartShuffleNotifier.new,
);

/// Track ids currently injected as smart-shuffle recommendations — i.e. NOT
/// part of the original queue/playlist. The queue UI watches this to mark
/// recommendations distinctly from the playlist's own tracks. Empty when smart
/// shuffle is off.
final smartShuffleInjectedIdsProvider =
    NotifierProvider<SmartShuffleInjectedIdsNotifier, Set<String>>(
  SmartShuffleInjectedIdsNotifier.new,
);

class SmartShuffleInjectedIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void update(Set<String> ids) => state = ids;
}

/// Cycles shuffle off -> shuffle -> smart shuffle -> off, mirroring Spotify.
Future<void> cycleShuffleMode(WidgetRef ref) =>
    ref.read(smartShuffleProvider.notifier).cycle();
