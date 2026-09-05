import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/modules/player/player.dart';
import 'package:sonolyth/modules/player/player_overlay_collapsed.dart';

/// CONTEXT item 42: the skin's own controls are under Android's 48dp minimum,
/// and the answer is to grow the **box**, never the glyph.
///
/// That only works if the drawn control does not move, and moving it is
/// exactly what a box that grows in a `Row` does unless the gap beside it
/// gives the same amount back. These compute the transport row and the mini
/// player's play button from first principles and check both halves: every
/// control is at least [kMinTapTarget] of target, and every drawn centre is
/// where §31 measured it against the Play Store shot.
///
/// Numbers are arithmetic on the metric constants rather than pumped widgets,
/// deliberately: the row is laid out from these and nothing else, and a test
/// that pumps a player needs a platform channel to build one.
void main() {
  group('the transport is 48dp of target everywhere', () {
    test('the ±10s dots gained the most, and needed to', () {
      // 14dp of glyph plus 8dp of padding is 30dp — measured in the device's
      // accessibility tree as `[73,2046][152,2124]`, 79px at density 2.625.
      expect(
        ZenithPlayerMetrics.dotSize + ZenithPlayerMetrics.proButtonPadding * 2,
        30.0,
      );
      expect(
        ZenithPlayerMetrics.proButtonBox(ZenithPlayerMetrics.dotSize),
        kMinTapTarget,
      );
    });

    test('prev and next were two short of it', () {
      expect(
        ZenithPlayerMetrics.prevNextSize +
            ZenithPlayerMetrics.proButtonPadding * 2,
        46.0,
      );
      expect(
        ZenithPlayerMetrics.proButtonBox(ZenithPlayerMetrics.prevNextSize),
        kMinTapTarget,
      );
    });

    test('play was already over it and is left exactly as it was', () {
      // 56dp. Growing a box that is already big enough would move the row.
      expect(
        ZenithPlayerMetrics.proButtonBox(ZenithPlayerMetrics.playSize),
        ZenithPlayerMetrics.playSize +
            ZenithPlayerMetrics.proButtonPadding * 2,
      );
      expect(ZenithPlayerMetrics.proButtonBleed(ZenithPlayerMetrics.playSize),
          0.0);
    });
  });

  group('nothing drawn moved', () {
    /// Centre-to-centre distance between two neighbouring controls, as laid
    /// out: half of each box, plus the gap between them.
    double spacing(double a, double b, double gap) =>
        ZenithPlayerMetrics.proButtonBox(a) / 2 +
        gap +
        ZenithPlayerMetrics.proButtonBox(b) / 2;

    /// The same distance in the picture, where a control's box is only ever
    /// the glyph plus its padding.
    double drawnSpacing(double a, double b, double gap) =>
        (a + ZenithPlayerMetrics.proButtonPadding * 2) / 2 +
        gap +
        (b + ZenithPlayerMetrics.proButtonPadding * 2) / 2;

    test('dot to prev/next', () {
      expect(
        spacing(
          ZenithPlayerMetrics.dotSize,
          ZenithPlayerMetrics.prevNextSize,
          ZenithPlayerMetrics.laidOutDotGap,
        ),
        drawnSpacing(
          ZenithPlayerMetrics.dotSize,
          ZenithPlayerMetrics.prevNextSize,
          ZenithPlayerMetrics.dotGap,
        ),
      );
    });

    test('prev/next to play', () {
      expect(
        spacing(
          ZenithPlayerMetrics.prevNextSize,
          ZenithPlayerMetrics.playSize,
          ZenithPlayerMetrics.laidOutTransportGap,
        ),
        drawnSpacing(
          ZenithPlayerMetrics.prevNextSize,
          ZenithPlayerMetrics.playSize,
          ZenithPlayerMetrics.transportGap,
        ),
      );
    });

    test('a gap can never be given away twice', () {
      // The row is centred, so a gap driven negative would silently overlap
      // two controls rather than raising anything.
      expect(ZenithPlayerMetrics.laidOutDotGap, greaterThan(0));
      expect(ZenithPlayerMetrics.laidOutTransportGap, greaterThan(0));
    });
  });

  group('the mini player play button', () {
    test('is 48dp of target', () {
      expect(ZenithMiniPlayerMetrics.playButtonSize, 40.0);
      expect(ZenithMiniPlayerMetrics.playTapBox, kMinTapTarget);
    });

    test('keeps the glyph on its measured centre', () {
      expect(
        ZenithMiniPlayerMetrics.playTapInset +
            ZenithMiniPlayerMetrics.playTapBox / 2,
        ZenithMiniPlayerMetrics.playButtonInset +
            ZenithMiniPlayerMetrics.playButtonSize / 2,
      );
    });

    test('leaves the title line exactly where it was', () {
      // `MiniplayerTitleLineMarginLeft` — the one number on this row that a
      // viewer would actually see move.
      expect(
        ZenithMiniPlayerMetrics.playTapInset +
            ZenithMiniPlayerMetrics.playTapBox +
            ZenithMiniPlayerMetrics.playTapToText,
        ZenithMiniPlayerMetrics.textInsetLeft,
      );
    });

    test('takes its room out of the gap, not out of the screen edge', () {
      expect(ZenithMiniPlayerMetrics.playTapInset, greaterThan(0));
      expect(ZenithMiniPlayerMetrics.playTapToText, greaterThan(0));
    });
  });
}
