import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Spotify-style smart shuffle: shuffles the queue and mixes in
/// recommendations (top tracks of the artists already in the queue).
/// Toggling it off removes the injected tracks again.
class SmartShuffleNotifier extends Notifier<bool> {
  Set<String> _injectedTrackIds = {};

  @override
  bool build() => false;

  Future<void> enable() async {
    final playerState = ref.read(audioPlayerProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    final queueTracks =
        playerState.tracks.whereType<SonolythFullTrackObject>().toList();
    if (queueTracks.isEmpty) return;

    state = true;
    await audioPlayer.setShuffle(true);

    try {
      final plugin = await ref.read(metadataPluginProvider.future);
      if (plugin == null) return;

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
                  recommendations.every((r) => r.id != t.id),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }

      if (recommendations.isEmpty) return;

      recommendations.shuffle();
      final picked = recommendations.take(15).toList();
      _injectedTrackIds = picked.map((t) => t.id).toSet();
      await playerNotifier.addTracks(picked);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  Future<void> disable({bool keepShuffle = false}) async {
    state = false;
    if (_injectedTrackIds.isNotEmpty) {
      await ref
          .read(audioPlayerProvider.notifier)
          .removeTracks(_injectedTrackIds);
      _injectedTrackIds = {};
    }
    if (!keepShuffle) {
      await audioPlayer.setShuffle(false);
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
