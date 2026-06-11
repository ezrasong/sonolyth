import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/metadata/errors/safe_invoke.dart';

class MetadataPluginArtistEndpoint {
  final Hetu hetu;
  MetadataPluginArtistEndpoint(this.hetu);

  HTInstance get hetuMetadataArtist =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("artist")
          as HTInstance;

  Future<SonolythFullArtistObject> getArtist(String id) async {
    final raw = await hetuMetadataArtist
        .safeInvoke("getArtist", positionalArgs: [id]) as Map;

    return SonolythFullArtistObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythFullTrackObject>> topTracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataArtist.safeInvoke(
      "topTracks",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythFullTrackObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) => SonolythFullTrackObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythSimpleAlbumObject>> albums(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataArtist.safeInvoke(
      "albums",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythSimpleAlbumObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) => SonolythSimpleAlbumObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<void> save(List<String> ids) async {
    await hetuMetadataArtist.safeInvoke(
      "save",
      positionalArgs: [ids],
    );
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataArtist.safeInvoke(
      "unsave",
      positionalArgs: [ids],
    );
  }

  Future<SonolythPaginationResponseObject<SonolythFullArtistObject>> related(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataArtist.safeInvoke(
      "related",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit ?? 20,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythFullArtistObject>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) => SonolythFullArtistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }
}
