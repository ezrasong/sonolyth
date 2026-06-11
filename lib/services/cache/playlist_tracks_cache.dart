import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Disk cache for full track listings (playlists, albums, artist top tracks)
/// so reopening a collection — or restarting the app — shows the tracks
/// instantly while any refresh happens in the background.
class TrackListingCache {
  /// Bump to discard entries written by older builds (e.g. v2 invalidated
  /// listings cached before track durations were fixed).
  static const _formatVersion = 2;

  /// Directory name under the app-support dir.
  final String namespace;

  const TrackListingCache(this.namespace);

  Future<File> _file(String id) async {
    final dir = Directory(join(
      (await getApplicationSupportDirectory()).path,
      namespace,
    ));
    await dir.create(recursive: true);
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(join(dir.path, '$safeId.json'));
  }

  Future<SonolythPaginationResponseObject<SonolythFullTrackObject>?> read(
    String id, {
    Duration? maxAge,
  }) async {
    try {
      final file = await _file(id);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      final map = (json as Map).cast<String, Object?>();
      if (map['cacheFormatVersion'] != _formatVersion) return null;
      if (maxAge != null) {
        final cachedAt = DateTime.tryParse(map['cachedAt']?.toString() ?? '');
        if (cachedAt == null || DateTime.now().difference(cachedAt) > maxAge) {
          return null;
        }
      }
      return SonolythPaginationResponseObject.fromJson(
        map,
        (item) => SonolythFullTrackObject.fromJson(item),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return null;
    }
  }

  Future<void> write(
    String id,
    SonolythPaginationResponseObject<SonolythFullTrackObject> data,
  ) async {
    try {
      final file = await _file(id);
      await file.writeAsString(
        jsonEncode({
          ...data.toJson((track) => track.toJson()),
          'cacheFormatVersion': _formatVersion,
          'cachedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }
}

/// Playlist listings: kept as a static API (and the original directory name)
/// for existing callers and previously cached data.
abstract class PlaylistTracksCache {
  static const _cache = TrackListingCache('playlist-tracks-cache');

  static Future<SonolythPaginationResponseObject<SonolythFullTrackObject>?>
      read(String playlistId) => _cache.read(playlistId);

  static Future<void> write(
    String playlistId,
    SonolythPaginationResponseObject<SonolythFullTrackObject> data,
  ) =>
      _cache.write(playlistId, data);
}
