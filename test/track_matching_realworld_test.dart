import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';

/// Regression tests built from REAL provider payloads (captured from
/// `tidal.com/v1/search/tracks`), not invented strings. These guard the cases
/// that actually broke in the field — non-Latin artists whose romanisation
/// differs between Spotify and the lossless catalogs.
void main() {
  // The provider threshold every caller uses.
  const threshold = 0.5;

  double score({
    required String expectedTitle,
    required List<String> expectedArtists,
    required String candidateTitle,
    required List<String> candidateArtists,
    int expectedMs = 0,
    int candidateMs = 0,
  }) =>
      TrackMatching.score(
        expectedTitle: expectedTitle,
        candidateTitle: candidateTitle,
        expectedArtists: expectedArtists,
        candidateArtists: candidateArtists,
        expectedDurationMs: expectedMs,
        candidateDurationMs: candidateMs,
      );

  group('LEE MU JIN — "Rain and You" (real TIDAL results)', () {
    const title = 'Rain and You';
    const artists = ['LEE MU JIN'];
    const durationMs = 262000;

    test('the exact catalog entry clears the threshold', () {
      expect(
        score(
          expectedTitle: title,
          expectedArtists: artists,
          candidateTitle: 'Rain and You',
          candidateArtists: ['LEE MU JIN'],
          expectedMs: durationMs,
          candidateMs: 262000,
        ),
        greaterThanOrEqualTo(threshold),
      );
    });

    test('the instrumental sibling is hard-rejected', () {
      expect(
        TrackMatching.isVariantMismatch(title, 'Rain and You (Instrumental)'),
        isTrue,
      );
    });

    test('a same-title track by a different artist is rejected', () {
      // "Rain and You" by Rumble Fish is a genuinely different song.
      expect(
        score(
          expectedTitle: title,
          expectedArtists: artists,
          candidateTitle: 'Rain and You',
          candidateArtists: ['Rumble Fish'],
          expectedMs: durationMs,
          candidateMs: 248000,
        ),
        lessThan(threshold),
      );
    });

    test('a different song by the same artist is rejected', () {
      expect(
        score(
          expectedTitle: title,
          expectedArtists: artists,
          candidateTitle: 'Traffic light',
          candidateArtists: ['LEE MU JIN'],
          expectedMs: durationMs,
          candidateMs: 232000,
        ),
        lessThan(threshold),
      );
    });
  });

  group('romanisation variance between providers', () {
    // The failure mode this group exists for: Spotify and the lossless
    // catalogs romanise Korean/Japanese/Chinese names differently, and
    // exact-token-set artist matching treats those as different people.
    const title = 'Rain and You';
    const durationMs = 262000;

    void expectMatches(List<String> expected, List<String> candidate) {
      expect(
        score(
          expectedTitle: title,
          expectedArtists: expected,
          candidateTitle: title,
          candidateArtists: candidate,
          expectedMs: durationMs,
          candidateMs: durationMs,
        ),
        greaterThanOrEqualTo(threshold),
        reason: '$expected should match $candidate',
      );
    }

    test('spacing differences in a romanised name still match', () {
      expectMatches(['LEE MU JIN'], ['Lee Mujin']);
      expectMatches(['Lee Mujin'], ['LEE MU JIN']);
    });

    test('hyphenation differences still match', () {
      expectMatches(['LEE MU JIN'], ['Lee Mu-jin']);
    });

    test('native script vs romanisation still matches', () {
      expectMatches(['이무진'], ['LEE MU JIN']);
      expectMatches(['LEE MU JIN'], ['이무진']);
    });

    test('reversed name order still matches', () {
      // Some catalogs credit given-name-first.
      expectMatches(['LEE MU JIN'], ['Mujin Lee']);
    });

    test('genuinely different people still do NOT match', () {
      expect(
        score(
          expectedTitle: title,
          expectedArtists: ['LEE MU JIN'],
          candidateTitle: title,
          candidateArtists: ['Lee Hi'],
          expectedMs: durationMs,
          candidateMs: durationMs,
        ),
        lessThan(threshold),
      );
    });
  });

  group('cross-script credits carry no artist evidence', () {
    const title = 'Rain and You';
    const durationMs = 262000;

    test('a Latin initialism for a native-script act still matches', () {
      // 방탄소년단 IS BTS, and no string comparison can know that. This is why
      // the wrong-artist penalty is softened rather than applied in full:
      // Korean and Japanese acts are routinely credited natively by the
      // metadata provider and by initialism in the lossless catalogs.
      expect(
        score(
          expectedTitle: title,
          expectedArtists: ['방탄소년단'],
          candidateTitle: title,
          candidateArtists: ['BTS'],
          expectedMs: durationMs,
          candidateMs: durationMs,
        ),
        greaterThanOrEqualTo(threshold),
      );
    });

    test('the softened penalty still rejects the real wrong-artist result', () {
      // "Rain and You" by Rumble Fish, from the same live TIDAL payload: the
      // title is identical, so only the length separates it.
      expect(
        score(
          expectedTitle: title,
          expectedArtists: ['이무진'],
          candidateTitle: title,
          candidateArtists: ['Rumble Fish'],
          expectedMs: durationMs,
          candidateMs: 248000,
        ),
        lessThan(threshold),
      );
    });

    test('an inexact title gets the FULL penalty, not the softened one', () {
      // With no usable artist evidence the title is all that is left, so a
      // merely-similar one must not be enough to pin the track.
      expect(
        score(
          expectedTitle: title,
          expectedArtists: ['이무진'],
          candidateTitle: 'Rain and You Again',
          candidateArtists: ['Rumble Fish'],
          expectedMs: durationMs,
          candidateMs: durationMs,
        ),
        lessThan(threshold),
      );
    });

    test('two Latin names that disagree keep the full penalty', () {
      // Same script means the comparison actually happened, so a zero score
      // is real evidence and must not be softened.
      expect(
        score(
          expectedTitle: title,
          expectedArtists: ['LEE MU JIN'],
          candidateTitle: title,
          candidateArtists: ['Rumble Fish'],
          expectedMs: durationMs,
          candidateMs: durationMs,
        ),
        lessThan(threshold),
      );
    });
  });

  group('romanization system variance', () {
    const title = 'Rain and You';
    const durationMs = 262000;

    void expectMatches(List<String> expected, List<String> candidate) {
      expect(
        score(
          expectedTitle: title,
          expectedArtists: expected,
          candidateTitle: title,
          candidateArtists: candidate,
          expectedMs: durationMs,
          candidateMs: durationMs,
        ),
        greaterThanOrEqualTo(threshold),
        reason: '$expected should match $candidate',
      );
    }

    test('Revised vs passport vs McCune spellings of a Korean name', () {
      expectMatches(['정승환'], ['Jung Seung Hwan']);
      expectMatches(['정승환'], ['Jeong Seunghwan']);
      expectMatches(['박효신'], ['Park Hyo Shin']);
    });

    test('kana against the credited romaji', () {
      expectMatches(['ヨルシカ'], ['Yorushika']);
      expectMatches(['キタニタツヤ'], ['Kitani Tatsuya']);
    });

    test('anagrams are NOT treated as the same name', () {
      // "Silent" and "Listen" share every letter, but neither spells the
      // other out of whole name pieces.
      expect(
        TrackMatching.artistSimilarity(['Silent'], ['Listen']),
        0,
      );
      expect(
        TrackMatching.artistSimilarity(['George'], ['George Hampton']),
        0,
      );
    });
  });
}
