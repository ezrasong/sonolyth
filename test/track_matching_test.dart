import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';

void main() {
  group('normalize', () {
    test('lowercases, strips feat. clauses, punctuation and diacritics', () {
      expect(
        TrackMatching.normalize("Café (feat. Sömeone)!"),
        "cafe",
      );
    });

    test('collapses whitespace', () {
      expect(TrackMatching.normalize("  a   b  "), "a b");
    });
  });

  group('titleSimilarity', () {
    test('identical titles score 1.0', () {
      expect(TrackMatching.titleSimilarity("Hello World", "hello world"), 1.0);
    });

    test('feat. formatting differences still match strongly', () {
      // "Song (feat. X)" vs "Song ft. X" normalize to the same core.
      expect(
        TrackMatching.titleSimilarity("Song (feat. X)", "Song ft. X"),
        greaterThanOrEqualTo(0.8),
      );
    });

    test('unrelated titles score low', () {
      expect(
        TrackMatching.titleSimilarity("Sunflower", "November Rain"),
        lessThan(0.2),
      );
    });
  });

  group('mismatchedVariants', () {
    test('flags a live version of a studio title', () {
      expect(
        TrackMatching.mismatchedVariants("Yesterday", "Yesterday (Live)"),
        contains("live"),
      );
    });

    test('flags remix / sped up / slowed', () {
      expect(
        TrackMatching.mismatchedVariants("Closer", "Closer (Sped Up Remix)"),
        containsAll(<String>["sped", "remix"]),
      );
    });

    test('does not flag when the expected title is itself the variant', () {
      // User explicitly wants the live recording — no mismatch.
      expect(
        TrackMatching.mismatchedVariants("Wonderwall (Live)", "Wonderwall Live"),
        isEmpty,
      );
    });

    test('clean studio match has no variant flags', () {
      expect(
        TrackMatching.mismatchedVariants("Levitating", "Levitating"),
        isEmpty,
      );
    });
  });

  group('score', () {
    test('exact studio match outranks a live version of the same song', () {
      final studio = TrackMatching.score(
        expectedTitle: "Creep",
        candidateTitle: "Creep",
        expectedArtists: const ["Radiohead"],
        candidateArtists: const ["Radiohead"],
        expectedDurationMs: 238000,
        candidateDurationMs: 238000,
      );
      final live = TrackMatching.score(
        expectedTitle: "Creep",
        candidateTitle: "Creep (Live)",
        expectedArtists: const ["Radiohead"],
        candidateArtists: const ["Radiohead"],
        expectedDurationMs: 238000,
        candidateDurationMs: 250000,
      );
      expect(studio, greaterThan(live));
    });

    test('a live version is penalized even with a closer duration', () {
      // The live take matches duration exactly; the studio take is 8s off.
      // The variant penalty should still keep studio ahead.
      final studio = TrackMatching.score(
        expectedTitle: "Fix You",
        candidateTitle: "Fix You",
        expectedArtists: const ["Coldplay"],
        candidateArtists: const ["Coldplay"],
        expectedDurationMs: 295000,
        candidateDurationMs: 287000,
      );
      final live = TrackMatching.score(
        expectedTitle: "Fix You",
        candidateTitle: "Fix You - Live",
        expectedArtists: const ["Coldplay"],
        candidateArtists: const ["Coldplay"],
        expectedDurationMs: 295000,
        candidateDurationMs: 295000,
      );
      expect(studio, greaterThan(live));
    });

    test('a large duration mismatch lowers the score', () {
      final close = TrackMatching.score(
        expectedTitle: "Clocks",
        candidateTitle: "Clocks",
        expectedArtists: const ["Coldplay"],
        candidateArtists: const ["Coldplay"],
        expectedDurationMs: 307000,
        candidateDurationMs: 307000,
      );
      final farOff = TrackMatching.score(
        expectedTitle: "Clocks",
        candidateTitle: "Clocks",
        expectedArtists: const ["Coldplay"],
        candidateArtists: const ["Coldplay"],
        expectedDurationMs: 307000,
        candidateDurationMs: 600000, // 5min longer (extended/loop)
      );
      expect(close, greaterThan(farOff));
    });

    test('correct artist outranks a wrong artist with the same title', () {
      final right = TrackMatching.score(
        expectedTitle: "Hello",
        candidateTitle: "Hello",
        expectedArtists: const ["Adele"],
        candidateArtists: const ["Adele"],
      );
      final wrong = TrackMatching.score(
        expectedTitle: "Hello",
        candidateTitle: "Hello",
        expectedArtists: const ["Adele"],
        candidateArtists: const ["Lionel Richie"],
      );
      expect(right, greaterThan(wrong));
    });
  });
}
