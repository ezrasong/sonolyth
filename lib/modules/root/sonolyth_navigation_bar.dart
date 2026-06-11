import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart' show Badge;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sonolyth/collections/side_bar_tiles.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';

final navigationPanelHeight = StateProvider<double>((ref) => 50);

class SonolythNavigationBar extends HookConsumerWidget {
  const SonolythNavigationBar({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.of(context);

    final downloadCount = ref.watch(
      downloadManagerProvider.select(
        (tasks) => tasks
            .where((e) =>
                e.status == DownloadStatus.downloading ||
                e.status == DownloadStatus.queued)
            .length,
      ),
    );
    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

    final navbarTileList = useMemoized(
      () => getNavbarTileList(context.l10n),
      [context.l10n],
    );

    final panelHeight = ref.watch(navigationPanelHeight);

    final router = context.watchRouter;
    // -1 when no tile matches (e.g. Settings, Lyrics); no tile is selected.
    final selectedIndex = navbarTileList.indexWhere(
      (e) => router.currentPath.startsWith(e.pathPrefix),
    );

    if (layoutMode == LayoutMode.extended ||
        (mediaQuery.mdAndUp && layoutMode == LayoutMode.adaptive) ||
        panelHeight < 10) {
      return const SizedBox();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: panelHeight + 14,
      color: context.theme.colorScheme.background,
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          for (final tile in navbarTileList)
            Expanded(
              child: _SpotifyNavigationItem(
                icon: tile.icon,
                label: tile.title,
                selected: selectedIndex != -1 &&
                    navbarTileList[selectedIndex] == tile,
                badgeCount: tile.id == "library" ? downloadCount : 0,
                onPressed: () {
                  context.navigateTo(tile.route);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotifyNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onPressed;

  const _SpotifyNavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final foreground =
        selected ? colorScheme.foreground : colorScheme.mutedForeground;

    return material.InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 2,
          children: [
            // Hand-rolled pill instead of material.Badge: Badge hangs its
            // label above the icon's bounds where the mini player paints over
            // it (count appeared decapitated), and its label color fell back
            // to the unconfigured Material theme. The pill sits beside the
            // icon, fully inside the navbar row, with explicit colors.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: foreground, size: 23),
                if (badgeCount > 0)
                  Positioned(
                    left: 25,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // Cap wide counts so a 3-digit queue (e.g. 679)
                        // doesn't balloon the pill past the tab.
                        badgeCount > 99 ? "99+" : badgeCount.toString(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primaryForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
