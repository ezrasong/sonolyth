import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:spotube/components/titlebar/titlebar.dart';
import 'package:spotube/collections/routes.gr.dart';
import 'package:spotube/pages/getting_started/sections/greeting.dart';
import 'package:spotube/pages/getting_started/sections/playback.dart';
import 'package:spotube/pages/getting_started/sections/region.dart';
import 'package:spotube/pages/getting_started/sections/support.dart';
import 'package:spotube/services/kv_store/kv_store.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class GettingStartedPage extends HookConsumerWidget {
  static const name = "getting_started";

  const GettingStartedPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final pageController = usePageController();

    final onNext = useCallback(() {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }, [pageController]);

    final onPrevious = useCallback(() {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }, [pageController]);

    final onSkip = useCallback(() async {
      await KVStoreService.setDoneGettingStarted(true);
      if (context.mounted) {
        context.replaceRoute(const SettingsMetadataProviderRoute());
      }
    }, [context]);

    return Scaffold(
      headers: [
        SafeArea(
          child: TitleBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            surfaceBlur: 0,
            trailing: [
              ListenableBuilder(
                listenable: pageController,
                builder: (context, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: !pageController.hasClients ||
                            pageController.page == 0 ||
                            pageController.page == 3
                        ? const SizedBox()
                        : Button.secondary(
                            onPressed: onSkip,
                            child: const Text("Skip setup"),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
      floatingHeader: true,
      child: Container(
        color: const Color(0xff121212),
        child: PageView(
          controller: pageController,
          children: [
            GettingStartedPageGreetingSection(onNext: onNext),
            GettingStartedPageLanguageRegionSection(onNext: onNext),
            GettingStartedPagePlaybackSection(
              onNext: onNext,
              onPrevious: onPrevious,
            ),
            const GettingStartedScreenSupportSection(),
          ],
        ),
      ),
    );
  }
}
