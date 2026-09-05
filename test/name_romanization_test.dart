import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/services/spotiflac/name_romanization.dart';

List<String> forms(String name) =>
    (NameRomanization.candidates(name) ?? const <RomanizedName>[])
        .map((f) => f.joined)
        .toList();

void main() {
  group('Hangul', () {
    test('Revised Romanization of the syllable block', () {
      expect(forms('이무진'), contains('imujin'));
      expect(forms('정승환'), contains('jeongseunghwan'));
      expect(forms('김광석'), contains('gimgwangseok'));
    });

    test('the conventional surname spellings RR never produces', () {
      // Revised Romanization renders 이 as "I" and 박 as "Bak", but catalogs
      // credit them "Lee" and "Park" — without these the common case misses.
      expect(forms('이무진'), contains('leemujin'));
      expect(forms('박효신'), contains('parkhyosin'));
      expect(forms('정승환'), contains('jungseunghwan'));
    });

    test('a surname spelling only applies to the leading syllable', () {
      // 진 is a surname too, but here it ends a given name.
      expect(forms('이무진').where((f) => f.contains('chin')), isEmpty);
    });
  });

  group('kana', () {
    test('katakana artist names romanize to their credited spelling', () {
      expect(forms('ヨルシカ'), contains('yorushika'));
      expect(forms('キタニタツヤ'), contains('kitanitatsuya'));
    });

    test('small kana form yoon rather than a literal glide', () {
      // ミョ is "myo", and シャ is "sha" — not "shya".
      expect(forms('アイミョン'), contains('aimyon'));
      expect(forms('シャ'), contains('sha'));
    });

    test('hiragana maps through the same table as katakana', () {
      expect(forms('よるしか'), contains('yorushika'));
    });
  });

  group('scripts with no deterministic mapping report failure', () {
    // Callers rely on null meaning "unreadable", NOT "no match".
    test('Han ideographs', () => expect(NameRomanization.candidates('米津玄師'), isNull));
    test('Cyrillic', () => expect(NameRomanization.candidates('Кино'), isNull));
    test('mixed kanji and kana', () {
      expect(NameRomanization.candidates('宇多田ヒカル'), isNull);
    });
  });

  test('a Latin name romanizes to itself', () {
    expect(forms('Lee Mujin'), ['leemujin']);
  });

  group('fold reconciles the competing romanization systems', () {
    test('Korean vowel systems', () {
      // Revised "Jeong", McCune "Chung", passport "Jung".
      expect(NameRomanization.fold('jeong'), NameRomanization.fold('jung'));
      expect(NameRomanization.fold('jeong'), NameRomanization.fold('chung'));
      expect(NameRomanization.fold('mun'), NameRomanization.fold('moon'));
      expect(NameRomanization.fold('seo'), NameRomanization.fold('suh'));
    });

    test('Hepburn sibilants against Revised', () {
      expect(NameRomanization.fold('hyoshin'), NameRomanization.fold('hyosin'));
    });

    test('it does not collapse genuinely different names', () {
      expect(NameRomanization.fold('rumblefish'),
          isNot(NameRomanization.fold('leemujin')));
      expect(NameRomanization.fold('yorushika'),
          isNot(NameRomanization.fold('yoasobi')));
    });
  });
}
