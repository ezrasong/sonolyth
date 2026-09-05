import 'package:sonolyth/services/spotiflac/name_romanization.dart';

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

  /// Comparable tokens of one artist name, in the order written. Duplicates
  /// are kept — "Duran Duran" is not "Duran".
  static List<String> _artistTokenList(String value) => normalize(value)
      .split(" ")
      .where((w) => w.isNotEmpty && !_artistStopTokens.contains(w))
      .toList();

  static Set<String> _artistTokens(String value) =>
      _artistTokenList(value).toSet();

  /// Every individually comparable name in a credit list: each field as
  /// written, plus each collaborator once the field is split on the common
  /// separators.
  static List<String> _artistPieces(List<String> fields) {
    final pieces = <String>[];
    for (final field in fields) {
      for (final piece in [field, ...field.split(_artistSplitRegex)]) {
        if (_artistTokenList(piece).isNotEmpty) pieces.add(piece);
      }
    }
    return pieces;
  }

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
    final candidatePieces = _artistPieces(candidate);
    for (final artist in expected) {
      final tokens = _artistTokens(artist);
      if (tokens.isEmpty) continue;
      for (final other in candidatePieces) {
        final otherTokens = _artistTokens(other);
        if (tokens.length == otherTokens.length &&
            otherTokens.containsAll(tokens)) {
          return 1;
        }
        if (_subsetWithForeignLeftovers(tokens, otherTokens)) return 1;
        if (_sameNameWrittenDifferently(artist, other)) return 1;
      }
    }
    return 0;
  }

  /// Minimum length, in letters with every space removed, before the
  /// spelling-tolerant comparisons below may fire. Short names reassemble into
  /// one another far too easily ("Lee Hi", "Sia"), and pinning the wrong
  /// artist is worse than failing to match at all.
  static const _minComparableNameLength = 6;

  /// Providers spell the same artist differently in three ways that plain text
  /// comparison reads as three different people:
  ///
  ///  * **spacing** — "LEE MU JIN" against "Lee Mujin";
  ///  * **name order** — some catalogs credit given-name-first, "Mujin Lee";
  ///  * **script** — the metadata provider credits "이무진" natively while the
  ///    lossless catalog romanizes it.
  ///
  /// All three are handled the same way: reduce both names to their plausible
  /// romanizations (a Latin name romanizes to itself), then ask whether one
  /// side's pieces spell the other side out exactly.
  static bool _sameNameWrittenDifferently(String expected, String candidate) {
    final expectedForms = _romanizations(expected);
    final candidateForms = _romanizations(candidate);
    if (expectedForms == null || candidateForms == null) return false;
    for (final a in expectedForms) {
      for (final b in candidateForms) {
        if (_formsAgree(a, b)) return true;
        // Only if the exact spellings disagree: the competing romanization
        // systems ("Jeong"/"Jung"/"Chung") reduce to a common form.
        if (_formsAgree(a.folded, b.folded)) return true;
      }
    }
    return false;
  }

  static List<RomanizedName>? _romanizations(String name) =>
      NameRomanization.candidates(_artistTokenList(name).join(" "));

  static bool _formsAgree(RomanizedName a, RomanizedName b) {
    final left = a.joined;
    final right = b.joined;
    if (left.length != right.length) return false;
    if (left.length < _minComparableNameLength) return false;
    if (left == right) return true;
    return _piecesSpell(a.pieces, right) || _piecesSpell(b.pieces, left);
  }

  /// Whether [pieces] can be concatenated, in some order, to spell [target]
  /// exactly.
  ///
  /// Deliberately stricter than comparing sorted letters: "Silent" and
  /// "Listen" are anagrams, but neither spells the other out of whole pieces,
  /// so they stay different artists.
  static bool _piecesSpell(List<String> pieces, String target) {
    if (pieces.isEmpty) return target.isEmpty;
    if (pieces.length > _maxReorderablePieces) return false;
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (piece.isEmpty || !target.startsWith(piece)) continue;
      final rest = [...pieces]..removeAt(i);
      if (_piecesSpell(rest, target.substring(piece.length))) return true;
    }
    return false;
  }

  /// Caps the reordering search — names this long are not being re-ordered,
  /// and the permutation count would stop being free.
  static const _maxReorderablePieces = 6;

  /// Whether the two credit lists carry no comparable information: every
  /// expected/candidate pairing puts a Latin name against a native-script one.
  ///
  /// This is NOT the same as disagreeing. Romanization is best-effort — an
  /// artist's own chosen spelling routinely departs from any system ("헤이즈"
  /// romanizes to "heijeu" but is credited "Heize") — so a failed romanization
  /// is silence, not a verdict, and [score] softens the wrong-artist penalty
  /// rather than rejecting outright. [_sameNameWrittenDifferently] only ever
  /// ADDS evidence: it can turn a non-match into a match, never the reverse.
  static bool artistsAreIncomparable(
    List<String> expected,
    List<String> candidate,
  ) {
    final expectedNames =
        expected.where((a) => _artistTokenList(a).isNotEmpty).toList();
    final candidateNames = _artistPieces(candidate);
    if (expectedNames.isEmpty || candidateNames.isEmpty) return false;
    for (final a in expectedNames) {
      for (final b in candidateNames) {
        if (!_scriptsIncomparable(a, b)) return false;
      }
    }
    return true;
  }

  /// Latin against native script. Two names in the SAME script were compared
  /// as text and genuinely disagree, so that stays real evidence.
  static bool _scriptsIncomparable(String a, String b) =>
      _isLatinName(a) != _isLatinName(b);

  static bool _isLatinName(String name) {
    final text = _artistTokenList(name).join();
    return text.isNotEmpty && !text.runes.any((r) => r > 0x7F);
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
    // An alternate version (live/cover/piano/instrumental/...) is never a
    // plausible stand-in for the studio recording, however close the title
    // and length happen to be.
    if (isVariantMismatch(expectedTitle, candidateTitle)) return false;
    return titleRelated && durationDiffSeconds <= 60;
  }

  /// Alternate-version markers. A candidate carrying one of these when the
  /// expected title doesn't is a DIFFERENT RECORDING, and is rejected
  /// outright — never merely penalised (see [isVariantMismatch]).
  static const variantWords = {
    // performance context
    "live", "unplugged", "concert", "tour", "session", "sessions",
    "bootleg", "rehearsal", "soundcheck", "encore",
    // re-performance by someone else
    "cover", "covered", "tribute", "karaoke", "rendition", "reinterpretation",
    // arrangement / instrumentation
    "instrumental", "acoustic", "piano", "orchestral", "orchestra",
    "symphonic", "strings", "guitar", "violin", "cello", "flute",
    "saxophone", "harp", "ukulele", "acapella", "accapella", "cappella",
    "lullaby", "musicbox", "chiptune", "8bit",
    // derivative edits
    "remix", "remixed", "mashup", "rework", "reworked", "reimagined",
    "stripped", "demo", "sped", "slowed", "nightcore", "reverb",
    "daycore", "8d", "vip",
    // vocal-removed / backing
    "backing", "playback", "minus",
  };

  /// Multi-word markers that identify a non-original recording no matter where
  /// they appear in the title — these phrases essentially never occur in a
  /// genuine studio track name, so they don't need to sit in a decoration
  /// segment to be conclusive.
  static const _variantPhrases = [
    "made famous by",
    "in the style of",
    "originally performed by",
    "as made popular by",
    "backing track",
    "karaoke version",
    "instrumental version",
    "piano version",
    "acoustic version",
    "live version",
    "cover version",
    "8d audio",
    "sped up",
    "slowed down",
    "slowed reverb",
    "tribute to",
    "music box",
    "live at",
    "live from",
    "live in",
    "live on",
    "recorded live",
  ];

  /// Splits a title into its "decoration" segments: bracketed groups
  /// (`(Live)`, `[Acoustic]`) and any dash-separated trailing part
  /// (`Song - 2011 Remaster`). Variant markers are only conclusive when they
  /// decorate the title — otherwise "Live and Let Die" or "Piano Man" would
  /// reject themselves, and a word-set comparison can't tell the difference
  /// (the marker appears in BOTH titles, so it cancels out).
  static List<String> _decorationSegments(String title) {
    final segments = <String>[];
    for (final match
        in RegExp(r"[\(\[]([^\)\]]*)[\)\]]").allMatches(title)) {
      segments.add(match.group(1) ?? "");
    }
    // Everything after the first " - " is a trailing descriptor.
    final dash = RegExp(r"\s[-–—]\s").firstMatch(title);
    if (dash != null) segments.add(title.substring(dash.end));
    return segments;
  }

  /// Variant markers decorating [title], as normalized words.
  static Set<String> _decorationVariants(String title) {
    final found = <String>{};
    for (final segment in _decorationSegments(title)) {
      final words = normalize(segment).split(" ").toSet();
      found.addAll(variantWords.where(words.contains));
    }
    return found;
  }

  /// Normalized whole-title text used for phrase probing.
  static String _phraseText(String title) => normalize(title);

  static Set<String> _phraseVariants(String title) {
    final text = _phraseText(title);
    return _variantPhrases.where(text.contains).toSet();
  }

  /// Variant markers present in [candidate] but not in [expected].
  ///
  /// Compares DECORATION segments rather than raw word sets, so a marker that
  /// is part of the song's real name ("Live and Let Die", "Piano Man",
  /// "Cover Me") is never treated as a variant, while "Song (Live)" and
  /// "Song - Piano Version" are.
  static Set<String> mismatchedVariants(String expected, String candidate) {
    final expectedMarkers = _decorationVariants(expected)
      ..addAll(_phraseVariants(expected));
    final candidateMarkers = _decorationVariants(candidate)
      ..addAll(_phraseVariants(candidate));
    return candidateMarkers.difference(expectedMarkers);
  }

  /// HARD gate: true when [candidate] is an alternate version (live, cover,
  /// karaoke, piano/instrumental, remix, sped-up, ...) of a track the user did
  /// NOT ask for. Callers must reject such a candidate outright rather than
  /// score it down — a score penalty alone still lets a strong title+artist
  /// match clear the acceptance threshold, which is exactly how live and
  /// piano renditions kept getting matched and downloaded.
  static bool isVariantMismatch(String expectedTitle, String candidateTitle) =>
      mismatchedVariants(expectedTitle, candidateTitle).isNotEmpty;

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
    final titleScore = titleSimilarity(expectedTitle, candidateTitle);
    var value = titleScore * 0.6 + artistScore * 0.4;

    // Only apply the wrong-artist penalty when the candidate actually reports
    // artists — some provider payloads omit them, and an absent credit is not
    // evidence of a mismatch.
    final candidateHasArtists =
        candidateArtists.any((a) => normalize(a).isNotEmpty);
    if (artistScore == 0 && expectedArtists.isNotEmpty && candidateHasArtists) {
      // A credit in another script is silence, not disagreement, so the full
      // penalty would reject correct tracks on no evidence. Soften it — but
      // only for a title that matches EXACTLY. With no usable artist evidence
      // the title is all that is left, and a merely-similar one is not enough
      // to pin a track to the wrong artist. A same-title, same-length
      // candidate then still clears the 0.5 threshold; nothing weaker does.
      final noArtistEvidence = titleScore == 1 &&
          artistsAreIncomparable(expectedArtists, candidateArtists);
      value -= noArtistEvidence ? 0.1 : 0.4;
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
