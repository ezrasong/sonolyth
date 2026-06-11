import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/provider/spotiflac/download_settings.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/provider/youtube_engine/youtube_engine.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/spotiflac/native_flac_downloader.dart';
import 'package:sonolyth/services/spotiflac/providers/youtube_provider.dart';

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  canceled,
}

/// Fixed scale pushed onto [DownloadTask.downloadedBytesStream]; the UI divides
/// by [DownloadTask.totalSizeBytes] to get a 0..1 ratio, and the native
/// downloader reports fractional progress rather than byte counts.
const _progressScale = 1000000;

class DownloadTask {
  final SonolythFullTrackObject track;
  final DownloadStatus status;
  final CancelToken cancelToken;
  final int? totalSizeBytes;

  /// Human-readable failure reason, set when [status] is
  /// [DownloadStatus.failed] so the UI can say why instead of a bare icon.
  final String? errorMessage;
  final StreamController<int> _downloadedBytesStreamController;

  Stream<int> get downloadedBytesStream =>
      _downloadedBytesStreamController.stream;

  DownloadTask({
    required this.track,
    required this.status,
    required this.cancelToken,
    this.totalSizeBytes,
    this.errorMessage,
    StreamController<int>? downloadedBytesStreamController,
  }) : _downloadedBytesStreamController =
            downloadedBytesStreamController ?? StreamController.broadcast();

  DownloadTask copyWith({
    SonolythFullTrackObject? track,
    DownloadStatus? status,
    CancelToken? cancelToken,
    int? totalSizeBytes,
    String? errorMessage,
    bool clearError = false,
    StreamController<int>? downloadedBytesStreamController,
  }) {
    return DownloadTask(
      track: track ?? this.track,
      status: status ?? this.status,
      cancelToken: cancelToken ?? this.cancelToken,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      downloadedBytesStreamController:
          downloadedBytesStreamController ?? _downloadedBytesStreamController,
    );
  }
}

class DownloadManagerNotifier extends Notifier<List<DownloadTask>> {
  @override
  build() {
    ref.onDispose(() {
      for (final task in state) {
        if (task.status == DownloadStatus.downloading) {
          task.cancelToken.cancel();
        }
        task._downloadedBytesStreamController.close();
      }
    });

    return [];
  }

  DownloadTask? getTaskByTrackId(String trackId) {
    return state.firstWhereOrNull((element) => element.track.id == trackId);
  }

  /// Tracks already on disk (from this or a previous session) are skipped so
  /// re-downloading a playlist after stopping partway only fetches the rest.
  bool _alreadyDownloaded(SonolythFullTrackObject track) {
    return ref
        .read(downloadedTracksProvider.notifier)
        .isDownloaded(track.id);
  }

  void addToQueue(SonolythFullTrackObject track) {
    if (state.any((element) => element.track.id == track.id)) return;
    if (_alreadyDownloaded(track)) return;
    state = [
      ...state,
      DownloadTask(
        track: track,
        status: DownloadStatus.queued,
        cancelToken: CancelToken(),
        totalSizeBytes: _progressScale,
      ),
    ];

    _startDownloading(); // No await should be invoked to avoid stuck UI
  }

  void addAllToQueue(
    List<SonolythFullTrackObject> tracks, {
    String? collectionUrl,
  }) {
    final queuedTrackIds = state.map((task) => task.track.id).toSet();
    final newTracks = tracks
        .where((track) =>
            !queuedTrackIds.contains(track.id) && !_alreadyDownloaded(track))
        .toList();
    if (newTracks.isEmpty) return;

    state = [
      ...state,
      ...newTracks.map((e) => DownloadTask(
            track: e,
            status: DownloadStatus.queued,
            cancelToken: CancelToken(),
            totalSizeBytes: _progressScale,
          )),
    ];

    _startDownloading(); // No await should be invoked to avoid stuck UI
  }

  void retry(SonolythFullTrackObject track) {
    if (state.firstWhereOrNull((e) => e.track.id == track.id)?.status
        case DownloadStatus.canceled || DownloadStatus.failed) {
      _setStatus(track, DownloadStatus.queued);
      _startDownloading(); // No await should be invoked to avoid stuck UI
    }
  }

  void cancel(SonolythFullTrackObject track) {
    final task = state.firstWhereOrNull((e) => e.track.id == track.id);
    if (task == null || task.status == DownloadStatus.failed) return;
    if (task.status == DownloadStatus.downloading &&
        !task.cancelToken.isCancelled) {
      task.cancelToken.cancel();
    }
    _setStatus(track, DownloadStatus.canceled);
  }

  void clearAll() {
    for (final task in state) {
      if (task.status == DownloadStatus.downloading) {
        task.cancelToken.cancel();
      }
    }
    state = [];
  }

  void _setStatus(
    SonolythFullTrackObject track,
    DownloadStatus status, {
    String? error,
  }) {
    state = state.map((e) {
      if (e.track.id == track.id) {
        // A re-queued task needs a fresh cancel token; the old one may have
        // been cancelled on a prior failed/cancelled attempt.
        if (status == DownloadStatus.queued && e.cancelToken.isCancelled) {
          return e.copyWith(
            status: status,
            cancelToken: CancelToken(),
            clearError: true,
          );
        }
        return e.copyWith(
          status: status,
          errorMessage: error,
          clearError: error == null && status != DownloadStatus.failed,
        );
      }
      return e;
    }).toList();
  }

  void _emitProgress(SonolythFullTrackObject track, double progress) {
    final task = state.firstWhereOrNull((e) => e.track.id == track.id);
    if (task == null || task._downloadedBytesStreamController.isClosed) return;
    task._downloadedBytesStreamController
        .add((progress.clamp(0, 1) * _progressScale).toInt());
  }

  Future<void> _downloadTrack(DownloadTask task) async {
    try {
      _setStatus(task.track, DownloadStatus.downloading);
      final task0 = state.firstWhereOrNull((e) => e.track.id == task.track.id);
      if (task0 == null) return;
      if (task0.cancelToken.isCancelled) {
        _setStatus(task.track, DownloadStatus.canceled);
        return;
      }

      final settings = await ref.read(spotiFlacDownloadSettingsProvider.future);
      // The YouTube fallback needs the active engine, which is Riverpod-scoped
      // (depends on the user's chosen client engine), so inject it here.
      final youtubeEngine = ref.read(youtubeEngineProvider);
      final providers = settings.enabledProviders
          .map((p) =>
              p is YouTubeProvider ? YouTubeProvider(engine: youtubeEngine) : p)
          .toList();
      final downloadLocation =
          ref.read(userPreferencesProvider).downloadLocation;

      final filePath = await nativeFlacDownloader.download(
        track: task.track,
        providers: providers,
        downloadDirectory: downloadLocation,
        qualityByProvider: settings.qualityByProvider,
        cancelToken: task0.cancelToken,
        onProgress: (progress) => _emitProgress(task.track, progress),
      );

      ref.read(downloadedTracksProvider.notifier).add(task.track.id, filePath);
      _setStatus(task.track, DownloadStatus.completed);
    } catch (e, stack) {
      final wasCancelled = e is DioException && CancelToken.isCancel(e);
      _setStatus(
        task.track,
        wasCancelled ? DownloadStatus.canceled : DownloadStatus.failed,
        error: wasCancelled ? null : _describeError(e),
      );
      if (!wasCancelled) {
        AppLogger.reportError(e, stack);
      }
    }
  }

  String _describeError(Object e) {
    if (e is SpotiFlacDownloadException) return e.message;
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 429) return "Rate limited by download server (429)";
      if (status != null) return "Download failed (HTTP $status)";
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          "Connection timed out",
        DioExceptionType.connectionError => "No connection to download server",
        _ => "Network error: ${e.message ?? e.type.name}",
      };
    }
    return e.toString();
  }

  /// Re-queues every failed task (e.g. after a rate-limit wave passes).
  void retryAllFailed() {
    final failed =
        state.where((e) => e.status == DownloadStatus.failed).toList();
    if (failed.isEmpty) return;
    for (final task in failed) {
      _setStatus(task.track, DownloadStatus.queued);
    }
    _startDownloading(); // No await should be invoked to avoid stuck UI
  }

  Future<void> _startDownloading() async {
    for (final task in state) {
      if (task.status == DownloadStatus.downloading) return;

      if (task.status == DownloadStatus.queued) {
        try {
          await _downloadTrack(task);
        } finally {
          // After completion, check for more queued tasks.
          // Ignore errors of the prior task to allow next task to complete.
          await _startDownloading();
        }
      }
    }
  }
}

final downloadManagerProvider =
    NotifierProvider<DownloadManagerNotifier, List<DownloadTask>>(
  DownloadManagerNotifier.new,
);
