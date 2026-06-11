import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Persistent registry of natively downloaded tracks (track id -> file path).
///
/// The download queue itself is in-memory only, so without this registry a
/// track downloaded in a previous session (or before a playlist download was
/// stopped partway) would show as not-downloaded and play the online stream
/// instead of the local file.
class DownloadedTracksNotifier extends Notifier<Map<String, String>> {
  static const _formatVersion = 1;

  bool _loaded = false;

  @override
  Map<String, String> build() {
    _load();
    return {};
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(path.join(dir.path, 'downloaded-tracks.json'));
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['formatVersion'] != _formatVersion) return;
      final tracks = (json['tracks'] as Map).cast<String, String>();
      // Drop entries whose files were deleted outside the app.
      tracks.removeWhere((_, filePath) => !File(filePath).existsSync());
      state = Map.unmodifiable(tracks);
      _syncMediaPaths();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  /// Chains persists so overlapping add/remove calls can't interleave writes
  /// to the same file.
  Future<void> _persistChain = Future.value();

  Future<void> _persist() {
    return _persistChain = _persistChain.then((_) async {
      try {
        final file = await _file();
        // Temp-file + rename keeps the write atomic: a crash mid-write must
        // not corrupt the registry, or every downloaded track is forgotten.
        final tmp = File("${file.path}.tmp");
        await tmp.writeAsString(
          jsonEncode({
            'formatVersion': _formatVersion,
            'tracks': state,
          }),
          flush: true,
        );
        await tmp.rename(file.path);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  /// Mirror the registry into [SonolythMedia.downloadedPaths] so media
  /// construction (which is synchronous and riverpod-free) can prefer the
  /// local file over the streaming server URL.
  void _syncMediaPaths() {
    SonolythMedia.downloadedPaths = state;
  }

  void add(String trackId, String filePath) {
    state = Map.unmodifiable({...state, trackId: filePath});
    _syncMediaPaths();
    _persist();
  }

  void remove(String trackId) {
    if (!state.containsKey(trackId)) return;
    state = Map.unmodifiable({...state}..remove(trackId));
    _syncMediaPaths();
    _persist();
  }

  /// Path of the downloaded file for [trackId], or null when not downloaded
  /// (or the file has been deleted since, in which case the stale entry is
  /// dropped).
  String? pathFor(String? trackId) {
    final filePath = state[trackId];
    if (filePath == null) return null;
    if (!File(filePath).existsSync()) {
      remove(trackId!);
      return null;
    }
    return filePath;
  }

  bool isDownloaded(String? trackId) => pathFor(trackId) != null;
}

final downloadedTracksProvider =
    NotifierProvider<DownloadedTracksNotifier, Map<String, String>>(
  DownloadedTracksNotifier.new,
);
