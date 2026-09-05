import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/modules/player/use_progress.dart';

/// What the seek bars draw when mpv is holding nothing (item 64).
///
/// The §43 gate keeps a queue out of mpv while nothing in it could be opened,
/// and the engine's streams do not go quiet when that happens — they keep
/// reporting the **last media mpv actually opened**. So a blocked Spotify
/// track sat under a bar reading `00:00 / 00:30`, the thirty seconds belonging
/// to the local tone played before it. Every number below is available without
/// asking the engine or the gateway anything.
void main() {
  group('progressValues, playing normally', () {
    test('reports the engine, and the bar is seekable', () {
      final v = progressValues(
        deferred: false,
        engineDuration: const Duration(minutes: 3),
        enginePosition: const Duration(minutes: 1, seconds: 30),
        engineBuffer: const Duration(minutes: 2),
        trackDurationMs: 210000,
      );

      expect(v.duration, const Duration(minutes: 3));
      expect(v.position, const Duration(minutes: 1, seconds: 30));
      expect(v.progressStatic, closeTo(0.5, 1e-9));
      expect(v.bufferProgress, closeTo(2 / 3, 1e-9));
      expect(v.seekable, isTrue);
    });

    test('the engine wins over the metadata while mpv holds the media', () {
      // A track whose metadata duration disagrees with the file mpv opened —
      // a re-mastered upload, a padded stream. Playing, the engine is the
      // authority, because the bar has to match what is being heard.
      final v = progressValues(
        deferred: false,
        engineDuration: const Duration(seconds: 200),
        enginePosition: Duration.zero,
        engineBuffer: Duration.zero,
        trackDurationMs: 210000,
      );

      expect(v.duration, const Duration(seconds: 200));
    });

    test('an unknown duration is 0 progress, not a divide by zero', () {
      final v = progressValues(
        deferred: false,
        engineDuration: Duration.zero,
        enginePosition: const Duration(seconds: 4),
        engineBuffer: const Duration(seconds: 9),
        trackDurationMs: null,
      );

      expect(v.progressStatic, 0.0);
      expect(v.bufferProgress, 0.0);
      expect(v.seekable, isTrue);
    });

    test('a position past the end still clamps to a full bar', () {
      final v = progressValues(
        deferred: false,
        engineDuration: const Duration(seconds: 30),
        enginePosition: const Duration(seconds: 41),
        engineBuffer: const Duration(seconds: 90),
        trackDurationMs: 30000,
      );

      expect(v.progressStatic, 1.0);
      expect(v.bufferProgress, 1.0);
    });
  });

  group('progressValues, queue deferred', () {
    test('takes the total off the track, not off the stale engine', () {
      // This is the reported defect: mpv still says 30 seconds because that
      // is the tone it last opened, and the track sitting on screen is 3:30.
      final v = progressValues(
        deferred: true,
        engineDuration: const Duration(seconds: 30),
        enginePosition: const Duration(seconds: 12),
        engineBuffer: const Duration(seconds: 30),
        trackDurationMs: 210000,
      );

      expect(v.duration, const Duration(milliseconds: 210000));
    });

    test('sits at zero, with nothing buffered', () {
      // Playback has not begun and cannot begin, so a leftover position and a
      // leftover buffer fill are both lies about this track.
      final v = progressValues(
        deferred: true,
        engineDuration: const Duration(seconds: 30),
        enginePosition: const Duration(seconds: 12),
        engineBuffer: const Duration(seconds: 30),
        trackDurationMs: 210000,
      );

      expect(v.position, Duration.zero);
      expect(v.progressStatic, 0.0);
      expect(v.bufferProgress, 0.0);
    });

    test('refuses a scrub', () {
      // A bar that can be dragged to a position nothing will honour is worse
      // than one showing a wrong total: the finger moves the fill, the engine
      // never reports arriving, and the hold in `useProgress` keeps the wrong
      // number on screen for its full timeout.
      final v = progressValues(
        deferred: true,
        engineDuration: const Duration(seconds: 30),
        enginePosition: Duration.zero,
        engineBuffer: Duration.zero,
        trackDurationMs: 210000,
      );

      expect(v.seekable, isFalse);
    });

    test('a track with no duration reads 0:00, never the previous track', () {
      // The fallback is deliberately zero rather than the engine's value: an
      // unknown total is honest, and the last track's total is not.
      final v = progressValues(
        deferred: true,
        engineDuration: const Duration(seconds: 30),
        enginePosition: const Duration(seconds: 12),
        engineBuffer: Duration.zero,
        trackDurationMs: null,
      );

      expect(v.duration, Duration.zero);
      expect(v.seekable, isFalse);
    });
  });
}
