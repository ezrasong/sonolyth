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
  /// Strips punctuation but keeps ALL letters and digits (any script).
  /// The old `[^a-z0-9\s]` deleted every non-ASCII character, so CJK /
  /// Cyrillic / Greek / Arabic titles and artists normalized to the empty
  /// string and text matching failed outright for non-Latin music.
  static final _nonAlphaNum = RegExp(r"[^\p{L}\p{N}\s]", unicode: true);
  static final _spaces = RegExp(r"\s+");

  /// Bracketed release descriptors that DON'T change the recording's identity —
  /// "Song (Remastered 2011)", "[Deluxe Edition]", "(2019 Remaster)" — pure
  /// matching noise. Word-overlap scoring otherwise drops a valid track to a
  /// low score just because the provider tagged it with a remaster/edition
  /// suffix the Spotify title lacks (or vice-versa). Variant markers
  /// (live/remix/acoustic/...) are deliberately NOT stripped — those ARE
  /// different recordings and must keep failing the match (see [variantWords]).
  // NB: "version"/"mix"/"edit" are intentionally absent — a re-recording
  // ("Taylor's Version"), radio edit, or remix is a DIFFERENT recording, so
  // stripping those would match the wrong audio.
  static final _descriptorGroupRegex = RegExp(
    r"\s*[\(\[][^\)\]]*\b(re-?master(ed)?|reissue|deluxe|expanded|anniversary|bonus|mono|stereo|edition)\b[^\)\]]*[\)\]]",
    caseSensitive: false,
  );

  /// Unbracketed trailing descriptor, e.g. "Song - 2011 Remaster".
  static final _trailingDescriptorRegex = RegExp(
    r"\s*-\s*(\d{4}\s+)?(re-?master(ed)?|reissue)(\s+\d{4})?\s*$",
    caseSensitive: false,
  );

  static String normalize(String value) {
    var text = value.toLowerCase();
    text = text.replaceAll(_featureRegex, " ");
    text = text.replaceAll(_bareFeatureRegex, " ");
    text = text.replaceAll(_descriptorGroupRegex, " ");
    text = text.replaceAll(_trailingDescriptorRegex, " ");
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

  /// Separators providers use when cramming several collaborators into one
  /// artist field ("A, B", "A & B", "A feat. B"). Brackets are separators too:
  /// providers commonly credit an artist as native-plus-romanized —
  /// "아이유 (IU)" — and each bracketed part must be comparable on its own.
  /// NOT split on: "and" (handled as a stop token so band names survive) and
  /// "x" (splitting is simultaneous across all separators, so "Lil Nas X,
  /// Jack Harlow" would shred the "Lil Nas X" piece).
  static final _artistSplitRegex = RegExp(
    r"\s*(?:[,;/+&·()\[\]]|\bfeat\.?(?=\s)|\bft\.?(?=\s)|\bfeaturing\b|\bwith\b|\bvs\.?(?=\s))\s*",
    caseSensitive: false,
  );

  /// Connector words that vary freely between providers' renderings of the
  /// same name ("Simon & Garfunkel" vs "Simon and Garfunkel" — `&` is
  /// already stripped as punctuation, so drop "and" too before comparing;
  /// "The Chainsmokers" vs "Chainsmokers" likewise for "the").
  static const _artistStopTokens = {"and", "the"};

  static Set<String> _artistTokens(String value) => normalize(value)
      .split(" ")
      .where((w) => w.isNotEmpty && !_artistStopTokens.contains(w))
      .toSet();

  /// 1.0 when any expected artist IS one of the credited candidate artists —
  /// same normalized token set, not substring containment ("George" must not
  /// match "George Hampton", and "Sia" must not match "Siavash"). Candidate
  /// fields that pack several collaborators into one string are also compared
  /// per collaborator after splitting on the common separators.
  static double artistSimilarity(
    List<String> expected,
    List<String> candidate,
  ) {
    if (expected.isEmpty || candidate.isEmpty) return 0;
    final candidateTokenSets = <Set<String>>[];
    for (final field in candidate) {
      for (final piece in [field, ...field.split(_artistSplitRegex)]) {
        final tokens = _artistTokens(piece);
        if (tokens.isNotEmpty) candidateTokenSets.add(tokens);
      }
    }
    for (final artist in expected) {
      final tokens = _artistTokens(artist);
      if (tokens.isEmpty) continue;
      for (final other in candidateTokenSets) {
        if (tokens.length == other.length && other.containsAll(tokens)) {
          return 1;
        }
        if (_subsetWithForeignLeftovers(tokens, other)) return 1;
      }
    }
    return 0;
  }

  static final _latinToken = RegExp(r"[a-z0-9]");

  /// Same-artist "native + romanized" credits whose own name contains
  /// brackets — "(여자)아이들 ((G)I-DLE)" — can't be recovered by splitting
  /// (the split shreds the bracketed name itself). Accept a candidate that
  /// contains ALL expected tokens when every leftover token is in a different
  /// script: the leftovers are then the same name written natively, not a
  /// different artist. "George" vs "George Hampton" stays rejected — the
  /// leftover "hampton" is the same script.
  static bool _subsetWithForeignLeftovers(
    Set<String> expected,
    Set<String> candidate,
  ) {
    if (expected.isEmpty || !candidate.containsAll(expected)) return false;
    final leftovers = candidate.difference(expected);
    if (leftovers.isEmpty) return false;
    bool latin(String t) => _latinToken.hasMatch(t);
    if (expected.every(latin)) return leftovers.every((t) => !latin(t));
    if (expected.every((t) => !latin(t))) return leftovers.every(latin);
    return false;
  }

  /// Whether a fallback candidate is even plausibly the same song: its title
  /// shares real material with the expected one AND its length is roughly
  /// right. Used to keep an all-wrong search result set from being played
  /// "best first" and to avoid pinning such a pick permanently.
  static bool plausibleCandidate({
    required String expectedTitle,
    required String candidateTitle,
    required int expectedDurationMs,
    required int candidateDurationMs,
  }) {
    final normalizedExpected = normalize(expectedTitle);
    final normalizedCandidate = normalize(candidateTitle);
    final titleRelated = (normalizedExpected.isNotEmpty &&
            normalizedCandidate.contains(normalizedExpected)) ||
        titleSimilarity(expectedTitle, candidateTitle) >= 0.45;
    final durationDiffSeconds =
        ((expectedDurationMs - candidateDurationMs) ~/ 1000).abs();
    return titleRelated && durationDiffSeconds <= 60;
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
  /// alternate-version corrections. A candidate whose credited artists share
  /// nothing with the expected ones is treated as a different song outright
  /// (covers, karaoke, same-title tracks by someone else), not just a weaker
  /// match: a perfect title alone (0.6 + up to 0.05 duration) would otherwise
  /// clear the 0.5 acceptance threshold every provider uses.
  static double score({
    required String expectedTitle,
    required String candidateTitle,
    required List<String> expectedArtists,
    required List<String> candidateArtists,
    int expectedDurationMs = 0,
    int candidateDurationMs = 0,
  }) {
    final artistScore = artistSimilarity(expectedArtists, candidateArtists);
    var value = titleSimilarity(expectedTitle, candidateTitle) * 0.6 +
        artistScore * 0.4;

    // Only apply the wrong-artist penalty when the candidate actually reports
    // artists — some provider payloads omit them, and an absent credit is not
    // evidence of a mismatch.
    final candidateHasArtists =
        candidateArtists.any((a) => normalize(a).isNotEmpty);
    if (artistScore == 0 && expectedArtists.isNotEmpty && candidateHasArtists) {
      value -= 0.4;
    }

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
