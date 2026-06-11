import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/metadata/errors/safe_invoke.dart';

class MetadataPluginAlbumEndpoint {
  final Hetu hetu;
  MetadataPluginAlbumEndpoint(this.hetu);

  HTInstance get hetuMetadataAlbum =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("album")
          as HTInstance;

  Future<SonolythFullAlbumObject> getAlbum(String id) async {
    final raw =
        await hetuMetadataAlbum.safeInvoke("getAlbum", positionalArgs: [id]) as Map;

    return SonolythFullAlbumObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythFullTrackObject>> tracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataAlbum.safeInvoke(
      "tracks",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythFullTrackObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) =>
          SonolythFullTrackObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythSimpleAlbumObject>> releases({
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataAlbum.safeInvoke(
      "releases",
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythSimpleAlbumObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) =>
          SonolythSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<void> save(List<String> ids) async {
    await hetuMetadataAlbum.safeInvoke(
      "save",
      positionalArgs: [ids],
    );
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataAlbum.safeInvoke(
      "unsave",
      positionalArgs: [ids],
    );
  }
}
