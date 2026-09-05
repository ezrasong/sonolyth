import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sonolyth/utils/outside_build.dart';

/// The verify toast was raised from inside a build (§43g, item 61).
///
/// `useZarzVerifyPrompt` registers its listener with `fireImmediately: true`,
/// and flutter_hooks runs a `useEffect` body from `didBuild` — still inside
/// `Element.performRebuild`. A track whose resolve had *already* failed
/// therefore called `showToast` mid-build, and Flutter logged "This ToastLayer
/// widget cannot be marked as needing to build because the framework is already
/// in the process of building widgets". The toast appeared anyway, so nothing
/// visibly broke; what these pin is that the ordering is no longer accidental.
void main() {
  testWidgets('runs straight away when no frame is in flight', (tester) async {
    // A prompt that waits for a frame an idle app has no reason to schedule is
    // worse than one raised a moment early, so this must not defer.
    var ran = false;
    runOutsideBuild(() => ran = true);
    expect(ran, isTrue);
  });

  testWidgets('defers out of the build phase, and still runs', (tester) async {
    var ran = false;
    late SchedulerPhase phaseAtCall;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          phaseAtCall = SchedulerBinding.instance.schedulerPhase;
          runOutsideBuild(() => ran = true);
          // Called from inside `build`, exactly where the hook called it.
          expect(ran, isFalse);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(phaseAtCall, SchedulerPhase.persistentCallbacks);
    // Deferred, not dropped: the same frame's post-frame callbacks run it.
    expect(ran, isTrue);
  });

  testWidgets('marking a widget dirty from it raises no framework error',
      (tester) async {
    // The defect itself, reproduced and then not reproduced. `setState` from a
    // build is the same violation `showToast` was committing — an overlay is a
    // widget somewhere else being marked dirty.
    final key = GlobalKey<_DirtyState>();

    Widget tree({required bool pokeFromBuild}) => Column(
          textDirection: TextDirection.ltr,
          children: [
            _Dirty(key: key),
            Builder(
              builder: (context) {
                if (pokeFromBuild) runOutsideBuild(key.currentState!.poke);
                return const SizedBox.shrink();
              },
            ),
          ],
        );

    await tester.pumpWidget(tree(pokeFromBuild: false));
    // The sibling is already mounted, so this build reaches into a widget the
    // framework has finished with — the same shape as an overlay insert.
    await tester.pumpWidget(tree(pokeFromBuild: true));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(key.currentState!.pokes, 1);
  });
}

class _Dirty extends StatefulWidget {
  const _Dirty({super.key});

  @override
  State<_Dirty> createState() => _DirtyState();
}

class _DirtyState extends State<_Dirty> {
  int pokes = 0;

  void poke() => setState(() => pokes++);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
