import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
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
  Set<String> _injectedTrackIds = {};

  /// Everything ever suggested this session — never suggest the same track
  /// twice, even after it was played or removed.
  Set<String> _suggestedEver = {};

  StreamSubscription? _subscription;
  bool _fetching = false;

  /// Top up when fewer than this many tracks remain after the current one.
  static const _refillThreshold = 5;
  static const _initialBatch = 15;
  static const _refillBatch = 10;

  @override
  bool build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return false;
  }

  Future<void> enable() async {
    final queueTracks = ref
        .read(audioPlayerProvider)
        .tracks
        .whereType<SonolythFullTrackObject>()
        .toList();
    if (queueTracks.isEmpty) return;

    state = true;
    await audioPlayer.setShuffle(true);

    await _topUp(_initialBatch);

    _subscription?.cancel();
    _subscription = audioPlayer.playlistStream.listen((_) => _maybeTopUp());
  }

  Future<void> disable({bool keepShuffle = false}) async {
    state = false;
    _subscription?.cancel();
    _subscription = null;
    if (_injectedTrackIds.isNotEmpty) {
      await ref
          .read(audioPlayerProvider.notifier)
          .removeTracks(_injectedTrackIds);
      _injectedTrackIds = {};
    }
    _suggestedEver = {};
    if (!keepShuffle) {
      await audioPlayer.setShuffle(false);
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

/// Cycles shuffle off -> shuffle -> smart shuffle -> off, mirroring Spotify.
Future<void> cycleShuffleMode(WidgetRef ref) async {
  final shuffled = ref.read(audioPlayerProvider).shuffled;
  final smart = ref.read(smartShuffleProvider);
  final smartNotifier = ref.read(smartShuffleProvider.notifier);

  if (!shuffled && !smart) {
    await audioPlayer.setShuffle(true);
  } else if (shuffled && !smart) {
    await smartNotifier.enable();
  } else {
    await smartNotifier.disable();
  }
}
