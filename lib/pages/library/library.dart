import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/side_bar_tiles.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';

@RoutePage()
class LibraryPage extends HookConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final downloadingCount = ref
        .watch(downloadManagerProvider)
        .where((e) =>
            e.status == DownloadStatus.downloading ||
            e.status == DownloadStatus.queued)
        .length;
    final router = context.watchRouter;
    final sidebarLibraryTileList = useMemoized(
      () => [
        ...getSidebarLibraryTileList(context.l10n),
        SideBarTiles(
          id: "downloads",
          pathPrefix: "/library/downloads",
          title: context.l10n.downloads,
          route: const UserDownloadsRoute(),
          icon: SonolythIcons.download,
        ),
      ],
      [context.l10n],
    );
    final index = sidebarLibraryTileList.indexWhere(
      (e) => router.currentPath.startsWith(e.pathPrefix),
    );
    final selectedIndex = index < 0 ? 0 : index;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          return Scaffold(
            headers: [
              if (constraints.smAndDown)
                _LibraryTopNavigation(
                  tiles: sidebarLibraryTileList,
                  selectedIndex: selectedIndex,
                  downloadingCount: downloadingCount,
                  onSelected: (index) {
                    context.navigateTo(sidebarLibraryTileList[index].route);
                  },
                )
              else
                const TitleBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  surfaceBlur: 0,
                  height: 32,
                ),
              const Gap(10),
            ],
            child: const AutoRouter(),
          );
        }),
      ),
    );
  }
}

class _LibraryTopNavigation extends StatelessWidget {
  final List<SideBarTiles> tiles;
  final int selectedIndex;
  final int downloadingCount;
  final ValueChanged<int> onSelected;

  const _LibraryTopNavigation({
    required this.tiles,
    required this.selectedIndex,
    required this.downloadingCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return material.Material(
      color: colorScheme.background,
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final MapEntry(:key, value: tile) in tiles.asMap().entries)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final selected = key == selectedIndex;
                    final foreground = selected
                        ? colorScheme.foreground
                        : colorScheme.mutedForeground;

                    return _LibraryTopNavigationItem(
                      label: tile.title,
                      selected: selected,
                      foreground: foreground,
                      accent: colorScheme.primary,
                      badgeCount: tile.id == 'downloads' ? downloadingCount : 0,
                      onPressed: () => onSelected(key),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTopNavigationItem extends StatelessWidget {
  final String label;
  final bool selected;
  final Color foreground;
  final Color accent;
  final int badgeCount;
  final VoidCallback onPressed;

  const _LibraryTopNavigationItem({
    required this.label,
    required this.selected,
    required this.foreground,
    required this.accent,
    required this.badgeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return material.InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: material.Badge(
          isLabelVisible: badgeCount > 0,
          label: Text(badgeCount.toString()),
          backgroundColor: accent,
          // Offset the badge clear of the text so a count doesn't sit on top
          // of the last letters of a long label like "Downloads".
          alignment: Alignment.topRight,
          offset: const Offset(8, -4),
          // Equal-width tabs leave a long label like "Downloads" + badge
          // tight; shrink to fit rather than truncating to "Downloa…".
          child: AutoSizeText(
            label,
            maxLines: 1,
            minFontSize: 8,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
