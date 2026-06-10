import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';

class MetadataPluginTrackEndpoint {
  final Hetu hetu;
  MetadataPluginTrackEndpoint(this.hetu);

  HTInstance get hetuMetadataTrack =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("track")
          as HTInstance;

  Future<SonolythFullTrackObject> getTrack(String id) async {
    final raw =
        await hetuMetadataTrack.invoke("getTrack", positionalArgs: [id]) as Map;

    return SonolythFullTrackObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<void> save(List<String> ids) async {
    await hetuMetadataTrack.invoke("save", positionalArgs: [ids]);
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataTrack.invoke("unsave", positionalArgs: [ids]);
  }

  Future<List<SonolythFullTrackObject>> radio(String id) async {
    final result = await hetuMetadataTrack.invoke(
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
