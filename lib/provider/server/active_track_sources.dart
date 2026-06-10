import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/sourced_track/sourced_track.dart';

final activeTrackSourcesProvider = FutureProvider<
    ({
      SourcedTrack? source,
      SourcedTrackNotifier? notifier,
      SonolythTrackObject track,
    })?>((ref) async {
  final audioPlayerState = ref.watch(audioPlayerProvider);

  if (audioPlayerState.activeTrack == null) {
    return null;
  }

  if (audioPlayerState.activeTrack is SonolythLocalTrackObject) {
    return (
      source: null,
      notifier: null,
      track: audioPlayerState.activeTrack!,
    );
  }

  final sourcedTrack = await ref.watch(
    sourcedTrackProvider(
      audioPlayerState.activeTrack! as SonolythFullTrackObject,
    ).future,
  );
  final sourcedTrackNotifier = ref.watch(
    sourcedTrackProvider(
      audioPlayerState.activeTrack! as SonolythFullTrackObject,
    ).notifier,
  );

  return (
    source: sourcedTrack,
    track: audioPlayerState.activeTrack!,
    notifier: sourcedTrackNotifier,
  );
});
