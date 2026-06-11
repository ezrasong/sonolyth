import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Namespaced disk cache for metadata-plugin JSON objects (album, artist,
/// playlist details...). Pages re-query the plugin on every visit otherwise,
/// which is slow and burns through Spotify's rate limit; entries here are
/// served until [maxAge] passes, and stale entries still work as a fallback
/// when the network or plugin errors out.
class MetadataObjectCache {
  static const _formatVersion = 1;

  static Future<File> _file(String namespace, String id) async {
    final dir = Directory(join(
      (await getApplicationSupportDirectory()).path,
      'metadata-cache',
      namespace,
    ));
    await dir.create(recursive: true);
    // Ids come from plugins; keep filenames safe.
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(join(dir.path, '$safeId.json'));
  }

  /// Returns the cached object, or null when absent, corrupt, or older than
  /// [maxAge] (pass null to accept any age, e.g. as an error fallback).
  static Future<Map<String, dynamic>?> read(
    String namespace,
    String id, {
    Duration? maxAge,
  }) async {
    try {
      final file = await _file(namespace, id);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['formatVersion'] != _formatVersion) return null;
      if (maxAge != null) {
        final cachedAt = DateTime.tryParse(json['cachedAt']?.toString() ?? '');
        if (cachedAt == null || DateTime.now().difference(cachedAt) > maxAge) {
          return null;
        }
      }
      return (json['data'] as Map).cast<String, dynamic>();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return null;
    }
  }

  static Future<void> write(
    String namespace,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final file = await _file(namespace, id);
      await file.writeAsString(jsonEncode({
        'formatVersion': _formatVersion,
        'cachedAt': DateTime.now().toIso8601String(),
        'data': data,
      }));
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  /// Drops a cached entry (e.g. after the user edits a playlist) so the next
  /// read fetches fresh data.
  static Future<void> evict(String namespace, String id) async {
    try {
      final file = await _file(namespace, id);
      if (await file.exists()) await file.delete();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  /// Cached-first fetch: serve a fresh-enough cache entry, otherwise fetch and
  /// persist, falling back to a stale entry when the fetch fails.
  static Future<T> fetchWithCache<T>({
    required String namespace,
    required String id,
    required Duration maxAge,
    required Future<T> Function() fetch,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
  }) async {
    final cached = await read(namespace, id, maxAge: maxAge);
    if (cached != null) return fromJson(cached);

    try {
      final fresh = await fetch();
      await write(namespace, id, toJson(fresh));
      return fresh;
    } catch (_) {
      final stale = await read(namespace, id);
      if (stale != null) return fromJson(stale);
      rethrow;
    }
  }
}
