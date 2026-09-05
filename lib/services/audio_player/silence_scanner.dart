import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Digital silence measured at the edges of an audio file.
typedef EdgeSilence = ({Duration lead, Duration tail, Duration duration});

/// Measures the lead-in / lead-out silence of a *local, fully written* audio
/// file, so playback can skip it.
///
/// This is about SILENCE THAT IS IN THE AUDIO, not encoder padding: FLAC is
/// sample-exact and mpv's demuxer already honours the LAME/iTunes gapless
/// tags on MP3/AAC, so padding needs no help here. What's left is the few
/// hundred milliseconds of true digital silence a CD master often carries at
/// each end — the part that makes an album transition (or a crossfade) sag.
///
/// The scan decodes the file with no audio output and no clock, which is much
/// faster than realtime, and reads ffmpeg's `silencedetect` output from mpv's
/// log stream. It is deliberately restricted to files already on disk: it must
/// never pull bytes for a track that isn't playing.
abstract final class SilenceScanner {
  /// Anything quieter than this counts as silence.
  static const _noiseFloorDb = -50;

  /// Shorter runs than this aren't worth trimming and are more likely to be
  /// musical rests than dead air at the edges.
  static const _minSilence = Duration(milliseconds: 400);

  /// Leave a little breath so a trimmed track never clips its own first or
  /// last sample.
  static const _breath = Duration(milliseconds: 150);

  /// A longer "silence" than this is a quiet intro/outro, not dead air —
  /// trimming it would cut the music the user expects to hear.
  static const _maxTrim = Duration(seconds: 5);

  /// Give up on a file that won't decode in reasonable time rather than
  /// leaving a second player alive.
  static const _timeout = Duration(minutes: 2);

  static final RegExp _silenceStart = RegExp(r'silence_start:\s*(-?[\d.]+)');
  static final RegExp _silenceEnd = RegExp(r'silence_end:\s*(-?[\d.]+)');

  /// Scans [filePath] and returns the trimmable silence at each edge, or null
  /// when there's nothing worth trimming (or the scan failed — a failed scan
  /// simply leaves the track untrimmed).
  static Future<EdgeSilence?> scan(String filePath) async {
    if (!await File(filePath).exists()) return null;

    Player? scanner;
    StreamSubscription? logSub;
    StreamSubscription? errorSub;
    try {
      scanner = Player(
        configuration: const PlayerConfiguration(
          title: "Sonolyth silence scan",
          logLevel: MPVLogLevel.info,
          async: true,
        ),
      );
      final native = scanner.platform as NativePlayer;

      double? firstSilenceEnd;
      double? lastSilenceStart;
      var sawAnySilence = false;

      logSub = scanner.stream.log.listen((event) {
        final text = event.text;
        final end = _silenceEnd.firstMatch(text);
        if (end != null) {
          sawAnySilence = true;
          firstSilenceEnd ??= double.tryParse(end.group(1)!);
        }
        final start = _silenceStart.firstMatch(text);
        if (start != null) {
          sawAnySilence = true;
          lastSilenceStart = double.tryParse(start.group(1)!);
        }
      });
      errorSub = scanner.stream.error.listen((_) {});

      // Decode as fast as the CPU allows, to nothing.
      await native.setProperty('ao', 'null');
      await native.setProperty('untimed', 'yes');
      await native.setProperty('audio-display', 'no');
      await native.setProperty('vid', 'no');
      await native.setProperty(
        'af',
        'lavfi=[silencedetect=noise=${_noiseFloorDb}dB'
            ':d=${(_minSilence.inMilliseconds / 1000).toStringAsFixed(2)}]',
      );

      await scanner.open(Media(filePath), play: true);
      await scanner.stream.completed
          .firstWhere((completed) => completed)
          .timeout(_timeout);

      final duration = scanner.state.duration;
      if (duration <= Duration.zero) return null;
      if (!sawAnySilence) return null;

      // A leading trim only applies when the file STARTS silent: the first
      // silence must end after a run that began at (or before) zero, which is
      // exactly the case where the first event seen is an end with no start
      // before it. `silencedetect` reports a run starting at 0 without a
      // preceding start marker, so a first `silence_end` earlier than the
      // first `silence_start` is the signal.
      final firstEnd = firstSilenceEnd;
      final lead = (firstEnd != null &&
              firstEnd > 0 &&
              (lastSilenceStart == null || firstEnd <= lastSilenceStart!))
          ? _clampTrim(Duration(milliseconds: (firstEnd * 1000).round()))
          : Duration.zero;

      // A trailing trim only applies when the last detected silence runs to
      // the end of the file (no `silence_end` after it).
      final lastStart = lastSilenceStart;
      final tailRun = lastStart == null
          ? Duration.zero
          : duration - Duration(milliseconds: (lastStart * 1000).round());
      final tail = (lastStart != null &&
              (firstEnd == null || lastStart > firstEnd) &&
              tailRun > _minSilence)
          ? _clampTrim(tailRun)
          : Duration.zero;

      if (lead == Duration.zero && tail == Duration.zero) return null;
      // Never let the trims meet: a file that is mostly silence stays whole.
      if (lead + tail > duration ~/ 2) return null;

      return (lead: lead, tail: tail, duration: duration);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return null;
    } finally {
      await logSub?.cancel();
      await errorSub?.cancel();
      try {
        await scanner?.dispose();
      } catch (_) {}
    }
  }

  /// Applies the breath margin and the upper bound to a raw silence run.
  static Duration _clampTrim(Duration raw) {
    if (raw <= _minSilence) return Duration.zero;
    final trimmed = raw - _breath;
    if (trimmed <= Duration.zero) return Duration.zero;
    return trimmed > _maxTrim ? _maxTrim : trimmed;
  }
}
