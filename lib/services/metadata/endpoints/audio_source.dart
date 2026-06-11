import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/metadata/errors/safe_invoke.dart';

class MetadataPluginAudioSourceEndpoint {
  final Hetu hetu;
  MetadataPluginAudioSourceEndpoint(this.hetu);

  HTInstance get hetuMetadataAudioSource =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("audioSource")
          as HTInstance;

  List<SonolythAudioSourceContainerPreset> get supportedPresets {
    final raw = hetuMetadataAudioSource.memberGet("supportedPresets") as List;

    return raw
        .map((e) => SonolythAudioSourceContainerPreset.fromJson(e))
        .toList();
  }

  Future<List<SonolythAudioSourceMatchObject>> matches(
    SonolythFullTrackObject track,
  ) async {
    final raw = await hetuMetadataAudioSource
        .safeInvoke("matches", positionalArgs: [track.toJson()]) as List;

    return raw.map((e) => SonolythAudioSourceMatchObject.fromJson(e)).toList();
  }

  Future<List<SonolythAudioSourceStreamObject>> streams(
    SonolythAudioSourceMatchObject match,
  ) async {
    final raw = await hetuMetadataAudioSource
        .safeInvoke("streams", positionalArgs: [match.toJson()]) as List;

    return raw.map((e) => SonolythAudioSourceStreamObject.fromJson(e)).toList();
  }
}
