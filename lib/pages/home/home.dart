import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/modules/home/sections/sections.dart';
import 'package:sonolyth/modules/home/sections/new_releases.dart';
import 'package:sonolyth/modules/home/sections/recent.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

@RoutePage()
class HomePage extends HookConsumerWidget {
  static const name = "home";
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final controller = useScrollController();
    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      >= 5 && < 12 => context.l10n.good_morning,
      >= 12 && < 18 => context.l10n.good_afternoon,
      _ => context.l10n.good_evening,
    };

    return SafeArea(
        bottom: false,
        child: Scaffold(
          child: CustomScrollView(
            controller: controller,
            slivers: [
              // Unconditional now. This used to appear only below 640dp (or in
              // "compact" layout mode) because above that the desktop
              // sidebar's wordmark stood in for a page title — and the
              // sidebar is gone (§38), so without this Home had no header at
              // all on a tablet.
              SliverAppBar(
                floating: true,
                toolbarHeight: 64,
                // `ItemTextTitle_scene_top_header`: 8dp margin + the 12dp
                // text padding at the 1.6 header scale — the same left edge
                // the Library title and every list header sit on.
                titleSpacing: 28,
                // `ItemTextTitle_Text` x `ItemTextTitle_scene_header`.
                // Bigger than it was, and much lighter: Proxima sets display
                // type in normal weight, never w800.
                title: Text(
                  greeting,
                  style: zenithPageTitle(theme.colorScheme),
                ),
                backgroundColor: theme.colorScheme.background,
                foregroundColor: theme.colorScheme.foreground,
                actions: [
                  ZenithTooltip(
                    message: context.l10n.connect_to_a_device,
                    child: IconButton.ghost(
                      icon: const Icon(SonolythIcons.speaker),
                      onPressed: () {
                        context.navigateTo(const ConnectRoute());
                      },
                    ),
                  ),
                  ZenithTooltip(
                    message: context.l10n.settings,
                    child: IconButton.ghost(
                      icon: const Icon(SonolythIcons.settings),
                      onPressed: () {
                        context.navigateTo(const SettingsRoute());
                      },
                    ),
                  ),
                  const Gap(8),
                ],
              ),
              const SliverGap(10),
              SliverList.builder(
                // Two sections, not three: the "Featured" slot was an
                // upstream-deprecated widget returning `SizedBox.shrink()`
                // built on a Spotify API this fork replaced with the plugin
                // system, so the list carried a dead row (item 54's class).
                itemCount: 2,
                itemBuilder: (context, index) {
                  return switch (index) {
                    // 0 => const HomeGenresSection(),
                    0 => const HomeRecentlyPlayedSection(),
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
