import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/metadata/errors/safe_invoke.dart';

class MetadataPluginTrackEndpoint {
  final Hetu hetu;
  MetadataPluginTrackEndpoint(this.hetu);

  HTInstance get hetuMetadataTrack =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("track")
          as HTInstance;

  Future<SonolythFullTrackObject> getTrack(String id) async {
    final raw =
        await hetuMetadataTrack.safeInvoke("getTrack", positionalArgs: [id]) as Map;

    return SonolythFullTrackObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<void> save(List<String> ids) async {
    await hetuMetadataTrack.safeInvoke("save", positionalArgs: [ids]);
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataTrack.safeInvoke("unsave", positionalArgs: [ids]);
  }

  Future<List<SonolythFullTrackObject>> radio(String id) async {
    final result = await hetuMetadataTrack.safeInvoke(
      "radio",
      positionalArgs: [id],
    );

    return (result as List)
        .map(
          (e) => SonolythFullTrackObject.fromJson(
            (e as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }
}
