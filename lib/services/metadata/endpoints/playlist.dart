import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/metadata/errors/safe_invoke.dart';

class MetadataPluginPlaylistEndpoint {
  final Hetu hetu;
  MetadataPluginPlaylistEndpoint(this.hetu);

  HTInstance get hetuMetadataPlaylist =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("playlist")
          as HTInstance;

  Future<SonolythFullPlaylistObject> getPlaylist(String id) async {
    final raw = await hetuMetadataPlaylist
        .safeInvoke("getPlaylist", positionalArgs: [id]) as Map;

    return SonolythFullPlaylistObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythFullTrackObject>> tracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    final raw = await hetuMetadataPlaylist.safeInvoke(
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

  Future<SonolythFullPlaylistObject?> create(
    String userId, {
    required String name,
    String? description,
    bool? public,
    bool? collaborative,
  }) async {
    final raw = await hetuMetadataPlaylist.safeInvoke(
      "create",
      positionalArgs: [userId],
      namedArgs: {
        "name": name,
        "description": description,
        "public": public,
        "collaborative": collaborative,
      }..removeWhere((key, value) => value == null),
    ) as Map?;

    if (raw == null) return null;

    return SonolythFullPlaylistObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<void> update(
    String playlistId, {
    String? name,
    String? description,
    bool? public,
    bool? collaborative,
  }) async {
    await hetuMetadataPlaylist.safeInvoke(
      "update",
      positionalArgs: [playlistId],
      namedArgs: {
        "name": name,
        "description": description,
        "public": public,
        "collaborative": collaborative,
      }..removeWhere((key, value) => value == null),
    );
  }

  Future<void> addTracks(
    String playlistId, {
    required List<String> trackIds,
    int? position,
  }) async {
    await hetuMetadataPlaylist.safeInvoke(
      "addTracks",
      positionalArgs: [playlistId],
      namedArgs: {
        "trackIds": trackIds,
        "position": position,
      }..removeWhere((key, value) => value == null),
    );
  }

  Future<void> removeTracks(
    String playlistId, {
    required List<String> trackIds,
  }) async {
    await hetuMetadataPlaylist.safeInvoke(
      "removeTracks",
      positionalArgs: [playlistId],
      namedArgs: {
        "trackIds": trackIds,
      }..removeWhere((key, value) => value == null),
    );
  }

  Future<void> save(String playlistId) async {
    await hetuMetadataPlaylist.safeInvoke(
      "save",
      positionalArgs: [playlistId],
    );
  }

  Future<void> unsave(String playlistId) async {
    await hetuMetadataPlaylist.safeInvoke(
      "unsave",
      positionalArgs: [playlistId],
    );
  }

  Future<void> deletePlaylist(String playlistId) async {
    return await hetuMetadataPlaylist.safeInvoke(
      "deletePlaylist",
      positionalArgs: [playlistId],
    );
  }
}
