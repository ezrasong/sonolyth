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
      return SonolythPaginationResponseObject.fromJson(
        (json as Map).cast<String, Object?>(),
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
        jsonEncode(data.toJson((track) => track.toJson())),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }
}
