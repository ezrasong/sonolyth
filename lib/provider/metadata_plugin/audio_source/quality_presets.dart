import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/metadata/metadata.dart';

part 'quality_presets.g.dart';
part 'quality_presets.freezed.dart';

@freezed
class AudioSourcePresetsState with _$AudioSourcePresetsState {
  factory AudioSourcePresetsState({
    @Default([]) final List<SonolythAudioSourceContainerPreset> presets,
    @Default(0) final int selectedStreamingQualityIndex,
    @Default(0) final int selectedStreamingContainerIndex,
    @Default(0) final int selectedDownloadingQualityIndex,
    @Default(0) final int selectedDownloadingContainerIndex,
  }) = _AudioSourcePresetsState;

  factory AudioSourcePresetsState.fromJson(Map<String, dynamic> json) =>
      _$AudioSourcePresetsStateFromJson(json);
}

/// The built-in preset list.
///
/// **This is not a convenience default — playback is broken without it.**
/// `presets` used to come exclusively from the audio-source *plugin*, and that
/// plugin was YouTube, which is gone. Every other path assumed a non-empty
/// list: `SourcedTrack.url` reads
/// `presets[selectedStreamingContainerIndex]` directly, so an empty list threw
/// `RangeError (length): Invalid value: Valid value range is empty: 0` on
/// **every single playback request**. The track resolved to FLAC, the server
/// was asked for its URL, and it blew up there — which presents as a track
/// that sits at 00:00 forever with no error anywhere in the UI.
///
/// Both native sources report `container: "flac"` (see
/// `qobuz_audio_source.dart` / `tidal_audio_source.dart`), so the name here
/// has to stay `"flac"` for `getStreamOfQuality`'s exact match to hit.
/// 16/44.1 is the floor both catalogs guarantee; higher-resolution streams
/// still play, since a quality miss falls back to the best available source
/// rather than rejecting it.
final kBuiltInLosslessPresets = <SonolythAudioSourceContainerPreset>[
  SonolythAudioSourceContainerPreset.lossless(
    type: SonolythMediaCompressionType.lossless,
    name: "flac",
    qualities: [
      SonolythAudioLosslessContainerQuality(bitDepth: 16, sampleRate: 44100),
    ],
  ),
];

class AudioSourceAvailableQualityPresetsNotifier
    extends Notifier<AudioSourcePresetsState> {
  @override
  build() {
    final audioSourceSnapshot = ref.watch(audioSourcePluginProvider);
    final audioSourceConfigSnapshot = ref.watch(
      metadataPluginsProvider.select((data) =>
          data.whenData((value) => value.defaultAudioSourcePluginConfig)),
    );

    _initialize(audioSourceSnapshot, audioSourceConfigSnapshot);

    listenSelf((previous, next) {
      final isNewLossless =
          next.presets.elementAtOrNull(next.selectedStreamingContainerIndex)
              is SonolythAudioSourceContainerPresetLossless;
      final isOldLossless = previous?.presets
              .elementAtOrNull(previous.selectedStreamingContainerIndex)
          is SonolythAudioSourceContainerPresetLossless;
      if (!isOldLossless && isNewLossless) {
        audioPlayer.setDemuxerBufferSize(6 * 1024 * 1024); // 6MB
      } else if (isOldLossless && !isNewLossless) {
        audioPlayer.setDemuxerBufferSize(4 * 1024 * 1024); // 4MB
      }
    });

    // Seed with the built-in list, NOT an empty one. `_initialize` is async,
    // and the very first playback request routinely lands before it finishes —
    // so an empty seed is a crash even when a plugin would eventually supply
    // presets.
    return AudioSourcePresetsState(presets: kBuiltInLosslessPresets);
  }

  void _initialize(
    AsyncValue<MetadataPlugin?> audioSourceSnapshot,
    AsyncValue<PluginConfiguration?> audioSourceConfigSnapshot,
  ) async {
    audioSourceConfigSnapshot.whenData((audioSourceConfig) {
      audioSourceSnapshot.whenData((audioSource) async {
        if (audioSource == null || audioSourceConfig == null) {
          // No audio-source plugin is the NORMAL state now — playback is
          // Qobuz→TIDAL and neither is a plugin. Keep the built-in presets.
          state = AudioSourcePresetsState(presets: kBuiltInLosslessPresets);
          return;
        }

        final preferences = await SharedPreferences.getInstance();
        final persistedStateStr =
            preferences.getString("audioSourceState-${audioSourceConfig.slug}");

        // A plugin that advertises nothing must not empty the list — see
        // `kBuiltInLosslessPresets` for what an empty list costs.
        final pluginPresets = audioSource.audioSource.supportedPresets;
        final presets =
            pluginPresets.isEmpty ? kBuiltInLosslessPresets : pluginPresets;

        if (persistedStateStr != null) {
          state = _withFlacDownloadDefaults(
            AudioSourcePresetsState.fromJson(jsonDecode(persistedStateStr))
                .copyWith(presets: presets),
          );
        } else {
          state = _withFlacDownloadDefaults(
            AudioSourcePresetsState(presets: presets),
          );
        }
      });
    });
  }

  AudioSourcePresetsState _withFlacDownloadDefaults(
    AudioSourcePresetsState next,
  ) {
    final selectedPreset =
        next.presets.elementAtOrNull(next.selectedDownloadingContainerIndex);
    final alreadyLossless =
        selectedPreset is SonolythAudioSourceContainerPresetLossless;
    if (alreadyLossless) return next;

    final flacIndex = next.presets
        .indexWhere((preset) => preset.name.toLowerCase() == "flac");
    final losslessIndex = next.presets.indexWhere(
      (preset) => preset is SonolythAudioSourceContainerPresetLossless,
    );
    final preferredIndex = flacIndex >= 0 ? flacIndex : losslessIndex;

    if (preferredIndex < 0) return next;

    return next.copyWith(
      selectedDownloadingContainerIndex: preferredIndex,
      selectedDownloadingQualityIndex: 0,
    );
  }

  void setSelectedStreamingContainerIndex(int index) {
    state = state.copyWith(
      selectedStreamingContainerIndex: index,
      selectedStreamingQualityIndex:
          0, // Resetting both because it's a different quality
    );
    _updatePreferences();
  }

  void setSelectedStreamingQualityIndex(int index) {
    state = state.copyWith(selectedStreamingQualityIndex: index);
    _updatePreferences();
  }

  void setSelectedDownloadingContainerIndex(int index) {
    state = state.copyWith(
      selectedDownloadingContainerIndex: index,
      selectedDownloadingQualityIndex:
          0, // Resetting both because it's a different quality
    );
    _updatePreferences();
  }

  void setSelectedDownloadingQualityIndex(int index) {
    state = state.copyWith(selectedDownloadingQualityIndex: index);
    _updatePreferences();
  }

  void _updatePreferences() async {
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));

    // Having no audio-source plugin is normal now, so persist under a fixed
    // key instead of throwing `noDefaultAudioSourcePlugin`. That throw was
    // written when YouTube was the only source; today it fires whenever
    // someone touches the streaming-quality selector.
    final slug = audioSourceConfig?.slug ?? "builtin-lossless";

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      "audioSourceState-$slug",
      jsonEncode(state),
    );
  }
}

final audioSourcePresetsProvider = NotifierProvider<
    AudioSourceAvailableQualityPresetsNotifier, AudioSourcePresetsState>(
  () => AudioSourceAvailableQualityPresetsNotifier(),
);
