import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/modules/home/sections/featured.dart';
import 'package:sonolyth/modules/home/sections/sections.dart';
import 'package:sonolyth/modules/home/sections/new_releases.dart';
import 'package:sonolyth/modules/home/sections/recent.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/utils/platform.dart';

@RoutePage()
class HomePage extends HookConsumerWidget {
  static const name = "home";
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final controller = useScrollController();
    final mediaQuery = MediaQuery.of(context);
    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));
    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      >= 5 && < 12 => "Good morning",
      >= 12 && < 18 => "Good afternoon",
      _ => "Good evening",
    };

    return SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            if (kTitlebarVisible) const TitleBar(height: 30),
          ],
          child: CustomScrollView(
            controller: controller,
            slivers: [
              if (mediaQuery.smAndDown || layoutMode == LayoutMode.compact)
                SliverAppBar(
                  floating: true,
                  toolbarHeight: 64,
                  titleSpacing: 16,
                  title: Text(
                    greeting,
                    style: TextStyle(
                      color: theme.colorScheme.foreground,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  backgroundColor: theme.colorScheme.background,
                  foregroundColor: theme.colorScheme.foreground,
                  actions: [
                    IconButton.ghost(
                      icon: const Icon(SonolythIcons.speaker),
                      onPressed: () {
                        context.navigateTo(const ConnectRoute());
                      },
                    ),
                    IconButton.ghost(
                      icon: const Icon(SonolythIcons.settings),
                      onPressed: () {
                        context.navigateTo(const SettingsRoute());
                      },
                    ),
                    const Gap(8),
                  ],
                )
              else if (kIsMacOS)
                const SliverGap(10),
              const SliverGap(10),
              SliverList.builder(
                itemCount: 3,
                itemBuilder: (context, index) {
                  return switch (index) {
                    // 0 => const HomeGenresSection(),
                    0 => const HomeRecentlyPlayedSection(),
                    1 => const HomeFeaturedSection(),
                    // 3 => const HomePageFriendsSection(),
                    _ => const HomeNewReleasesSection()
                  };
                },
              ),
              const SliverSafeArea(sliver: HomePageBrowseSection()),
            ],
          ),
        ));
  }
}
