import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/spotiflac/spotiflac_downloader.dart';

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  canceled,
}

class DownloadTask {
  final SpotubeFullTrackObject track;
  final DownloadStatus status;
  final CancelToken cancelToken;
  final int? totalSizeBytes;
  final StreamController<int> _downloadedBytesStreamController;

  Stream<int> get downloadedBytesStream =>
      _downloadedBytesStreamController.stream;

  DownloadTask({
    required this.track,
    required this.status,
    required this.cancelToken,
    this.totalSizeBytes,
    StreamController<int>? downloadedBytesStreamController,
  }) : _downloadedBytesStreamController =
            downloadedBytesStreamController ?? StreamController.broadcast();

  DownloadTask copyWith({
    SpotubeFullTrackObject? track,
    DownloadStatus? status,
    CancelToken? cancelToken,
    int? totalSizeBytes,
    StreamController<int>? downloadedBytesStreamController,
  }) {
    return DownloadTask(
      track: track ?? this.track,
      status: status ?? this.status,
      cancelToken: cancelToken ?? this.cancelToken,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
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

  void addToQueue(SpotubeFullTrackObject track) {
    if (state.any((element) => element.track.id == track.id)) return;
    state = [
      ...state,
      DownloadTask(
        track: track,
        status: DownloadStatus.queued,
        cancelToken: CancelToken(),
      ),
    ];

    _startDownloading(); // No await should be invoked to avoid stuck UI
  }

  void addAllToQueue(
    List<SpotubeFullTrackObject> tracks, {
    String? collectionUrl,
  }) {
    final queuedTrackIds = state.map((task) => task.track.id).toSet();
    final newTracks =
        tracks.where((track) => !queuedTrackIds.contains(track.id)).toList();
    if (newTracks.isEmpty) return;

    state = [
      ...state,
      ...newTracks.map((e) => DownloadTask(
            track: e,
            status: DownloadStatus.queued,
            cancelToken: CancelToken(),
          )),
    ];

    if (collectionUrl?.trim().isNotEmpty == true) {
      _startCollectionDownload(
        collectionUrl!.trim(),
        newTracks,
      ); // No await should be invoked to avoid stuck UI
      return;
    }

    _startDownloading(); // No await should be invoked to avoid stuck UI
  }

  void retry(SpotubeFullTrackObject track) {
    if (state.firstWhereOrNull((e) => e.track.id == track.id)?.status
        case DownloadStatus.canceled || DownloadStatus.failed) {
      _setStatus(track, DownloadStatus.queued);
      _startDownloading(); // No await should be invoked to avoid stuck UI
    }
  }

  void cancel(SpotubeFullTrackObject track) {
    if (state.firstWhereOrNull((e) => e.track.id == track.id)?.status ==
        DownloadStatus.failed) {
      return;
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

  void _setStatus(SpotubeFullTrackObject track, DownloadStatus status) {
    state = state.map((e) {
      if (e.track.id == track.id) {
        if ((status == DownloadStatus.canceled) && e.cancelToken.isCancelled) {
          e.cancelToken.cancel();
        }

        return e.copyWith(status: status);
      }
      return e;
    }).toList();
  }

  bool _isShowingDialog = false;

  Future<void> _downloadTrack(DownloadTask task) async {
    try {
      _setStatus(task.track, DownloadStatus.downloading);
      if (task.cancelToken.isCancelled) {
        _setStatus(task.track, DownloadStatus.canceled);
        return;
      }

      final opened = await SpotiFlacDownloader.downloadTrack(task.track);
      if (opened) {
        _setStatus(task.track, DownloadStatus.completed);
      } else {
        _setStatus(task.track, DownloadStatus.failed);
      }
    } catch (e, stack) {
      _setStatus(task.track, DownloadStatus.failed);
      AppLogger.reportError(e, stack);
    }
  }

  Future<void> _startCollectionDownload(
    String collectionUrl,
    List<SpotubeFullTrackObject> tracks,
  ) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;
    try {
      for (final track in tracks) {
        _setStatus(track, DownloadStatus.downloading);
      }

      final opened = await SpotiFlacDownloader.downloadUrl(collectionUrl);
      for (final track in tracks) {
        _setStatus(
          track,
          opened ? DownloadStatus.completed : DownloadStatus.failed,
        );
      }
    } catch (e, stack) {
      for (final track in tracks) {
        _setStatus(track, DownloadStatus.failed);
      }
      AppLogger.reportError(e, stack);
    } finally {
      _isShowingDialog = false;
    }
  }

  Future<void> _startDownloading() async {
    for (final task in state) {
      if (task.status == DownloadStatus.downloading) return;

      if (task.status == DownloadStatus.queued) {
        try {
          await _downloadTrack(task);
        } finally {
          // After completion, check for more queued tasks
          // Ignore errors of the prior task to allow next task to complete
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
