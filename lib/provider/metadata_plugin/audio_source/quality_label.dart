import 'package:riverpod/riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:sonolyth/provider/server/active_track_sources.dart';
import 'package:sonolyth/provider/server/track_format_registry.dart';

final audioSourceQualityLabelProvider = Provider<String>((ref) {
  // Prefer the format of the stream ACTUALLY playing (e.g. "flac • 16bit •
  // 44.1kHz" for Qobuz/Tidal) over the configured preset — otherwise the player
  // always showed the YouTube preset ("mp4 • 256kbps") even on a lossless play.
  final liveLabel =
      ref.watch(activeTrackSourcesProvider).valueOrNull?.source?.qualityLabel;
  if (liveLabel != null) return liveLabel;

  // A file on disk is never a *source*, so the line above is null for every
  // local and downloaded track and the preset below used to answer for them:
  // the player named "flac • 16bit • 44.1kHz" over a WAV whose own row, three
  // taps away, read "0:30 | wav". The row has always taken the registry first
  // and the file extension second (`track_tile.dart`); this is the same
  // question with the same answer.
  final track = ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
  if (track != null) {
    final format =
        ref.watch(trackFormatRegistryProvider.select((f) => f[track.id])) ??
            switch (track) {
              SonolythLocalTrackObject(:final path) =>
                TrackFormat.fromPath(path),
              _ => switch (ref.watch(
                  downloadedTracksProvider.select((paths) => paths[track.id]),
                )) {
                  final String path => TrackFormat.fromPath(path),
                  null => null,
                },
            };
    if (format != null) return format.label;
  }

  // Fallback (nothing resolved and nothing on disk): the selected preset.
  final sourceQuality = ref.watch(audioSourcePresetsProvider);
  final sourceContainer = sourceQuality.presets
      .elementAtOrNull(sourceQuality.selectedStreamingContainerIndex);
  final quality = sourceContainer?.qualities
      .elementAtOrNull(sourceQuality.selectedStreamingQualityIndex);

  return "${sourceContainer?.name ?? "Unknown"} • ${quality?.toString() ?? "Unknown"}";
});
