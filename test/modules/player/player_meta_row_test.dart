import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/modules/player/player.dart';
import 'package:sonolyth/modules/player/player_meta_row.dart';

/// The counter row under the seek line — elapsed, the codec chip, total.
///
/// At Android's 200% font size the counters take roughly twice the width they
/// were measured at, so the chip between them was squeezed until
/// `flac • 16bit • 44.1kHz` ellipsised to `flac • 16bit • 44.1…` and its ring
/// sat flush against the digits at both ends (§43g). §42c measured this slot
/// and found it fitted — with the shorter "Verify lossless" in it.
///
/// What these pin is the pair of properties the fix rests on: **the row is the
/// picture's, untouched, at the default font size** — the chip centred in the
/// slack the counters leave, never touching either — and **past the reflow
/// threshold the chip is no longer in the row at all**, so it has the full
/// width and neither counter can crowd it.
///
/// Widths are asserted, never glyph counts: the test font draws every
/// character as a full em square, so what a string measures here is not what it
/// measures on a device. The geometry is the same either way.
void main() {
  /// The player gives this row the art's width minus the seekbar's margins and
  /// the bar's own touch padding — about this much on a 411dp phone.
  const rowWidth = 363.0;

  /// Long enough to be squeezed at 200% between two counters and comfortable on
  /// a line of its own, in *this* font. On a device that is the real codec
  /// string; here it stands in for it.
  const codec = 'flac • 16bit';

  Widget host(
    Widget child, {
    TextScaler scaler = TextScaler.noScaling,
    double width = rowWidth,
  }) =>
      MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: ShadcnApp(
          home: Scaffold(
            child: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      );

  Widget row({
    String elapsed = '01:23',
    String total = '03:45',
    String label = codec,
  }) =>
      PlayerMetaRow(
        elapsed: elapsed,
        total: total,
        seeking: false,
        chip: PlayerMetaChip(label: label),
      );

  Rect rectOf(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Rect chipRect(WidgetTester tester) =>
      rectOf(tester, find.byType(PlayerMetaChip));

  bool ellipsised(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  group('at the default font size', () {
    testWidgets('the chip sits between the counters, centred on the row',
        (tester) async {
      await tester.pumpWidget(host(row()));

      final left = rectOf(tester, find.text('01:23'));
      final right = rectOf(tester, find.text('03:45'));
      final chip = chipRect(tester);

      // One line, all three of them: this is the measured picture.
      expect(left.top, moreOrLessEquals(right.top, epsilon: 0.5));
      expect(chip.center.dy, moreOrLessEquals(left.center.dy, epsilon: 1));
      expect(chip.left, greaterThan(left.right));
      expect(chip.right, lessThan(right.left));

      // `Zenith_TopMetaInfoLayout` centres between the two counters, and both
      // counters are the same width here, so the chip is centred on the row.
      expect(
        chip.center.dx,
        moreOrLessEquals(rectOf(tester, find.byType(PlayerMetaRow)).center.dx,
            epsilon: 1),
      );
    });

    testWidgets('the chip is never flush against a counter', (tester) async {
      // A label wide enough to take every pixel the slot has. Before the fix
      // the chip filled the `Expanded` exactly and its ring touched the digits
      // at both ends — the visible half of §43g.
      await tester.pumpWidget(host(row(label: 'a' * 200)));

      final left = rectOf(tester, find.text('01:23'));
      final right = rectOf(tester, find.text('03:45'));
      final chip = chipRect(tester);

      expect(chip.left - left.right, greaterThanOrEqualTo(8));
      expect(right.left - chip.right, greaterThanOrEqualTo(8));
    });

    testWidgets('costs the height estimate nothing', (tester) async {
      // The player anchors or scrolls off `estimatedHeight`, which has been
      // right since §31. This fix must add **0** to it below the threshold.
      late double extra;
      late bool stacks;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              extra = PlayerMetaRow.extraHeight(context);
              stacks = PlayerMetaRow.stacks(context);
              return row();
            },
          ),
        ),
      );
      expect(extra, 0);
      expect(stacks, isFalse);
    });
  });

  group('just below the reflow threshold', () {
    testWidgets('nothing has moved off the row yet', (tester) async {
      late double extra;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              extra = PlayerMetaRow.extraHeight(context);
              return row();
            },
          ),
          scaler: const TextScaler.linear(zenithStackedRowTextScale),
        ),
      );

      final left = rectOf(tester, find.text('01:23'));
      final chip = chipRect(tester);
      expect(chip.center.dy, moreOrLessEquals(left.center.dy, epsilon: 1.5));
      expect(chip.left, greaterThan(left.right));
      expect(extra, 0);
    });

    testWidgets('the gutter holds when the counters have grown',
        (tester) async {
      await tester.pumpWidget(
        host(
          row(label: 'a' * 200, elapsed: '1:02:03', total: '1:59:59'),
          scaler: const TextScaler.linear(zenithStackedRowTextScale),
        ),
      );

      final left = rectOf(tester, find.text('1:02:03'));
      final right = rectOf(tester, find.text('1:59:59'));
      final chip = chipRect(tester);

      expect(chip.left - left.right, greaterThanOrEqualTo(8));
      expect(right.left - chip.right, greaterThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
    });
  });

  group('at Android 200%', () {
    testWidgets('the chip takes its own line under both counters',
        (tester) async {
      await tester.pumpWidget(
        host(row(), scaler: const TextScaler.linear(2.0)),
      );

      final left = rectOf(tester, find.text('01:23'));
      final right = rectOf(tester, find.text('03:45'));
      final chip = chipRect(tester);

      // The counters keep the line they were measured on...
      expect(left.top, moreOrLessEquals(right.top, epsilon: 0.5));
      // ...and the chip is below both of them, not wedged between.
      expect(chip.top, greaterThanOrEqualTo(left.bottom));
      expect(chip.top, greaterThanOrEqualTo(right.bottom));
    });

    testWidgets('the codec string survives whole, and would not have',
        (tester) async {
      // The two halves of the defect, on the same label at the same scale.
      // Wedged between two 200% counters there is not room for it...
      await tester.pumpWidget(
        host(
          Row(
            children: [
              const Text('01:23', style: TextStyle(fontSize: 12)),
              const Expanded(
                child: Center(child: PlayerMetaChip(label: codec)),
              ),
              const Text('03:45', style: TextStyle(fontSize: 12)),
            ],
          ),
          scaler: const TextScaler.linear(2.0),
        ),
      );
      expect(ellipsised(tester, codec), isTrue,
          reason: 'the pre-fix row is the control: it must still be squeezed');

      // ...and on a line of its own there is.
      await tester.pumpWidget(
        host(row(), scaler: const TextScaler.linear(2.0)),
      );
      expect(ellipsised(tester, codec), isFalse);
    });

    testWidgets('the row reports the line it gained', (tester) async {
      late double extra;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              extra = PlayerMetaRow.extraHeight(context);
              return row();
            },
          ),
          scaler: const TextScaler.linear(2.0),
        ),
      );

      // A whole line of counter-sized text plus the chip's padding and the gap
      // above it — the player has to budget for it or it anchors and overflows.
      expect(extra, greaterThan(20));

      final rowRect = rectOf(tester, find.byType(PlayerMetaRow));
      final counter = rectOf(tester, find.text('01:23'));
      expect(
        rowRect.height - counter.height,
        moreOrLessEquals(extra, epsilon: 1),
      );
    });

    testWidgets('holds with the counters at their widest', (tester) async {
      // An hour-long track: "1:02:03" is two glyphs wider at each end, which is
      // what took the old row past its width in the first place.
      await tester.pumpWidget(
        host(
          row(elapsed: '1:02:03', total: '1:59:59'),
          scaler: const TextScaler.linear(2.0),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(ellipsised(tester, '1:02:03'), isFalse);
      expect(ellipsised(tester, '1:59:59'), isFalse);
    });
  });

  group('ZenithPlayerMetrics.estimatedHeight', () {
    test('is unchanged when the meta row has gained nothing', () {
      // The default-scale estimate is the one that has been right since §31.
      expect(
        ZenithPlayerMetrics.estimatedHeight(411, 1, extraMetaRowHeight: 0),
        ZenithPlayerMetrics.estimatedHeight(411, 1),
      );
    });

    test('grows by exactly what the meta row gained', () {
      final base = ZenithPlayerMetrics.estimatedHeight(411, 2);
      expect(
        ZenithPlayerMetrics.estimatedHeight(411, 2, extraMetaRowHeight: 34),
        moreOrLessEquals(base + 34, epsilon: 0.001),
      );
    });
  });
}
