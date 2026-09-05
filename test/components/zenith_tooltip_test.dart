import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';

/// [ZenithTooltip] exists because shadcn's `Tooltip` emits no semantics at all
/// and its `Clickable` is a bare `GestureDetector` — every glyph-only control
/// in the app was an unnamed tappable rectangle to a screen reader. Forty-odd
/// call sites now depend on this widget producing the right node, so the node
/// itself is what these tests assert.
void main() {
  Widget host(Widget child) => ShadcnApp(
        home: Scaffold(child: Center(child: child)),
      );

  /// The semantics node covering [finder], with its children merged the way a
  /// screen reader reads it.
  SemanticsData dataFor(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData();

  testWidgets('names the control and calls it a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        ZenithTooltip(
          message: 'Add to queue',
          child: IconButton.ghost(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ),
      ),
    );

    final data = dataFor(tester, find.byType(IconButton));
    expect(data.label, 'Add to queue');
    expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue,
        reason: 'the label must land on the node that is actually tappable');
    handle.dispose();
  });

  testWidgets('status: named, but not announced as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const ZenithTooltip.status(
          message: 'Recommended',
          child: Icon(Icons.star),
        ),
      ),
    );

    final data = dataFor(tester, find.byType(Icon));
    expect(data.label, 'Recommended');
    expect(data.hasFlag(SemanticsFlag.isButton), isFalse);
    handle.dispose();
  });

  testWidgets('selfNamed: a button flag, but the name comes from the child',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        ZenithTooltip.selfNamed(
          message: 'Select',
          child: Button(
            style: ButtonVariance.ghost,
            onPressed: () {},
            child: const Text('Select'),
          ),
        ),
      ),
    );

    // Not "Select, Select": the tooltip is not repeated as a label.
    final data = dataFor(tester, find.text('Select'));
    expect(data.label, 'Select');
    expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
    handle.dispose();
  });

  testWidgets('plain: adds no label, so a truncated title is not read twice',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const ZenithTooltip.plain(
          message: 'A very long album title',
          child: Text('A very long album title'),
        ),
      ),
    );

    // One node carrying the text once — not the text plus a tooltip label.
    final data = dataFor(tester, find.text('A very long album title'));
    expect(data.label, 'A very long album title');
    expect(data.hasFlag(SemanticsFlag.isButton), isFalse);
    handle.dispose();
  });
}
