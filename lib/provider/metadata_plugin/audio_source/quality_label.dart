import 'package:riverpod/riverpod.dart';
import 'package:sonolyth/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:sonolyth/provider/server/active_track_sources.dart';

final audioSourceQualityLabelProvider = Provider<String>((ref) {
  // Prefer the format of the stream ACTUALLY playing (e.g. "flac • 16bit •
  // 44.1kHz" for Qobuz/Tidal) over the configured preset — otherwise the player
  // always showed the YouTube preset ("mp4 • 256kbps") even on a lossless play.
  final liveLabel =
      ref.watch(activeTrackSourcesProvider).valueOrNull?.source?.qualityLabel;
  if (liveLabel != null) return liveLabel;

  // Fallback (track not resolved yet): the selected preset.
  final sourceQuality = ref.watch(audioSourcePresetsProvider);
  final sourceContainer = sourceQuality.presets
      .elementAtOrNull(sourceQuality.selectedStreamingContainerIndex);
  final quality = sourceContainer?.qualities
      .elementAtOrNull(sourceQuality.selectedStreamingQualityIndex);

  return "${sourceContainer?.name ?? "Unknown"} • ${quality?.toString() ?? "Unknown"}";
});
