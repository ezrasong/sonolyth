import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

/// How close the engine's reported position has to get to a requested seek
/// before the bar starts following playback again.
const _kSeekSettled = Duration(milliseconds: 1200);

/// How long to keep showing a requested seek that the engine never reaches —
/// a stream that fails to open, a seek past the end. Without a ceiling the bar
/// would sit on a position that is never going to happen.
const _kSeekTimeout = Duration(seconds: 5);

/// Ignore position events closer together than this. The stream fires every
/// ~200ms and both the player and the nav bar rebuild on it; a jump larger
/// than this (a seek, a track change) always gets through.
const _kPositionStep = Duration(milliseconds: 240);

/// A [useProgress] seek that goes nowhere.
///
/// Handed out while the queue is deferred: mpv has no media open, so there is
/// no position to move. Returning a no-op rather than `null` keeps the record
/// shape constant for both call sites.
Future<void> _noSeek(Duration _) async {}

/// What the two bars draw, given what the engine reports and whether mpv is
/// holding anything at all.
///
/// Split out of the hook for the same reason `mpvCanOpenTrack` is (§43): the
/// judgement is the part worth pinning, and it can be checked here without a
/// player, a platform channel or a gateway.
///
/// **The deferred case is not a degraded version of the normal one.** While
/// the §43 gate holds a queue back, mpv has no media open, so its duration is
/// simply the last thing it *did* open and no position event will ever arrive
/// to correct it — a blocked track sat under `00:00 / 00:30` with the thirty
/// seconds belonging to the track before it (item 64). The track's own
/// duration is carried by every metadata object, so the honest total needs
/// nobody's permission; what the bar must not do is offer a scrub, because
/// there is nothing open to seek in.
@visibleForTesting
({
  double progressStatic,
  Duration position,
  Duration duration,
  double bufferProgress,
  bool seekable,
}) progressValues({
  required bool deferred,
  required Duration engineDuration,
  required Duration enginePosition,
  required Duration engineBuffer,
  required int? trackDurationMs,
}) {
  if (deferred) {
    return (
      progressStatic: 0.0,
      position: Duration.zero,
      duration: Duration(milliseconds: trackDurationMs ?? 0),
      bufferProgress: 0.0,
      seekable: false,
    );
  }

  // Ratios in milliseconds, not whole seconds: on a three-minute track a
  // second is half a percent of the bar, so an integer ratio made the fill
  // step visibly instead of gliding.
  final totalMs = engineDuration.inMilliseconds;
  final positionMs = enginePosition.inMilliseconds;
  final bufferMs = engineBuffer.inMilliseconds;

  return (
    progressStatic:
        totalMs <= 0 ? 0.0 : (positionMs / totalMs).clamp(0.0, 1.0),
    position: enginePosition,
    duration: engineDuration,
    bufferProgress: totalMs <= 0 ? 0.0 : (bufferMs / totalMs).clamp(0.0, 1.0),
    seekable: true,
  );
}

({
  double progressStatic,
  Duration position,
  Duration duration,
  double bufferProgress,
  bool seekable,
  Future<void> Function(Duration) seek,
}) useProgress(WidgetRef ref) {
  // Re-run (and reset) whenever the playing track changes.
  final activeTrackId =
      ref.watch(audioPlayerProvider.select((s) => s.activeTrack?.id));

  // While the §43 gate holds a queue back, mpv is empty and every stream below
  // is stale rather than wrong-in-progress: the duration is the last media it
  // opened, and no position event will ever arrive to correct it. The track's
  // own duration is known without asking anyone, so that is what gets shown.
  final deferred = ref.watch(playbackDeferredProvider);
  final trackDurationMs =
      ref.watch(audioPlayerProvider.select((s) => s.activeTrack?.durationMs));

  final bufferMs =
      useStream(audioPlayer.bufferedPositionStream).data?.inMilliseconds ?? 0;

  final duration = useState(Duration.zero);
  final position = useState(Duration.zero);

  // A seek the user has asked for but the engine has not reached yet.
  //
  // Releasing the seek bar used to hand the bar straight back to the position
  // stream, which was still reporting where playback *was* — so the bar
  // snapped back to the old spot and only jumped forward when the engine
  // caught up, up to a second later. Scrubbing therefore felt like it had
  // been ignored. Hold the requested position until playback actually lands
  // near it (or [_kSeekTimeout] passes).
  final pendingSeek = useRef<Duration?>(null);
  final pendingSince = useRef<DateTime?>(null);

  useEffect(() {
    duration.value = audioPlayer.duration;

    // Force the bar to 0 on every track change. A skip/auto-advance otherwise
    // leaves the previous track's position (or a preloaded offset) on screen
    // until the new position stream catches up — so the bar looked like it
    // started partway in. Re-subscribing also means a late position event from
    // the old track can't land on the new one.
    position.value = Duration.zero;
    pendingSeek.value = null;
    pendingSince.value = null;

    var lastPosition = Duration.zero;

    final durationSubscription = audioPlayer.durationStream.listen((event) {
      duration.value = event;
    });

    final positionSubscription = audioPlayer.positionStream.listen((event) {
      final target = pendingSeek.value;
      if (target != null) {
        final settled = (event - target).abs() <= _kSeekSettled;
        final since = pendingSince.value;
        final expired =
            since == null || DateTime.now().difference(since) > _kSeekTimeout;
        if (!settled && !expired) return;
        pendingSeek.value = null;
        pendingSince.value = null;
        lastPosition = event;
        position.value = event;
        return;
      }

      // Coalesce the stream's ~200ms ticks; a real jump always passes.
      if ((event - lastPosition).abs() < _kPositionStep) return;
      lastPosition = event;
      position.value = event;
    });

    return () {
      positionSubscription.cancel();
      durationSubscription.cancel();
    };
  }, [activeTrackId]);

  /// Seeks, and shows the requested position immediately.
  ///
  /// Every scrub in the app goes through here — the player's bar and the nav
  /// bar's line — so the hold above applies wherever the user let go.
  final seek = useCallback<Future<void> Function(Duration)>((target) async {
    final total = duration.value.inMilliseconds;
    final clamped = Duration(
      milliseconds: total <= 0
          ? target.inMilliseconds.clamp(0, target.inMilliseconds)
          : target.inMilliseconds.clamp(0, total),
    );
    pendingSeek.value = clamped;
    pendingSince.value = DateTime.now();
    position.value = clamped;
    await audioPlayer.seek(clamped);
  }, const []);

  // Computed after every hook, so the hook order is identical either way.
  final values = progressValues(
    deferred: deferred,
    engineDuration: duration.value,
    enginePosition: position.value,
    engineBuffer: Duration(milliseconds: bufferMs),
    trackDurationMs: trackDurationMs,
  );

  return (
    progressStatic: values.progressStatic,
    position: values.position,
    duration: values.duration,
    bufferProgress: values.bufferProgress,
    seekable: values.seekable,
    // A drag that reaches a bar with nothing open would set `pendingSeek` and
    // hold the display on a position playback is never going to report.
    seek: values.seekable ? seek : _noSeek,
  );
}
