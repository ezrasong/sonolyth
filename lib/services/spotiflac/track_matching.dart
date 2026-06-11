/// Title/artist normalization and scoring used to pick the right provider
/// track when an ISRC lookup misses. Mirrors the matching the SpotiFLAC
/// extensions do (loose title compare + artist overlap + duration proximity).
abstract class TrackMatching {
  static final _featureRegex = RegExp(
    r"\s*[\(\[]\s*(feat|ft|featuring|with)\.?\s.*?[\)\]]",
    caseSensitive: false,
  );

  /// Bare (unbracketed) feature credits, e.g. "Song ft. X" or
  /// "Song featuring X" — these run to the end of the title. "with" is
  /// deliberately excluded here (too many real titles contain it, e.g.
  /// "Gone with the Wind"); only the unambiguous feat./ft. markers are
  /// stripped, and a leading space requirement keeps words like "Lift" safe.
  static final _bareFeatureRegex = RegExp(
    r"\s+(feat|ft|featuring)\.?\s+.*$",
    caseSensitive: false,
  );
  static final _nonAlphaNum = RegExp(r"[^a-z0-9\s]");
  static final _spaces = RegExp(r"\s+");

  static String normalize(String value) {
    var text = value.toLowerCase();
    text = text.replaceAll(_featureRegex, " ");
    text = text.replaceAll(_bareFeatureRegex, " ");
    text = _stripDiacritics(text);
    text = text.replaceAll(_nonAlphaNum, " ");
    return text.replaceAll(_spaces, " ").trim();
  }

  static const _diacritics =
      "àáâãäåāăąèéêëēĕėęěìíîïĩīĭįòóôõöøōŏőùúûüũūŭůûưñçćčşšžźżğ";
  static const _plain =
      "aaaaaaaaaeeeeeeeeeiiiiiiiioooooooooouuuuuuuuuuncccsszzzg";

  static String _stripDiacritics(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final index = _diacritics.indexOf(char);
      buffer.write(index >= 0 ? _plain[index] : char);
    }
    return buffer.toString();
  }

  /// 0..1 similarity of two titles by word overlap after normalization.
  static double titleSimilarity(String a, String b) {
    final wordsA = normalize(a).split(" ").where((w) => w.isNotEmpty).toSet();
    final wordsB = normalize(b).split(" ").where((w) => w.isNotEmpty).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return 0;
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    return intersection / union;
  }

  /// 1.0 when any expected artist appears among the candidate artists.
  static double artistSimilarity(
    List<String> expected,
    List<String> candidate,
  ) {
    if (expected.isEmpty || candidate.isEmpty) return 0;
    final normalizedCandidate = candidate.map(normalize).toSet();
    for (final artist in expected.map(normalize)) {
      if (artist.isEmpty) continue;
      for (final other in normalizedCandidate) {
        if (other.contains(artist) || artist.contains(other)) return 1;
      }
    }
    return 0;
  }

  /// Alternate-version markers. A candidate carrying one of these when the
  /// expected title doesn't is almost always the wrong recording, even when
  /// every other word matches.
  static const variantWords = {
    "live",
    "remix",
    "cover",
    "acoustic",
    "instrumental",
    "karaoke",
    "sped",
    "slowed",
    "nightcore",
    "reverb",
    "mashup",
    "demo",
    "unplugged",
  };

  /// Variant markers present in [candidate] but not in [expected]
  /// (normalized word-wise).
  static Set<String> mismatchedVariants(String expected, String candidate) {
    final expectedWords = normalize(expected).split(" ").toSet();
    final candidateWords = normalize(candidate).split(" ").toSet();
    return variantWords
        .where((w) => candidateWords.contains(w) && !expectedWords.contains(w))
        .toSet();
  }

  /// Combined score: title 60%, artist 40%, with duration and
  /// alternate-version corrections.
  static double score({
    required String expectedTitle,
    required String candidateTitle,
    required List<String> expectedArtists,
    required List<String> candidateArtists,
    int expectedDurationMs = 0,
    int candidateDurationMs = 0,
  }) {
    var value = titleSimilarity(expectedTitle, candidateTitle) * 0.6 +
        artistSimilarity(expectedArtists, candidateArtists) * 0.4;

    // A "(Live)" / "(Remix)" / etc. candidate for a plain studio title is the
    // wrong recording no matter how well the words overlap.
    final variants = mismatchedVariants(expectedTitle, candidateTitle).length;
    value -= (variants * 0.3).clamp(0.0, 0.6);

    if (expectedDurationMs > 0 && candidateDurationMs > 0) {
      final diff = (expectedDurationMs - candidateDurationMs).abs();
      if (diff <= 3000) {
        value += 0.05;
      } else if (diff > 30000) {
        value -= 0.3;
      } else if (diff > 10000) {
        value -= 0.1;
      }
    }
    return value;
  }
}
