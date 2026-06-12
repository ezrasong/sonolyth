import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Disk cache for the user's saved-playlists listing so the Library tab
/// renders instantly on open and keeps showing the last good list when a
/// refresh fails (rate limit, flaky network) instead of erroring out.
abstract class SavedPlaylistsCache {
  static const _formatVersion = 1;

  static Future<File> _file() async {
    final dir = Directory(join(
      (await getApplicationSupportDirectory()).path,
      'library-listings-cache',
    ));
    await dir.create(recursive: true);
    return File(join(dir.path, 'saved-playlists.json'));
  }

  static Future<
      SonolythPaginationResponseObject<SonolythSimplePlaylistObject>?>
      read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      final map = (json as Map).cast<String, Object?>();
      if (map['cacheFormatVersion'] != _formatVersion) return null;
      return SonolythPaginationResponseObject.fromJson(
        map,
        (item) => SonolythSimplePlaylistObject.fromJson(item),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return null;
    }
  }

  static Future<void> write(
    SonolythPaginationResponseObject<SonolythSimplePlaylistObject> data,
  ) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          ...data.toJson((playlist) => playlist.toJson()),
          'cacheFormatVersion': _formatVersion,
        }),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }
}
