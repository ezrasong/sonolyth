import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/metadata/errors/safe_invoke.dart';

class MetadataPluginSearchEndpoint {
  final Hetu hetu;
  MetadataPluginSearchEndpoint(this.hetu);

  HTInstance get hetuMetadataSearch =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("search")
          as HTInstance;

  List<String> get chips {
    return (hetuMetadataSearch.memberGet("chips") as List).cast<String>();
  }

  Future<SonolythSearchResponseObject> all(String query) async {
    if (query.isEmpty) {
      return SonolythSearchResponseObject(
        albums: [],
        artists: [],
        playlists: [],
        tracks: [],
      );
    }

    final raw = await hetuMetadataSearch.safeInvoke(
      "all",
      positionalArgs: [query],
    ) as Map;

    return SonolythSearchResponseObject.fromJson(raw.cast<String, dynamic>());
  }

  Future<SonolythPaginationResponseObject<SonolythSimpleAlbumObject>> albums(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SonolythPaginationResponseObject<SonolythSimpleAlbumObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.safeInvoke(
      "albums",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythSimpleAlbumObject>.fromJson(
      raw.cast<String, dynamic>(),
      (json) => SonolythSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythFullArtistObject>> artists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SonolythPaginationResponseObject<SonolythFullArtistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.safeInvoke(
      "artists",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythFullArtistObject>.fromJson(
      raw.cast<String, dynamic>(),
      (json) => SonolythFullArtistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythSimplePlaylistObject>>
      playlists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SonolythPaginationResponseObject<SonolythSimplePlaylistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.safeInvoke(
      "playlists",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<
        SonolythSimplePlaylistObject>.fromJson(
      raw.cast<String, dynamic>(),
      (json) => SonolythSimplePlaylistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SonolythPaginationResponseObject<SonolythFullTrackObject>> tracks(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SonolythPaginationResponseObject<SonolythFullTrackObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.safeInvoke(
      "tracks",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    ) as Map;

    return SonolythPaginationResponseObject<SonolythFullTrackObject>.fromJson(
      raw.cast<String, dynamic>(),
      (json) => SonolythFullTrackObject.fromJson(json.cast<String, dynamic>()),
    );
  }
}
