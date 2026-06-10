import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Disk cache for playlist track listings so reopening a playlist (or
/// restarting the app) shows the full track list instantly while a
/// background refresh checks for changes.
abstract class PlaylistTracksCache {
  /// Bump to discard entries written by older builds (e.g. v2 invalidated
  /// listings cached before track durations were fixed).
  static const _formatVersion = 2;

  static Future<File> _file(String playlistId) async {
    final dir = Directory(join(
      (await getApplicationSupportDirectory()).path,
      'playlist-tracks-cache',
    ));
    await dir.create(recursive: true);
    return File(join(dir.path, '$playlistId.json'));
  }

  static Future<SonolythPaginationResponseObject<SonolythFullTrackObject>?> read(
    String playlistId,
  ) async {
    try {
      final file = await _file(playlistId);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      final map = (json as Map).cast<String, Object?>();
      if (map['cacheFormatVersion'] != _formatVersion) return null;
      return SonolythPaginationResponseObject.fromJson(
        map,
        (item) => SonolythFullTrackObject.fromJson(item),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return null;
    }
  }

  static Future<void> write(
    String playlistId,
    SonolythPaginationResponseObject<SonolythFullTrackObject> data,
  ) async {
    try {
      final file = await _file(playlistId);
      await file.writeAsString(
        jsonEncode({
          ...data.toJson((track) => track.toJson()),
          'cacheFormatVersion': _formatVersion,
        }),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }
}
