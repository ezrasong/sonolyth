/// One romanization of a name, kept as the per-syllable/per-word pieces it was
/// built from rather than a single string.
///
/// The pieces matter: a native credit carries no word boundaries ("이무진" is
/// one token), while the catalog's Latin credit does ("LEE MU JIN"), and the
/// two providers disagree about where those boundaries fall and in which order
/// the parts are written. Keeping the pieces lets a caller re-assemble them in
/// any order to see whether the two spellings describe the same name.
class RomanizedName {
  const RomanizedName(this.pieces);

  /// Lowercase ASCII fragments, in the order the source name wrote them.
  final List<String> pieces;

  /// The whole name with every boundary removed.
  String get joined => pieces.join();

  /// The same name reduced to [NameRomanization.fold]ed pieces, for comparing
  /// across romanization systems.
  RomanizedName get folded =>
      RomanizedName(pieces.map(NameRomanization.fold).toList());
}

/// Best-effort romanization of native-script names, so a metadata credit
/// written natively ("이무진") can be compared with a lossless catalog's Latin
/// credit ("LEE MU JIN"). The two providers routinely disagree on which form to
/// use, and a plain text comparison then reads one artist as two different
/// people — which is exactly how Korean and Japanese tracks failed to match.
///
/// This is deliberately NOT a general transliteration library. It covers only
/// the scripts whose mapping is deterministic — Hangul syllables (Revised
/// Romanization, plus the conventional surname spellings RR does not produce,
/// since no Korean artist is ever credited "I Mujin") and Japanese kana — and
/// reports failure for everything else: Han ideographs, Cyrillic, Arabic, Thai.
///
/// Callers MUST treat that failure as "these two names are not comparable",
/// never as "these two names disagree". Inventing a mismatch out of a name we
/// cannot read is how a correct track gets rejected.
abstract class NameRomanization {
  /// Every plausible romanization of [name], or `null` when it contains a
  /// character with no deterministic mapping.
  ///
  /// A name that is already Latin comes back unchanged (one form, split on
  /// whitespace), so callers can run both sides through this uniformly.
  static List<RomanizedName>? candidates(String name) {
    final pieces = <String>[];
    final latin = StringBuffer();
    List<String>? surnameSpellings;
    var pendingSokuon = false;

    void flushLatin() {
      if (latin.isEmpty) return;
      pieces.add(latin.toString());
      latin.clear();
    }

    for (final rune in name.toLowerCase().runes) {
      final char = String.fromCharCode(rune);

      // ASCII letters and digits pass straight through, accumulating into one
      // piece per whitespace-delimited word.
      if ((rune >= 0x61 && rune <= 0x7A) || (rune >= 0x30 && rune <= 0x39)) {
        latin.write(char);
        continue;
      }
      if (char.trim().isEmpty) {
        flushLatin();
        continue;
      }

      // Hangul syllable block.
      if (rune >= _hangulBase && rune <= _hangulLast) {
        flushLatin();
        // Only the leading syllable can be a surname, and only when it opens
        // the whole name.
        if (pieces.isEmpty) surnameSpellings = _hangulSurnames[char];
        pieces.add(_romanizeHangul(rune));
        continue;
      }

      // Kana: fold hiragana onto katakana so one table serves both.
      var kana = rune;
      if (kana >= 0x3041 && kana <= 0x3096) kana += 0x60;

      // ー prolonged-sound mark: a lengthened vowel, dropped (the fold
      // collapses doubled letters anyway).
      if (kana == 0x30FC) continue;

      // ッ sokuon: geminates the following consonant.
      if (kana == 0x30C3) {
        pendingSokuon = true;
        continue;
      }

      final smallY = _smallYKana[kana];
      final smallVowel = _smallVowelKana[kana];
      if ((smallY != null || smallVowel != null) && pieces.isNotEmpty) {
        pieces[pieces.length - 1] = smallY != null
            ? _applyYoon(pieces.last, smallY)
            : pieces.last.replaceFirst(_trailingVowel, '') + smallVowel!;
        continue;
      }

      final romaji = _katakana[kana];
      if (romaji == null) return null; // Han, Cyrillic, Arabic, ... — unreadable
      flushLatin();
      pieces.add(pendingSokuon ? romaji[0] + romaji : romaji);
      pendingSokuon = false;
    }
    flushLatin();

    if (pieces.isEmpty) return null;

    final forms = <RomanizedName>[RomanizedName(pieces)];
    for (final spelling in surnameSpellings ?? const <String>[]) {
      forms.add(RomanizedName([spelling, ...pieces.skip(1)]));
    }
    return forms;
  }

  /// Reduces a romanization to a form shared by the competing romanization
  /// systems, so "Jeong" (Revised), "Chung" (McCune-Reischauer) and "Jung"
  /// (passport spelling) all compare equal.
  ///
  /// Lossy on purpose — it is only ever consulted after an exact comparison has
  /// already failed, and callers gate it behind a minimum name length so short
  /// handles cannot collide by accident.
  static String fold(String value) {
    var text = value.toLowerCase().replaceAll(_nonAscii, '');

    // Vowel systems. RR writes ㅓ/ㅡ as "eo"/"eu"; passport spellings use
    // "u"/"oo"/"ou". Collapse the lot onto one symbol.
    for (final vowel in const ['eo', 'eu', 'oo', 'ou', 'wu']) {
      text = text.replaceAll(vowel, 'u');
    }
    text = text.replaceAll('ae', 'e');

    // A trailing "h" after a vowel is an English lengthening spelling —
    // "Suh"/"Seo", "Ahn"/"An", "Oh"/"O", "Huh"/"Heo".
    text = text.replaceAllMapped(_vowelThenH, (m) => m[1]!);

    // The sibilant/affricate fork: Hepburn "sh"/"ch" against RR "s"/"j".
    text = text.replaceAll('sh', 's').replaceAll('ch', 'j');

    // Voiced/voiceless pairs are chosen differently by every system
    // ("Kim"/"Gim", "Park"/"Bak", "Ryu"/"Lyu").
    final buffer = StringBuffer();
    for (final char in text.split('')) {
      buffer.write(_consonantPairs[char] ?? char);
    }

    // "Lee"/"Le", "Woo"/"Wo" — doubled letters carry no distinction here.
    return buffer.toString().replaceAllMapped(_doubledLetter, (m) => m[1]!);
  }

  static final _nonAscii = RegExp(r'[^a-z0-9]');
  static final _vowelThenH = RegExp(r'([aeiou])h');
  static final _doubledLetter = RegExp(r'(.)\1+');
  static final _trailingVowel = RegExp(r'[aiueo]$');

  static const _consonantPairs = {
    'k': 'g',
    't': 'd',
    'p': 'b',
    'l': 'r',
  };

  // ---------------------------------------------------------------------
  // Hangul
  // ---------------------------------------------------------------------

  static const _hangulBase = 0xAC00;
  static const _hangulLast = 0xD7A3;

  static const _hangulInitials = [
    'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '', //
    'j', 'jj', 'ch', 'k', 't', 'p', 'h',
  ];

  static const _hangulMedials = [
    'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', //
    'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i',
  ];

  static const _hangulFinals = [
    '', 'k', 'k', 'k', 'n', 'n', 'n', 't', 'l', 'k', 'm', 'p', 't', 't', //
    'p', 'l', 'm', 'p', 'p', 't', 't', 'ng', 't', 't', 'k', 't', 'p', 't',
  ];

  static String _romanizeHangul(int rune) {
    final index = rune - _hangulBase;
    return _hangulInitials[index ~/ 588] +
        _hangulMedials[(index % 588) ~/ 28] +
        _hangulFinals[index % 28];
  }

  /// Conventional Latin spellings of the common Korean surnames. Revised
  /// Romanization would render 이 as "I" and 박 as "Bak", but essentially every
  /// catalog credits them "Lee" and "Park", so RR alone never matches.
  static const _hangulSurnames = <String, List<String>>{
    '이': ['lee', 'yi', 'rhee', 'ri'],
    '김': ['kim'],
    '박': ['park', 'pak'],
    '최': ['choi', 'choe'],
    '정': ['jung', 'chung', 'jong'],
    '강': ['kang'],
    '조': ['cho'],
    '윤': ['yoon', 'yun'],
    '장': ['jang', 'chang'],
    '임': ['lim', 'im', 'rim'],
    '한': ['han'],
    '오': ['oh'],
    '서': ['seo', 'suh'],
    '신': ['shin'],
    '권': ['kwon'],
    '황': ['hwang'],
    '안': ['ahn'],
    '송': ['song'],
    '류': ['ryu', 'yu', 'yoo'],
    '유': ['yu', 'yoo', 'you'],
    '전': ['jeon', 'jun', 'chun'],
    '홍': ['hong'],
    '고': ['ko', 'koh'],
    '문': ['moon', 'mun'],
    '손': ['son', 'sohn'],
    '양': ['yang'],
    '배': ['bae'],
    '백': ['baek', 'paek'],
    '허': ['heo', 'hur', 'huh'],
    '남': ['nam'],
    '심': ['shim', 'sim'],
    '노': ['noh', 'roh'],
    '하': ['ha'],
    '곽': ['kwak'],
    '성': ['sung', 'seong'],
    '차': ['cha'],
    '주': ['joo', 'ju'],
    '우': ['woo'],
    '구': ['koo', 'goo'],
    '민': ['min'],
    '나': ['na', 'ra'],
    '지': ['ji', 'chi'],
    '엄': ['eom', 'um'],
    '채': ['chae'],
    '원': ['won'],
    '천': ['chun', 'cheon'],
    '방': ['bang'],
    '공': ['kong', 'gong'],
    '현': ['hyun', 'hyeon'],
    '함': ['ham'],
    '변': ['byun', 'byeon'],
    '염': ['yeom', 'youm'],
    '여': ['yeo', 'yuh'],
    '추': ['chu', 'choo'],
    '도': ['do', 'doh'],
    '소': ['so', 'soh'],
    '석': ['seok', 'suk'],
  };

  // ---------------------------------------------------------------------
  // Kana
  // ---------------------------------------------------------------------

  /// Combines a consonant+i syllable with a small ya/yu/yo. Hepburn writes
  /// シャ "sha", not "shya", so the sibilants drop the glide.
  static String _applyYoon(String previous, String glide) {
    final stem =
        previous.endsWith('i') ? previous.substring(0, previous.length - 1) : previous;
    final sibilant =
        stem.endsWith('sh') || stem.endsWith('ch') || stem.endsWith('j');
    return stem + (sibilant ? glide.substring(1) : glide);
  }

  static const _smallYKana = {0x30E3: 'ya', 0x30E5: 'yu', 0x30E7: 'yo'};

  static const _smallVowelKana = {
    0x30A1: 'a',
    0x30A3: 'i',
    0x30A5: 'u',
    0x30A7: 'e',
    0x30A9: 'o',
  };

  static const _katakana = {
    0x30A2: 'a', 0x30A4: 'i', 0x30A6: 'u', 0x30A8: 'e', 0x30AA: 'o', //
    0x30AB: 'ka', 0x30AD: 'ki', 0x30AF: 'ku', 0x30B1: 'ke', 0x30B3: 'ko',
    0x30AC: 'ga', 0x30AE: 'gi', 0x30B0: 'gu', 0x30B2: 'ge', 0x30B4: 'go',
    0x30B5: 'sa', 0x30B7: 'shi', 0x30B9: 'su', 0x30BB: 'se', 0x30BD: 'so',
    0x30B6: 'za', 0x30B8: 'ji', 0x30BA: 'zu', 0x30BC: 'ze', 0x30BE: 'zo',
    0x30BF: 'ta', 0x30C1: 'chi', 0x30C4: 'tsu', 0x30C6: 'te', 0x30C8: 'to',
    0x30C0: 'da', 0x30C2: 'ji', 0x30C5: 'zu', 0x30C7: 'de', 0x30C9: 'do',
    0x30CA: 'na', 0x30CB: 'ni', 0x30CC: 'nu', 0x30CD: 'ne', 0x30CE: 'no',
    0x30CF: 'ha', 0x30D2: 'hi', 0x30D5: 'fu', 0x30D8: 'he', 0x30DB: 'ho',
    0x30D0: 'ba', 0x30D3: 'bi', 0x30D6: 'bu', 0x30D9: 'be', 0x30DC: 'bo',
    0x30D1: 'pa', 0x30D4: 'pi', 0x30D7: 'pu', 0x30DA: 'pe', 0x30DD: 'po',
    0x30DE: 'ma', 0x30DF: 'mi', 0x30E0: 'mu', 0x30E1: 'me', 0x30E2: 'mo',
    0x30E4: 'ya', 0x30E6: 'yu', 0x30E8: 'yo',
    0x30E9: 'ra', 0x30EA: 'ri', 0x30EB: 'ru', 0x30EC: 're', 0x30ED: 'ro',
    0x30EF: 'wa', 0x30F0: 'wi', 0x30F1: 'we', 0x30F2: 'o', 0x30F3: 'n',
    0x30F4: 'vu',
  };
}
