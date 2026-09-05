import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/utils/platform.dart';

class GettingStartedPageGreetingSection extends HookConsumerWidget {
  final VoidCallback onNext;
  const GettingStartedPageGreetingSection({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 64, 28, 32),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              SonolythIcons.music,
              color: colorScheme.primary,
              // The scroll indexer's pop-out letter (80dp) is the largest
              // glyph in the skin; nothing else has a source above 29sp.
              size: 80,
            ),
            const Gap(32),
            // `ItemTextTitle_scene_header` — 29sp, normal weight, the same
            // title every screen uses. A bold `h1` was the biggest and heaviest
            // text in the app and had no source in Proxima.
            Text("Sonolyth", style: zenithPageTitle(colorScheme)),
            const Gap(12),
            Text(
              kIsMobile
                  ? context.l10n.freedom_of_music_palm
                  : context.l10n.freedom_of_music,
              textAlign: TextAlign.center,
              // `PopupButton_Text` size (16dp) at `textColorSecondary`.
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              // `DialogPositiveButtonStyle` — see [zenithPositiveButton].
              child: Button(
                style: zenithPositiveButton(colorScheme),
                onPressed: onNext,
                child: Text(context.l10n.get_started),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
