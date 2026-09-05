import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/audio_player/silence_scanner.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Where a file's music actually starts and ends, once edge silence is
/// discounted.
typedef TrackTrim = ({Duration start, Duration end});

/// Registry of measured edge silence for local audio files.
///
/// Holds the measurements in memory (mirrored into [SonolythMedia.trimPoints],
/// which media construction reads synchronously) and schedules scans for files
/// that don't have one yet.
///
/// Scans run one at a time, in the background, and only against files already
/// on disk — the app never fetches bytes to measure a track.
class TrackTrimNotifier extends Notifier<Map<String, TrackTrim>> {
  final _scanned = <String>{};
  final _queue = <String>[];
  bool _scanning = false;

  @override
  Map<String, TrackTrim> build() {
    _load();
    return const {};
  }

  AppDatabase get _database => ref.read(databaseProvider);

  Future<void> _load() async {
    try {
      final rows = await _database.select(_database.trackTrimTable).get();
      final trims = <String, TrackTrim>{};
      final stale = <String>[];

      for (final row in rows) {
        final file = File(row.filePath);
        // A file that's gone (or was replaced by a different encode) can't be
        // described by this row any more.
        if (!file.existsSync() || await file.length() != row.fileSize) {
          stale.add(row.filePath);
          continue;
        }
        _scanned.add(row.filePath);
        final trim = _toTrim(row);
        if (trim != null) trims[row.filePath] = trim;
      }

      if (stale.isNotEmpty) {
        await (_database.delete(_database.trackTrimTable)
              ..where((t) => t.filePath.isIn(stale)))
            .go();
      }

      state = Map.unmodifiable(trims);
      _syncMediaTrims();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  TrackTrim? _toTrim(TrackTrimTableData row) {
    final duration = Duration(milliseconds: row.durationMs);
    final start = Duration(milliseconds: row.leadMs);
    final end = duration - Duration(milliseconds: row.tailMs);
    if (end <= start) return null;
    return (start: start, end: end);
  }

  /// Mirror into [SonolythMedia.trimPoints] so media construction (which is
  /// synchronous and riverpod-free) can apply the trims.
  void _syncMediaTrims() {
    SonolythMedia.trimPoints = state;
  }

  /// Queues [filePath] for measurement if it hasn't been measured yet.
  ///
  /// Safe to call repeatedly; already-measured and already-queued files are
  /// ignored. The scan is best effort — a file that fails to scan simply
  /// plays untrimmed.
  void scheduleScan(String filePath) {
    if (_scanned.contains(filePath) || _queue.contains(filePath)) return;
    _queue.add(filePath);
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    // One scan at a time: each spins up a second decoder, and this is
    // strictly background work that must not compete with playback.
    if (_scanning) return;
    _scanning = true;
    try {
      while (_queue.isNotEmpty) {
        final filePath = _queue.removeAt(0);
        if (_scanned.contains(filePath)) continue;
        await _scanOne(filePath);
      }
    } finally {
      _scanning = false;
    }
  }

  Future<void> _scanOne(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;
      final size = await file.length();

      final silence = await SilenceScanner.scan(filePath);
      _scanned.add(filePath);

      // Record even a null result, so a file with nothing to trim isn't
      // rescanned on every launch.
      final leadMs = silence?.lead.inMilliseconds ?? 0;
      final tailMs = silence?.tail.inMilliseconds ?? 0;
      final durationMs = silence?.duration.inMilliseconds ?? 0;

      await _database.into(_database.trackTrimTable).insertOnConflictUpdate(
            TrackTrimTableCompanion.insert(
              filePath: filePath,
              fileSize: size,
              durationMs: durationMs,
              leadMs: Value(leadMs),
              tailMs: Value(tailMs),
            ),
          );

      if (silence == null) return;

      final start = silence.lead;
      final end = silence.duration - silence.tail;
      if (end <= start) return;

      state = Map.unmodifiable({
        ...state,
        filePath: (start: start, end: end),
      });
      _syncMediaTrims();
      AppLogger.log.i(
        "[trim] ${silence.lead.inMilliseconds}ms lead / "
        "${silence.tail.inMilliseconds}ms tail — $filePath",
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }
}

final trackTrimProvider =
    NotifierProvider<TrackTrimNotifier, Map<String, TrackTrim>>(
  TrackTrimNotifier.new,
);
