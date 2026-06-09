import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/utils/platform.dart';

class GettingStartedPageGreetingSection extends HookConsumerWidget {
  final VoidCallback onNext;
  const GettingStartedPageGreetingSection({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 64, 28, 32),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              SpotubeIcons.music,
              color: material.Theme.of(context).colorScheme.primary,
              size: 84,
            ),
            const Gap(32),
            const Text("Sonolyth").bold().h1(),
            const Gap(12),
            Text(
              kIsMobile
                  ? context.l10n.freedom_of_music_palm
                  : context.l10n.freedom_of_music,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xffb3b3b3),
                fontSize: 18,
                height: 1.35,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: Button.primary(
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
