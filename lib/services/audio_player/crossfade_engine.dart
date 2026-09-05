import 'dart:async';
import 'dart:math' as math;

import 'package:media_kit/media_kit.dart';
import 'package:sonolyth/models/playback/crossfade.dart';
import 'package:sonolyth/services/audio_player/custom_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

export 'package:sonolyth/models/playback/crossfade.dart' show CrossfadeCurve;

/// Gain (0..1) of the OUTGOING track at fade progress [t] (0..1).
double crossfadeOutGain(CrossfadeCurve curve, double t) {
  final x = t.clamp(0.0, 1.0);
  return switch (curve) {
    CrossfadeCurve.linear => 1 - x,
    // Equal-power keeps the summed loudness roughly constant through the
    // overlap; a linear pair dips audibly (−3dB summed) at the midpoint.
    CrossfadeCurve.equalPower => math.cos(x * math.pi / 2),
  };
}

/// Gain (0..1) of the INCOMING track at fade progress [t] (0..1).
double crossfadeInGain(CrossfadeCurve curve, double t) {
  final x = t.clamp(0.0, 1.0);
  return switch (curve) {
    CrossfadeCurve.linear => x,
    CrossfadeCurve.equalPower => math.sin(x * math.pi / 2),
  };
}

/// The fade actually used for a track of [trackLength]: the configured value,
/// capped so the overlap never eats more than half the track, and dropped to
/// zero (no crossfade — native gapless handles it) when the cap leaves less
/// than a second of fade to work with.
Duration effectiveCrossfade(Duration configured, Duration trackLength) {
  if (configured <= Duration.zero || trackLength <= Duration.zero) {
    return Duration.zero;
  }
  final half = trackLength ~/ 2;
  final fade = configured < half ? configured : half;
  return fade < const Duration(seconds: 1) ? Duration.zero : fade;
}

/// One in-flight crossfade.
class _FadeRun {
  _FadeRun({required this.duration, required this.hasTail});

  final Duration duration;

  /// Whether a shadow deck is carrying an outgoing tail under this fade. A
  /// manual skip has none — only the incoming ease-in applies.
  final bool hasTail;

  Timer? ticker;

  /// Fade progress already elapsed, carried across a pause so resuming
  /// continues the ramp instead of restarting it.
  Duration elapsed = Duration.zero;
  bool paused = false;
  bool finished = false;
}

/// Crossfade engine built around a single "tail" deck.
///
/// The main [CustomPlayer] always holds the current track: it owns the queue,
/// its playlist index is the now-playing pointer the whole app reads, and it
/// stays the deck every position/duration/state stream comes from. That never
/// alternates, so nothing outside this class has to know a crossfade is
/// happening.
///
/// What the second deck does is carry the OUTGOING track's tail:
///
///  1. Preroll — shortly before the current track's fade point, the shadow
///     deck opens the *current* track, seeks to the fade point, and waits
///     there paused.
///  2. Fade start — the shadow starts playing (continuing the outgoing track
///     from where main is about to leave it) and ramps down, while main is
///     advanced to the next queue entry and ramps up from silence. mpv's
///     `prefetch-playlist` has already opened that entry, so main's advance
///     costs nothing.
///  3. Fade end — the shadow stops. Main is left playing the new track at
///     full volume, exactly as it would be without any of this.
///
/// Because main advances at fade start, the now-playing track, notification
/// and progress bar flip when the new track becomes audible — the same moment
/// in every transition — and a seek or skip mid-fade acts on the track the
/// user can actually see. With `fadeDuration == 0` nothing here engages and
/// the shadow deck is never even created.
class CrossfadeEngine {
  CrossfadeEngine({
    required CustomPlayer mainPlayer,
    required Future<CustomPlayer> Function() shadowFactory,
  })  : _main = mainPlayer,
        _shadowFactory = shadowFactory {
    _positionSub = _main.stream.position.listen(
      _onPosition,
      onError: (_) {},
    );
    // Queue mutations can move or replace the entry the tail was prepared
    // for; drop it rather than fading from a stale one.
    _playlistSub = _main.stream.playlist.listen((playlist) {
      if (_fade != null) return;
      if (_preparedForIndex != null && _preparedForIndex != playlist.index) {
        unawaited(_discardPreparedTail());
      }
    });
  }

  final CustomPlayer _main;
  final Future<CustomPlayer> Function() _shadowFactory;

  CustomPlayer? _shadow;
  Future<CustomPlayer>? _shadowInit;
  StreamSubscription? _positionSub;
  StreamSubscription? _playlistSub;

  Duration _fadeDuration = Duration.zero;
  CrossfadeCurve curve = CrossfadeCurve.equalPower;
  double _userVolume = 1.0;

  _FadeRun? _fade;
  int _generation = 0;

  /// Queue index whose tail the shadow deck is parked on, and whether that
  /// preparation actually completed.
  int? _preparedForIndex;
  bool _tailReady = false;
  bool _preparing = false;

  final _volumeController = StreamController<double>.broadcast();

  /// The tail deck is opened this long before the fade point, so its decoder
  /// is primed and seeked before the first sample is needed.
  static const _prerollLead = Duration(seconds: 4);

  /// Below this much remaining track there's no room left for a fade (the
  /// user seeked into the final moments) — let the track end natively.
  static const _minTailForFade = Duration(milliseconds: 700);

  /// A manual skip has no prepared tail, and opening one would delay the
  /// skip — which has to stay instant — so the outgoing track simply stops
  /// and the new one eases in over this long, which only avoids a click.
  static const _manualEaseIn = Duration(milliseconds: 180);

  static const _tick = Duration(milliseconds: 25);

  bool get enabled => _fadeDuration > Duration.zero;
  Duration get fadeDuration => _fadeDuration;
  bool get isFading => _fade != null;
  double get userVolume => _userVolume;
  Stream<double> get userVolumeStream => _volumeController.stream;

  // ---------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------

  Future<void> setFadeDuration(Duration duration) async {
    if (duration != _fadeDuration) {
      AppLogger.diag("[xfade] fade duration -> ${duration.inMilliseconds}ms");
    }
    _fadeDuration = duration;
    if (duration > Duration.zero) return;
    // Turning it off mid-fade: drop the tail and leave main whole.
    await _abortFade();
    await _discardPreparedTail();
  }

  Future<void> setUserVolume(double volume) async {
    _userVolume = volume;
    if (!_volumeController.isClosed) _volumeController.add(volume);
    // Mid-fade, the ticker applies the new value through its gain multiplier.
    if (_fade == null) await _main.setVolume(volume * 100);
  }

  /// Applies a playback-shaping setting (normalization, speed, demuxer size,
  /// output device…) to both decks, so the tail sounds like the track it came
  /// from.
  Future<void> applyToDecks(
    Future<void> Function(CustomPlayer deck) apply,
  ) async {
    await apply(_main);
    final deck = _shadow;
    if (deck == null) return;
    try {
      await apply(deck);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  // ---------------------------------------------------------------------
  // Playback commands
  // ---------------------------------------------------------------------

  Future<void> pause() async {
    final run = _fade;
    if (run != null && !run.paused) {
      // Freeze the crossfade rather than finishing or dropping it: both decks
      // hold their gains and resuming picks the ramp back up, so pausing
      // mid-overlap and pressing play again sounds like nothing happened.
      run.paused = true;
      run.ticker?.cancel();
      run.ticker = null;
      AppLogger.diag(
        "[xfade] fade PAUSED at ${run.elapsed.inMilliseconds}"
        "/${run.duration.inMilliseconds}ms",
      );
      try {
        await _shadow?.pause();
      } catch (_) {}
    }
    await _main.pause();
  }

  Future<void> resume() async {
    await _main.play();
    final run = _fade;
    if (run != null && run.paused) {
      run.paused = false;
      AppLogger.diag(
        "[xfade] fade RESUMED at ${run.elapsed.inMilliseconds}"
        "/${run.duration.inMilliseconds}ms",
      );
      if (run.hasTail) {
        try {
          await _shadow?.play();
        } catch (_) {}
      }
      _runTicker(run, _generation);
    }
  }

  Future<void> seek(Duration position) async {
    // Seeking is about the track the user is looking at, which is already the
    // one on main. Drop the outgoing tail so it doesn't ring on underneath.
    await _abortFade();
    await _main.seek(position);
  }

  Future<void> skipToNext() async {
    // At the end of a non-looping queue `next()` is a no-op, so easing the
    // volume around it would only dip the track that keeps playing.
    if (!enabled || !_hasNextEntry()) return _main.next();
    await _manualTransition(_main.next);
  }

  Future<void> skipToPrevious() async {
    await _leaveCompletedState();
    if (!enabled || !_hasPreviousEntry()) return _main.previous();
    await _manualTransition(_main.previous);
  }

  Future<void> jumpTo(int index) async {
    await _leaveCompletedState();
    if (!enabled) return _main.jump(index);
    await _manualTransition(() => _main.jump(index));
  }

  /// media_kit's `play()` rewinds a *completed* playlist — the queue ran to
  /// its end and mpv is parked, paused, at EOF of the last file — to entry 0
  /// before it does anything else ("play the playlist again"), and both
  /// `previous()` and `jump()` call `play()` first. So `previous` at the end
  /// of the queue restarted the FIRST track (the §18i observation, distinct
  /// from the media-key auto-repeat fixed in §24b), and a jump began loading
  /// entry 0 before the entry asked for (a spurious `/stream` request for a
  /// streamed queue). media_kit's `seek()` is the one call that clears
  /// `completed` synchronously (media-kit/media-kit#221), so seek the parked
  /// file back to 0 — it is paused, nothing is heard — before moving on.
  Future<void> _leaveCompletedState() async {
    if (!_main.state.completed || _main.state.playlist.medias.isEmpty) return;
    await _main.seek(Duration.zero);
  }

  /// Returns the engine to its dormant state: no tail, no fade, main at the
  /// user's volume. Used whenever the queue itself is replaced or torn down.
  Future<void> reset() async {
    _generation++;
    final run = _fade;
    run?.ticker?.cancel();
    run?.finished = true;
    _fade = null;
    _preparedForIndex = null;
    _tailReady = false;
    try {
      await _shadow?.stop();
    } catch (_) {}
    try {
      await _main.setVolume(_userVolume * 100);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await reset();
    await _positionSub?.cancel();
    await _playlistSub?.cancel();
    await _volumeController.close();
    try {
      await _shadow?.dispose();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Fade triggering
  // ---------------------------------------------------------------------

  void _onPosition(Duration position) {
    if (!enabled || _fade != null) return;
    // Repeat-one loops the same file; there is no next track to cross into.
    if (_main.state.playlistMode == PlaylistMode.single) return;
    if (!_main.state.playing) return;

    final window = _fadeWindow();
    if (window == null) return;
    final (fade, end) = window;

    // Nothing to fade into: let the queue end the way it normally does.
    if (!_hasNextEntry()) return;

    final remaining = end - position;
    if (remaining <= fade + _prerollLead) {
      unawaited(_prepareTail(end - fade));
    }
    if (remaining <= fade && remaining > _minTailForFade) {
      unawaited(_beginFade(fade));
    }
  }

  /// The fade length and the position playback actually ends at for the
  /// current track, or null when this track can't be crossfaded.
  (Duration, Duration)? _fadeWindow() {
    final playlist = _main.state.playlist;
    final media = playlist.medias.elementAtOrNull(playlist.index);
    final duration = _main.state.duration;
    if (duration <= Duration.zero) return null;

    // A silence-trimmed entry stops at Media.end, not at the file's full
    // length — time the fade against where playback really ends.
    var end = duration;
    final mediaEnd = media?.end;
    if (mediaEnd != null && mediaEnd > Duration.zero && mediaEnd < duration) {
      end = mediaEnd;
    }
    final start = media?.start ?? Duration.zero;

    final fade = effectiveCrossfade(_fadeDuration, end - start);
    if (fade == Duration.zero) return null;
    return (fade, end);
  }

  bool _hasNextEntry() {
    final playlist = _main.state.playlist;
    final index = playlist.index;
    if (index < 0 || playlist.medias.isEmpty) return false;
    if (index + 1 < playlist.medias.length) return true;
    return _main.state.playlistMode == PlaylistMode.loop;
  }

  bool _hasPreviousEntry() {
    final playlist = _main.state.playlist;
    final index = playlist.index;
    if (index < 0 || playlist.medias.isEmpty) return false;
    if (index > 0) return true;
    return _main.state.playlistMode == PlaylistMode.loop;
  }

  /// Opens the CURRENT track on the shadow deck and parks it, paused, at
  /// [fadePoint] — ready to carry the tail the instant main moves on.
  Future<void> _prepareTail(Duration fadePoint) async {
    final index = _main.state.playlist.index;
    if (_preparing || (_preparedForIndex == index && _tailReady)) return;
    final media = _main.state.playlist.medias.elementAtOrNull(index);
    if (media == null) return;

    _preparing = true;
    final generation = _generation;
    try {
      final deck = await _ensureShadow();
      if (generation != _generation) return;
      await deck.setVolume(0);
      await deck.open(media, play: false);
      if (generation != _generation) return;
      await deck.seek(fadePoint);
      if (generation != _generation) return;
      _preparedForIndex = index;
      _tailReady = true;
      AppLogger.diag(
        "[xfade] tail PREPARED idx=$index parked at "
        "${fadePoint.inMilliseconds}ms",
      );
    } catch (e, stack) {
      // A tail that won't open just means this transition isn't crossfaded.
      AppLogger.diag("[xfade] tail prepare FAILED idx=$index: $e");
      AppLogger.reportError(e, stack);
      _preparedForIndex = null;
      _tailReady = false;
    } finally {
      _preparing = false;
    }
  }

  Future<void> _discardPreparedTail() async {
    _preparedForIndex = null;
    _tailReady = false;
    try {
      await _shadow?.stop();
    } catch (_) {}
  }

  /// The natural end-of-track crossfade.
  Future<void> _beginFade(Duration fade) async {
    if (_fade != null || !enabled) return;
    if (!_tailReady || _preparedForIndex != _main.state.playlist.index) {
      // The tail never got ready (slow open, or a seek moved the goalposts).
      // Let the track run to its own end rather than faking a fade.
      AppLogger.diag(
        "[xfade] fade SKIPPED — tail not ready "
        "(ready=$_tailReady preparedFor=$_preparedForIndex "
        "idx=${_main.state.playlist.index})",
      );
      return;
    }

    final generation = ++_generation;
    final run = _FadeRun(duration: fade, hasTail: true);
    _fade = run;
    _tailReady = false;
    _preparedForIndex = null;

    try {
      final deck = _shadow;
      if (deck == null) {
        _fade = null;
        return;
      }
      // Hand the outgoing track to the tail deck first so the overlap is
      // continuous, then move main onto the next entry (already opened by
      // mpv's prefetch, so this is instant) and bring it up from silence.
      AppLogger.diag(
        "[xfade] fade START ${fade.inMilliseconds}ms curve=${curve.name} "
        "idx=${_main.state.playlist.index} "
        "pos=${_main.state.position.inMilliseconds}ms",
      );
      await deck.setVolume(_userVolume * 100);
      await deck.play();
      await _main.setVolume(0);
      await _main.next();
      if (generation != _generation) return;
      _runTicker(run, generation);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      await _abortFade();
    }
  }

  /// A manual skip/jump. There is no prepared tail for an arbitrary mid-track
  /// position, and opening one would delay the skip — which must stay
  /// instant — so the outgoing track simply stops and the new one eases in
  /// over [_manualEaseIn], which exists only to avoid a click.
  Future<void> _manualTransition(Future<void> Function() move) async {
    await _abortFade();
    await _discardPreparedTail();

    final generation = ++_generation;
    AppLogger.diag(
      "[xfade] manual transition — ease-in ${_manualEaseIn.inMilliseconds}ms",
    );
    await _main.setVolume(0);
    await move();
    if (generation != _generation) return;

    final run = _FadeRun(duration: _manualEaseIn, hasTail: false);
    _fade = run;
    _runTicker(run, generation);
  }

  // ---------------------------------------------------------------------
  // Fade execution
  // ---------------------------------------------------------------------

  void _runTicker(_FadeRun run, int generation) {
    final stopwatch = Stopwatch()..start();
    final alreadyElapsed = run.elapsed;

    run.ticker = Timer.periodic(_tick, (timer) {
      if (generation != _generation || run.finished) {
        timer.cancel();
        return;
      }
      run.elapsed = alreadyElapsed + stopwatch.elapsed;

      final total = run.duration.inMilliseconds;
      final t = total <= 0
          ? 1.0
          : (run.elapsed.inMilliseconds / total).clamp(0.0, 1.0);

      unawaited(
        _main.setVolume(crossfadeInGain(curve, t) * _userVolume * 100),
      );
      if (run.hasTail) {
        unawaited(
          _shadow?.setVolume(crossfadeOutGain(curve, t) * _userVolume * 100),
        );
      }

      if (t >= 1.0) {
        timer.cancel();
        unawaited(_finishFade(run, generation));
      }
    });
  }

  Future<void> _finishFade(_FadeRun run, int generation) async {
    if (run.finished || generation != _generation) return;
    run.finished = true;
    run.ticker?.cancel();
    _fade = null;
    AppLogger.diag(
      "[xfade] fade END tail=${run.hasTail} "
      "over ${run.elapsed.inMilliseconds}ms "
      "idx=${_main.state.playlist.index}",
    );
    try {
      await _main.setVolume(_userVolume * 100);
      if (run.hasTail) await _shadow?.stop();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }

  /// Drops an in-flight fade immediately: the tail stops and main goes back
  /// to full volume on whatever it is playing. Used when the user takes over
  /// (seek, skip) or crossfade is switched off.
  Future<void> _abortFade() async {
    final run = _fade;
    if (run == null) return;
    run.finished = true;
    run.ticker?.cancel();
    _fade = null;
    _generation++;
    AppLogger.diag(
      "[xfade] fade ABORT at ${run.elapsed.inMilliseconds}"
      "/${run.duration.inMilliseconds}ms",
    );
    try {
      await _shadow?.stop();
    } catch (_) {}
    try {
      await _main.setVolume(_userVolume * 100);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Shadow deck lifecycle
  // ---------------------------------------------------------------------

  Future<CustomPlayer> _ensureShadow() {
    final existing = _shadow;
    if (existing != null) return Future.value(existing);
    return _shadowInit ??= () async {
      final deck = await _shadowFactory();
      _shadow = deck;
      AppLogger.diag("[xfade] shadow deck created");
      return deck;
    }();
  }
}
