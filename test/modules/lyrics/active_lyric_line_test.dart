import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/modules/lyrics/active_lyric_line.dart';

void main() {
  const lyrics = <int, String>{
    3: 'first',
    7: 'second',
    12: 'third',
    40: 'last',
  };

  group('activeLyricSecond', () {
    test('no line is active before the first stamp', () {
      expect(activeLyricSecond(lyrics, Duration.zero), -1);
      expect(activeLyricSecond(lyrics, const Duration(seconds: 2)), -1);
    });

    test('an exact hit selects that line', () {
      expect(activeLyricSecond(lyrics, const Duration(seconds: 7)), 7);
    });

    test('between two stamps the earlier line stays active', () {
      // The old `containsKey` match only moved on an exact whole-second hit,
      // so a stamp falling between two position ticks was never lit.
      expect(activeLyricSecond(lyrics, const Duration(seconds: 9)), 7);
      expect(
        activeLyricSecond(lyrics, const Duration(seconds: 12, milliseconds: 900)),
        12,
      );
    });

    test('past the last stamp the last line stays active', () {
      expect(activeLyricSecond(lyrics, const Duration(minutes: 3)), 40);
    });

    test('a seek backwards lands on the earlier line at once', () {
      expect(activeLyricSecond(lyrics, const Duration(seconds: 39)), 12);
      expect(activeLyricSecond(lyrics, const Duration(seconds: 4)), 3);
    });

    test('delay shifts the comparison point', () {
      expect(activeLyricSecond(lyrics, const Duration(seconds: 5), delay: 2), 7);
      expect(activeLyricSecond(lyrics, const Duration(seconds: 5), delay: -3), -1);
    });

    test('an empty map (new track, lyrics still loading) has no active line', () {
      expect(activeLyricSecond(const {}, const Duration(seconds: 30)), -1);
    });

    test('key order does not matter', () {
      const shuffled = <int, String>{40: 'last', 3: 'first', 12: 'third', 7: 'second'};
      expect(activeLyricSecond(shuffled, const Duration(seconds: 20)), 12);
    });
  });
}
