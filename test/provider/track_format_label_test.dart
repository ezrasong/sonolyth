import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/provider/server/track_format_registry.dart';

/// The player's meta chip reads `audioSourceQualityLabelProvider`, and until now
/// that provider had exactly two answers: the resolved stream's own label, or —
/// for everything else — the configured **streaming preset**.
///
/// A file on disk is never a *source*, so every local and downloaded track took
/// the second branch: the player named "flac • 16bit • 44.1kHz" over a WAV
/// whose own list row, three taps away, read "0:30 | wav". §42 caught the same
/// lie for a blocked stream and answered it with a state; this is the other
/// half, and here there is nothing to be blocked about — the format is known,
/// off the extension, exactly as `track_tile.dart` has always read it.
///
/// What this pins is the shared label: whatever the chip says about a file has
/// to match what the row says about the same file, and it has to drop what it
/// does not know rather than print or invent it.
void main() {
  group('TrackFormat.label', () {
    test('is the container alone when that is all a file tells you', () {
      // `TrackFormat.fromPath` cannot know bit depth without opening the file,
      // so this is the common case for a local track: one word, and true.
      expect(TrackFormat.fromPath('/sdcard/Music/Alpha Tone.wav')!.label, 'wav');
    });

    test('reads like the stream label when the depth and rate are known', () {
      // Byte-identical to `SourcedTrack.qualityLabel` for the same numbers —
      // the chip must not change shape because the audio came off a disk.
      expect(
        const TrackFormat(container: 'flac', bitDepth: 24, sampleRate: 96000)
            .label,
        'flac • 24bit • 96kHz',
      );
    });

    test('keeps one decimal only where there is one', () {
      expect(
        const TrackFormat(container: 'flac', bitDepth: 16, sampleRate: 44100)
            .label,
        'flac • 16bit • 44.1kHz',
      );
    });

    test('drops a rate it does not have rather than guessing one', () {
      expect(
        const TrackFormat(container: 'flac', bitDepth: 24).label,
        'flac • 24bit',
      );
    });

    test('has nothing to say about a path with no extension', () {
      expect(TrackFormat.fromPath('/sdcard/Music/tone'), isNull);
      expect(TrackFormat.fromPath('/sdcard/Music/tone.'), isNull);
    });
  });
}
