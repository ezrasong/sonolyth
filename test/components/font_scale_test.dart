import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_card.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart';
import 'package:sonolyth/modules/player/player_overlay_collapsed.dart';
import 'package:sonolyth/modules/stats/summary/summary_card.dart';
import 'package:sonolyth/pages/library/user_local_tracks/local_folder.dart';

/// Android's own font-size setting goes to 200%, and at 200% the app clipped
/// content on every screen: grid cells overflowed their 225dp extent, the
/// navbar's 55dp mini row cut the artist line in half, and a track row's
/// artist line was clipped mid-glyph by a fixed 40dp cap (§37).
///
/// The whole fix rests on one property, and it is the property these tests
/// pin: **every one of those heights is unchanged at the default font size and
/// grows by exactly as much as its text does above it.** If a refactor makes
/// the default-scale number drift, the 1:1 measurements of §27/§28/§31 are
/// silently gone; if it makes the growth stop, the clipping is back.
///
/// The other thing pinned here is the trap this pass fell into **twice**:
/// Android 14's font scaling is *non-linear*. It grows small text far more
/// than large text, so `textScaler.scale(<a dp constant>)` is not a way to ask
/// "how much taller is my text" — scaling the 40dp cap grew it by a third
/// while the 13sp line inside it nearly doubled, and asking `scale(100) / 100`
/// for the reflow threshold returned 1.3 at a system setting of 200%.
void main() {
  /// Android 14's non-linear curve, in the shape that matters: body text
  /// nearly doubles, a large heading barely moves. The real curve interpolates
  /// between per-size tables; this reproduces the *asymmetry*, which is the
  /// only part any of this code depends on.
  const nonLinear = _NonLinearTextScaler();

  Future<T> valueAt<T>(
    WidgetTester tester,
    TextScaler scaler,
    T Function(BuildContext context) read,
  ) async {
    late T value;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: ShadcnApp(
          home: Builder(
            builder: (context) {
              value = read(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return value;
  }

  group('zenithLineGrowth', () {
    testWidgets('is zero at the system default', (tester) async {
      final growth = await valueAt(
        tester,
        TextScaler.noScaling,
        (context) => zenithLineGrowth(
          context,
          const TextStyle(fontSize: 15),
        ),
      );

      expect(growth, 0);
    });

    testWidgets('is the extra height of one line, not the extra font size',
        (tester) async {
      final growth = await valueAt(
        tester,
        const TextScaler.linear(2),
        (context) => zenithLineGrowth(
          context,
          const TextStyle(fontSize: 15),
        ),
      );

      // A 15sp line is ~17-18dp tall, so doubling the text adds about that
      // much again — never the 15dp of the font size itself, and never zero.
      expect(growth, greaterThan(10));
      expect(growth, lessThan(30));
    });
  });

  group('a fixed height holds its text at 200%', () {
    testWidgets('a grid cell is the skin\'s 225dp, then grows', (tester) async {
      final base = await valueAt(
        tester,
        TextScaler.noScaling,
        (context) => (
          ZenithCardMetrics.extent(context),
          Theme.of(context).scaling,
        ),
      );
      final scaled = await valueAt(
        tester,
        nonLinear,
        ZenithCardMetrics.extent,
      );

      // The skin's 225dp, times the app's own UI scale and nothing else.
      expect(base.$1, ZenithCardMetrics.baseExtent * base.$2);
      // The two label lines overflowed by 20px at 200%, so anything less than
      // that much growth leaves the description clipped.
      expect(scaled - base.$1, greaterThan(20));
    });

    testWidgets('the mini player row is the navbar\'s 55dp, then grows',
        (tester) async {
      final base = await valueAt(
        tester,
        TextScaler.noScaling,
        ZenithMiniPlayerMetrics.heightOf,
      );
      final scaled = await valueAt(
        tester,
        nonLinear,
        ZenithMiniPlayerMetrics.heightOf,
      );

      expect(base, ZenithMiniPlayerMetrics.height);
      // It overflowed by 12px.
      expect(scaled - base, greaterThan(12));
    });

    testWidgets('a track row\'s line-2 cap is 40dp, then grows by two lines',
        (tester) async {
      final base = await valueAt(
        tester,
        TextScaler.noScaling,
        ZenithTrackRowMetrics.line2MaxHeightOf,
      );
      final scaled = await valueAt(
        tester,
        nonLinear,
        ZenithTrackRowMetrics.line2MaxHeightOf,
      );

      expect(base, ZenithTrackRowMetrics.line2MaxHeight);
      // Two lines of a nearly-doubled 13sp line need well over 40dp; the
      // regression to catch is the cap growing by only a third, which is what
      // `textScaler.scale(40)` did.
      expect(scaled, greaterThan(nonLinear.scale(base)));
      expect(scaled, greaterThan(55));
    });

    testWidgets("the local folder's two-line header is 64dp, then grows",
        (tester) async {
      // The one `TitleBar` that passes an explicit `height`, which is exactly
      // why it was still overflowing by 14px after §37: the growth
      // `TitleBar` adds lives in the branch an explicit height skips.
      final base = await valueAt(
        tester,
        TextScaler.noScaling,
        (context) => (
          localFolderHeaderHeight(context),
          Theme.of(context).scaling,
        ),
      );
      final scaled = await valueAt(tester, nonLinear, localFolderHeaderHeight);

      // The measured 64, times the app's UI scale and nothing else.
      expect(base.$1, localFolderHeaderBase * base.$2);
      // The size line under the folder name is what overflowed; it is small
      // text, which is the half of the curve that nearly doubles.
      expect(scaled - base.$1, greaterThan(14));
    });
  });

  group('zenithStacksRows', () {
    testWidgets('leaves the skin\'s rows alone at and near the default',
        (tester) async {
      expect(
        await valueAt(tester, TextScaler.noScaling, zenithStacksRows),
        isFalse,
      );
      expect(
        await valueAt(tester, const TextScaler.linear(1.15), zenithStacksRows),
        isFalse,
      );
    });

    testWidgets('stacks under a non-linear scaler that doubles body text',
        (tester) async {
      // The bug: measured at `scale(100) / 100` this scaler reads 1.3 and the
      // rows never stacked on the device, while the label was wrapping one
      // word per line.
      expect(nonLinear.scale(100) / 100, lessThanOrEqualTo(1.3));
      expect(
        await valueAt(tester, nonLinear, zenithStacksRows),
        isTrue,
      );
    });
  });

  group('zenithScaledLineHeight', () {
    testWidgets('is the whole line, not the growth', (tester) async {
      const style = TextStyle(fontSize: SummaryCard.unitSize);

      final atDefault = await valueAt(
        tester,
        TextScaler.noScaling,
        (context) => zenithScaledLineHeight(context, style),
      );
      final scaled = await valueAt(
        tester,
        nonLinear,
        (context) => zenithScaledLineHeight(context, style),
      );
      final growth = await valueAt(
        tester,
        nonLinear,
        (context) => zenithLineGrowth(context, style),
      );

      // The distinction the two helpers exist for: growth is what a box that
      // already has a line needs, this is what a box gaining one needs. A card
      // that gains a line and is only given the growth is short by exactly the
      // unscaled line, which is how item 55's text got clipped.
      expect(atDefault, greaterThan(0));
      expect(scaled, greaterThan(atDefault));
      expect(scaled - growth, closeTo(atDefault, 0.01));
    });
  });

  group('a summary card keeps its unit and its description', () {
    Future<List<int?>> maxLinesOf(
        WidgetTester tester, TextScaler scaler) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: ShadcnApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 190,
                height: 400,
                child: SummaryCard(
                  title: 55,
                  unit: 'minutes',
                  description: 'Listened to music',
                ),
              ),
            ),
          ),
        ),
      );
      return tester
          .widgetList<AutoSizeText>(find.byType(AutoSizeText))
          .map((t) => t.maxLines)
          .toList();
    }

    testWidgets('is one line each at the default, exactly as measured',
        (tester) async {
      // The figure and its unit share a line and the description takes one.
      // Nothing here may move at 100%, or §39's grid measurements are gone.
      expect(await maxLinesOf(tester, TextScaler.noScaling), [1, 1]);
    });

    testWidgets('gives each one more line past the threshold', (tester) async {
      // Item 55: `AutoSizeText` cannot shrink past a `minFontSize` measured
      // against the ambient style, so at 200% it clipped instead — the
      // "55 minutes" card rendered "55", and a clip raises no overflow error.
      expect(await maxLinesOf(tester, nonLinear), [2, 2]);
    });
  });
}

class _NonLinearTextScaler extends TextScaler {
  const _NonLinearTextScaler();

  @override
  double scale(double fontSize) => fontSize * (fontSize >= 40 ? 1.3 : 1.95);

  @override
  double get textScaleFactor => 1.95;
}
