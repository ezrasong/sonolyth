import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// How well the network is keeping up with playback.
enum PlaybackNetworkHealth {
  /// Playback is keeping ahead of the buffer — full speculative prefetch.
  healthy,

  /// Repeated mid-track stalls: the connection can't comfortably carry the
  /// stream plus the speculative prefetch traffic.
  degraded;

  bool get isDegraded => this == PlaybackNetworkHealth.degraded;
}

/// Watches for mid-track buffer stalls and reports whether the connection is
/// keeping up.
///
/// Playback here is lossless-only by design (Qobuz CD-FLAC, then TIDAL
/// LOSSLESS — both already the lowest lossless tier), so there is no quality
/// ladder to step down. What the app *can* trade away when the network is
/// struggling is speculative work:
///
///  * widen mpv's demuxer buffer, so a dip drains cache instead of the audio,
///  * and stop spending bandwidth on prefetching tracks that may never play,
///    which is what competes with the stream the user is actually hearing.
///
/// A stall only counts when it happens mid-track while playing — the buffering
/// at a track's opening is normal, and so is the burst after a seek.
class PlaybackNetworkHealthNotifier extends Notifier<PlaybackNetworkHealth> {
  /// Stalls within [_window] that trip the degraded state.
  static const _stallsToDegrade = 3;
  static const _window = Duration(seconds: 90);

  /// Cleanly finished tracks needed to earn the healthy state back.
  static const _cleanTracksToRecover = 2;

  /// Buffer sizes for each state. The degraded one buys ~3x the decode-ahead
  /// at the cost of memory the app can spare while a stream is struggling.
  static const _healthyBufferBytes = 6 * 1024 * 1024;
  static const _degradedBufferBytes = 20 * 1024 * 1024;

  final List<DateTime> _stalls = [];
  int _cleanTracks = 0;
  Duration _lastPosition = Duration.zero;
  bool _wasBuffering = false;

  @override
  PlaybackNetworkHealth build() {
    final subscriptions = <StreamSubscription>[
      // A stall shows up as buffering re-asserting itself after playback had
      // already progressed into the track.
      audioPlayer.playerStateStream.listen((_) {
        try {
          _onStateChanged();
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
      audioPlayer.positionStream.listen((position) {
        _lastPosition = position;
      }),
      // Reaching the end of a track without stalling is the evidence that the
      // connection recovered.
      audioPlayer.currentIndexChangedStream.listen((_) {
        try {
          _onTrackChanged();
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
    ];

    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });

    return PlaybackNetworkHealth.healthy;
  }

  void _onStateChanged() {
    final buffering = audioPlayer.isBuffering;
    final wasBuffering = _wasBuffering;
    _wasBuffering = buffering;

    if (!buffering || wasBuffering) return;
    // Opening the track (or the moments right after a seek landed) buffers
    // normally; only a stall well inside a track means the stream ran dry.
    if (_lastPosition < const Duration(seconds: 5)) return;
    if (!audioPlayer.isPlaying) return;

    final now = DateTime.now();
    _stalls
      ..add(now)
      ..removeWhere((stall) => now.difference(stall) > _window);

    if (_stalls.length >= _stallsToDegrade && !state.isDegraded) {
      _setHealth(PlaybackNetworkHealth.degraded);
    }
  }

  void _onTrackChanged() {
    final stalled = _stalls.isNotEmpty;
    _stalls.clear();
    _lastPosition = Duration.zero;

    if (!state.isDegraded) return;
    _cleanTracks = stalled ? 0 : _cleanTracks + 1;
    if (_cleanTracks >= _cleanTracksToRecover) {
      _setHealth(PlaybackNetworkHealth.healthy);
    }
  }

  void _setHealth(PlaybackNetworkHealth health) {
    if (state == health) return;
    state = health;
    _cleanTracks = 0;
    _stalls.clear();
    AppLogger.log.i("[network-health] $health");

    audioPlayer
        .setDemuxerBufferSize(
          health.isDegraded ? _degradedBufferBytes : _healthyBufferBytes,
        )
        .catchError((Object e, StackTrace stack) {
      AppLogger.reportError(e, stack);
    });
  }
}

final playbackNetworkHealthProvider =
    NotifierProvider<PlaybackNetworkHealthNotifier, PlaybackNetworkHealth>(
  PlaybackNetworkHealthNotifier.new,
);
