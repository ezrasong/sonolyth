import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/modules/spotiflac/download_providers_section.dart';

/// The download providers' reorder arrows measured **24 x 24dp** in the
/// emulator's accessibility tree — half Android's minimum. They are ordinary
/// settings rows with no Proxima geometry behind them, so they can simply be
/// bigger.
///
/// The catch that makes this worth a test: shadcn's ghost variance keeps a 3dp
/// inset inside whatever box you give it, so a 48dp `SizedBox` still renders a
/// 42dp button — the touch target is the *button*, not the box. This pins the
/// number that actually lands on 48.
void main() {
  testWidgets('a reorder arrow is at least 48dp of real target',
      (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: Center(
            child: SizedBox.square(
              dimension: kReorderTapTarget,
              child: IconButton.ghost(
                size: ButtonSize.small,
                icon: const Icon(SonolythIcons.angleUp),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    // 54 x 54 as rendered; the emulator's accessibility node for a 48dp box
    // measured 42, so 54 is what puts a real 48 under the finger.
    final button = tester.getSize(find.byType(IconButton));
    expect(button.width, greaterThanOrEqualTo(kMinTapTarget));
    expect(button.height, greaterThanOrEqualTo(kMinTapTarget));
  });
}
