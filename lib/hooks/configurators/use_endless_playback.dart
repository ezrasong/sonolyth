import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

void useEndlessPlayback(WidgetRef ref) {
  final playback = ref.watch(audioPlayerProvider.notifier);
  final audioPlayerState = ref.watch(audioPlayerProvider);
  final endlessPlayback =
      ref.watch(userPreferencesProvider.select((s) => s.endlessPlayback));
  final metadataPlugin = ref.watch(metadataPluginProvider.future);

  useEffect(
    () {
      if (!endlessPlayback) return null;

      void listener(int index) async {
        try {
          final playlist = ref.read(audioPlayerProvider);
          // An empty queue makes `length - 1` == -1, which the index can
          // legitimately equal when playback stops or the queue is cleared —
          // `.last` then threw "Bad state: No element".
          if (playlist.tracks.isEmpty) return;
          if (index != playlist.tracks.length - 1) return;

          final track = playlist.tracks.last;
          // A local file has no provider id to seed a radio from; asking the
          // metadata plugin threw every time such a queue neared its end.
          if (track is SonolythLocalTrackObject) return;

          final tracks = await (await metadataPlugin)?.track.radio(track.id);

          if (tracks == null || tracks.isEmpty) return;

          await playback.addTracks(
            tracks.toList()
              ..removeWhere((e) {
                final playlist = ref.read(audioPlayerProvider);
                final isDuplicate = playlist.tracks.any((t) => t.id == e.id);
                return e.id == track.id || isDuplicate;
              }),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }

      // Sometimes user can change settings for which the currentIndexChanged
      // might not be called. So we need to check if the current track is the
      // last track and if it is then we need to call the listener manually.
      if (audioPlayerState.tracks.isNotEmpty &&
          audioPlayerState.currentIndex == audioPlayerState.tracks.length - 1 &&
          audioPlayer.isPlaying) {
        listener(audioPlayerState.currentIndex);
      }

      final subscription =
          audioPlayer.currentIndexChangedStream.listen(listener);

      return subscription.cancel;
    },
    [
      metadataPlugin,
      playback,
      audioPlayerState.tracks,
      audioPlayerState.currentIndex,
      endlessPlayback,
    ],
  );
}
