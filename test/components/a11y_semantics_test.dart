import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/modules/player/zenith_seekbar.dart';

/// The two remaining halves of the accessibility pass that are testable off a
/// device: artwork must not add an unnamed stop to every list row, and the seek
/// bar must be operable by something that cannot drag.
void main() {
  Widget host(Widget child) => ShadcnApp(
        home: Scaffold(child: Center(child: child)),
      );

  group('UniversalImage', () {
    testWidgets('is decorative by default and emits no semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const UniversalImage(
            path: 'assets/images/placeholder.png',
            width: 40,
            height: 40,
          ),
        ),
      );

      // Cover art always sits beside the title it belongs to, so it must not
      // be a second stop with no name of its own.
      expect(
        find.bySemanticsLabel(RegExp('.*')).evaluate().where((e) {
          final node = tester.getSemantics(find.byWidget(e.widget));
          return node.getSemanticsData().hasFlag(SemanticsFlag.isImage);
        }),
        isEmpty,
      );
      handle.dispose();
    });

    testWidgets('announces itself when given a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const UniversalImage(
            path: 'assets/images/placeholder.png',
            width: 40,
            height: 40,
            semanticLabel: 'Artwork for Vitamin ME',
          ),
        ),
      );

      final data = tester
          .getSemantics(find.bySemanticsLabel('Artwork for Vitamin ME'))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isImage), isTrue);
      handle.dispose();
    });
  });

  group('ZenithSeekbar', () {
    testWidgets('is a named slider carrying the position', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: ZenithSeekbar(
              value: 0.5,
              semanticLabel: 'Seek',
              semanticValueFor: (f) => '${(f * 200).round()}s of 200s',
              onChanged: (_) {},
              onChangeEnd: (_) {},
            ),
          ),
        ),
      );

      final data =
          tester.getSemantics(find.bySemanticsLabel('Seek')).getSemanticsData();
      expect(data.label, 'Seek');
      expect(data.value, '100s of 200s');
      // A node that offers "increase" must also say what it would become —
      // Flutter asserts otherwise, which is why the readout is a function.
      expect(data.increasedValue, '110s of 200s');
      expect(data.decreasedValue, '90s of 200s');
      expect(data.hasFlag(SemanticsFlag.isSlider), isTrue);
      handle.dispose();
    });

    testWidgets('increase and decrease commit a seek', (tester) async {
      final handle = tester.ensureSemantics();
      final committed = <double>[];
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: ZenithSeekbar(
              value: 0.5,
              semanticLabel: 'Seek',
              onChangeEnd: committed.add,
            ),
          ),
        ),
      );

      final id = tester.getSemantics(find.bySemanticsLabel('Seek')).id;
      final owner = tester.binding.pipelineOwner.semanticsOwner!;

      owner.performAction(id, SemanticsAction.increase);
      owner.performAction(id, SemanticsAction.decrease);

      // A screen reader has no drag, so a step commits straight away rather
      // than waiting for a release that never comes.
      expect(committed, [0.55, 0.45]);
      handle.dispose();
    });

    testWidgets('offers no step when there is nothing to seek', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 300,
            child: ZenithSeekbar(value: 0.5, semanticLabel: 'Seek'),
          ),
        ),
      );

      final data =
          tester.getSemantics(find.bySemanticsLabel('Seek')).getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.hasAction(SemanticsAction.decrease), isFalse);
      handle.dispose();
    });
  });
}
