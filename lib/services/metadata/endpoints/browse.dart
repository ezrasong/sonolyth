import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/metadata/errors/safe_invoke.dart';

class MetadataPluginBrowseEndpoint {
  final Hetu hetu;
  MetadataPluginBrowseEndpoint(this.hetu);

  HTInstance get hetuMetadataBrowse =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("browse")
          as HTInstance;

  Future<SonolythPaginationResponseObject<SonolythBrowseSectionObject<Object>>>
      sections({
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataBrowse.safeInvoke(
      "sections",
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<
        SonolythBrowseSectionObject<Object>>.fromJson(
      raw.cast<String, dynamic>(),
      (Map json) => SonolythBrowseSectionObject<Object>.fromJson(
        json.cast<String, dynamic>(),
        (json) {
          final isPlaylist = json["owner"] != null;
          final isAlbum = json["artists"] != null;
          if (isPlaylist) {
            return SonolythSimplePlaylistObject.fromJson(
              json.cast<String, dynamic>(),
            );
          } else if (isAlbum) {
            return SonolythSimpleAlbumObject.fromJson(
              json.cast<String, dynamic>(),
            );
          } else {
            return SonolythFullArtistObject.fromJson(
              json.cast<String, dynamic>(),
            );
          }
        },
      ),
    );
  }

  Future<SonolythPaginationResponseObject<Object>> sectionItems(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataBrowse.safeInvoke(
      "sectionItems",
      positionalArgs: [id],
      namedArgs: {
        "offset": offset,
        "limit": limit,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<Object>.fromJson(
      raw.cast<String, dynamic>(),
      (json) {
        final isPlaylist = json["owner"] != null;
        final isAlbum = json["artists"] != null;
        if (isPlaylist) {
          return SonolythSimplePlaylistObject.fromJson(
            json.cast<String, dynamic>(),
          );
        } else if (isAlbum) {
          return SonolythSimpleAlbumObject.fromJson(
            json.cast<String, dynamic>(),
          );
        } else {
          return SonolythFullArtistObject.fromJson(
            json.cast<String, dynamic>(),
          );
        }
      },
    );
  }
}
