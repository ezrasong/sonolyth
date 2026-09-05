import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/l10n/l10n.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/player/player.dart';
import 'package:sonolyth/modules/player/player_line2.dart';

/// The player's line 2 and its track counter, both of which were laying text
/// out in a way that could only fail silently (§42d).
///
/// Line 2 was a `Row` of a `Flexible` `ArtistLink` — which is a **`Wrap`** —
/// beside a `Flexible` album `Text`. Two runs, two independent wraps: with a
/// long credit list the artists stacked onto three lines while "- ALBUM"
/// floated beside the first, at *every* font scale. The counter shared the
/// `sub_aa_buttons` row as one of five equal slots and, at Android's 200%,
/// wrapped inside a fixed-height box that then ate the second line — no
/// `RenderFlex` error, nothing in logcat, just "136 /" with the total gone.
///
/// So what these tests pin is the property each fix rests on: **line 2 is one
/// paragraph that ends where it says it ends**, and **the counter's slot is
/// exactly the picture's fifth at the default font size and wider only above
/// the reflow threshold.**
void main() {
  SonolythSimpleArtistObject artist(String name) =>
      SonolythSimpleArtistObject(
        id: name.toLowerCase().replaceAll(' ', '-'),
        name: name,
        externalUri: 'https://example.test/$name',
      );

  Widget host(Widget child, {TextScaler scaler = TextScaler.noScaling}) =>
      MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: ShadcnApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The player gives line 2 the art's width minus its margins; a
            // fixed box here is what makes "does it stay one line" a question
            // with an answer.
            child: Center(child: SizedBox(width: 300, child: child)),
          ),
        ),
      );

  /// Every `RenderParagraph` under [finder], as the layout actually resolved
  /// it — the number of line boxes, not the number of `\n`s in the string.
  int lineCount(WidgetTester tester, Finder finder) {
    final paragraph = tester.renderObject(finder) as RenderParagraph;
    return paragraph
        .getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: paragraph.text.toPlainText().length,
          ),
        )
        .map((box) => box.top.round())
        .toSet()
        .length;
  }

  group('PlayerLine2', () {
    Widget line2(
      List<SonolythSimpleArtistObject> artists,
      String album, {
      void Function(String route)? onArtistTap,
      VoidCallback? onOverflowTap,
    }) =>
        PlayerLine2(
          artists: artists,
          album: album,
          style: const TextStyle(fontSize: ZenithPlayerMetrics.line2Size),
          onArtistTap: onArtistTap ?? (_) {},
          onOverflowTap: onOverflowTap ?? () {},
        );

    testWidgets('is one paragraph, artists and album together', (tester) async {
      await tester.pumpWidget(
        host(line2([artist('Moon Sujin'), artist('Jiselle')], 'Only U')),
      );

      // One `Text`, not an ArtistLink beside an album Text. The album has to
      // be *inside* the same paragraph or it can wrap on its own again.
      expect(find.byType(Text), findsOneWidget);
      final paragraph =
          tester.renderObject(find.byType(RichText)) as RenderParagraph;
      expect(
        // `includeSemanticsLabels` defaults to true and the album span carries
        // one (below) — this asks what is *drawn*.
        paragraph.text.toPlainText(includeSemanticsLabels: false),
        'Moon Sujin, Jiselle - Only U',
      );
    });

    testWidgets('stays on one line when the credits are long', (tester) async {
      // The reported case: three artists and an album long enough that the old
      // Row wrapped the names onto three lines with "- ACROSS THE UNI…"
      // floating beside the first of them.
      await tester.pumpWidget(
        host(
          line2(
            [artist('Junggigo'), artist('Crush'), artist('DEAN')],
            'ACROSS THE UNIVERSE',
          ),
        ),
      );

      expect(lineCount(tester, find.byType(RichText)), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is still one line at 200%', (tester) async {
      await tester.pumpWidget(
        host(
          line2(
            [artist('Junggigo'), artist('Crush'), artist('DEAN')],
            'ACROSS THE UNIVERSE',
          ),
          scaler: const TextScaler.linear(2.0),
        ),
      );

      expect(lineCount(tester, find.byType(RichText)), 1);
    });

    testWidgets('folds the fourth artist onward into "and N more"',
        (tester) async {
      await tester.pumpWidget(
        host(
          line2(
            [artist('A'), artist('B'), artist('C'), artist('D'), artist('E')],
            '',
          ),
        ),
      );

      final text = (tester.renderObject(find.byType(RichText)) as RenderParagraph)
          .text
          .toPlainText();
      // Three names, then the fold — the same shape `ArtistLink` shows.
      expect(text, startsWith('A, B, C, '));
      expect(text, contains('2'));
      expect(text, isNot(contains('D')));
    });

    testWidgets('omits the separator when the album is unknown',
        (tester) async {
      await tester.pumpWidget(host(line2([artist('Moon Sujin')], '')));

      // §33c: an album with no name must not leave a dangling " - ".
      expect(
        (tester.renderObject(find.byType(RichText)) as RenderParagraph)
            .text
            .toPlainText(),
        'Moon Sujin',
      );
    });

    testWidgets('the album is announced without its separator dash',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(line2([artist('Moon Sujin')], 'ACROSS THE UNIVERSE')),
      );

      // A span carrying a recognizer becomes its own semantics node, so the
      // album is a separate fragment however the line is written — and it was
      // being read out as "dash ACROSS THE UNIVERSE" (§43g). The hyphen
      // separates two runs on a line; spoken, it is not a word.
      final labels = <String>[];
      void collect(SemanticsNode node) {
        if (node.label.isNotEmpty) labels.add(node.label);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(find.byType(RichText)));
      expect(labels, contains('ACROSS THE UNIVERSE'));
      expect(labels, isNot(contains(' - ACROSS THE UNIVERSE')));

      // The dash is still *drawn* — this is a reading change, not a visual one.
      expect(
        (tester.renderObject(find.byType(RichText)) as RenderParagraph)
            .text
            .toPlainText(includeSemanticsLabels: false),
        'Moon Sujin - ACROSS THE UNIVERSE',
      );
      semantics.dispose();
    });

    testWidgets('each artist span carries its own tap target', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        host(
          line2(
            [artist('Moon Sujin'), artist('Jiselle')],
            'Only U',
            onArtistTap: tapped.add,
          ),
        ),
      );

      final paragraph =
          tester.renderObject(find.byType(RichText)) as RenderParagraph;
      final spans = <TextSpan>[];
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) spans.add(span);
        return true;
      });

      // The recognizers are what make the names links; losing them is exactly
      // the regression a rewrite to plain text would cause, and it would look
      // perfectly fine in a screenshot.
      expect(spans.length, 2);
      for (final span in spans) {
        (span.recognizer as TapGestureRecognizer).onTap!();
      }
      expect(tapped, ['/artist/moon-sujin', '/artist/jiselle']);
    });

    testWidgets('re-points its recognizers when the track changes',
        (tester) async {
      final tapped = <String>[];
      Widget at(List<SonolythSimpleArtistObject> artists) => host(
            line2(artists, 'Album', onArtistTap: tapped.add),
          );

      await tester.pumpWidget(at([artist('Moon Sujin'), artist('Jiselle')]));
      await tester.pumpWidget(at([artist('Crush'), artist('DEAN')]));

      final paragraph =
          tester.renderObject(find.byType(RichText)) as RenderParagraph;
      final spans = <TextSpan>[];
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) spans.add(span);
        return true;
      });
      for (final span in spans) {
        (span.recognizer as TapGestureRecognizer).onTap!();
      }

      // The recognizers outlive a track change — the handlers must not.
      expect(tapped, ['/artist/crush', '/artist/dean']);
    });

    testWidgets('disposes its recognizers', (tester) async {
      await tester.pumpWidget(host(line2([artist('Moon Sujin')], 'Only U')));
      await tester.pumpWidget(host(const SizedBox.shrink()));

      // A `TapGestureRecognizer` owns a timer, and the player rebuilds on
      // every position tick — an undisposed one per frame is a real leak.
      expect(tester.takeException(), isNull);
    });
  });

  group('ZenithPlayerMetrics.trackCounterFlex', () {
    Future<int> flexAt(WidgetTester tester, TextScaler scaler) async {
      late int flex;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: ShadcnApp(
            home: Builder(
              builder: (context) {
                flex = ZenithPlayerMetrics.trackCounterFlex(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return flex;
    }

    testWidgets('is one slot of five at the default font size',
        (tester) async {
      // `sub_aa_buttons` is `fitCentered` across five equal slots in the
      // picture. If this ever stops being 1, the measured row is silently gone.
      expect(await flexAt(tester, TextScaler.noScaling), 1);
    });

    testWidgets('is unchanged just below the reflow threshold', (tester) async {
      expect(
        await flexAt(tester, const TextScaler.linear(zenithStackedRowTextScale)),
        1,
      );
    });

    testWidgets('widens past the reflow threshold', (tester) async {
      expect(await flexAt(tester, const TextScaler.linear(2.0)), greaterThan(1));
    });
  });
}
