import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/nav_tiles.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';

/// Whether the Library tab is showing its root — Poweramp's list of
/// categories — or one category's list. Tapping a category clears it, back
/// (or tapping the Library tab again) sets it. Kept outside the page so the
/// nav bar can send the user back to the root the way Poweramp's does.
final libraryRootVisibleProvider = StateProvider<bool>((ref) => true);

/// The Library tab.
///
/// Poweramp's Library is a **list of categories** — All Songs, Folders,
/// Albums, Artists… — each an `item_text` row with a shape tile
/// (`ItemTextAAImage`, `shape_*`) and an `ItemTextTitle` label, under the
/// `scene_top_header` title row ("Library", 29sp, 28dp in, the `header_menu`
/// glyph at the right). A category opens its own list under the
/// `item_top_text_back_decor` "‹ Library" and its own title row, exactly as
/// the skin's screenshots show. That is what this page does on a phone: the
/// root is the category list, a tap opens the category inside the nested
/// router, and back returns to the root. The chip row this replaced was the
/// app's own idiom; Poweramp has no tabs here.
///
/// It does that at **every** width now. Above 640dp it used to hand the
/// category links to the desktop sidebar and show the nested router bare; the
/// sidebar is gone (§38) and that left the page blank, so there is one shape
/// here, as there is in Poweramp.
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
    final tiles = useMemoized(
      () => [
        ...getLibraryTileList(context.l10n),
        NavTile(
          id: "downloads",
          pathPrefix: "/library/downloads",
          title: context.l10n.downloads,
          route: const UserDownloadsRoute(),
          icon: SonolythIcons.download,
        ),
      ],
      [context.l10n],
    );
    // The nested library router's path isn't always reflected in this
    // (parent) router's currentPath, so path-matching alone can lag. Seed
    // from the path when it resolves, but let taps drive it.
    final pathIndex = tiles.indexWhere(
      (e) => router.currentPath.startsWith(e.pathPrefix),
    );
    final selectedIndex = useState(pathIndex < 0 ? 0 : pathIndex);
    useEffect(() {
      if (pathIndex >= 0) selectedIndex.value = pathIndex;
      return null;
    }, [pathIndex]);

    final showRoot = ref.watch(libraryRootVisibleProvider);

    void openCategory(int index) {
      selectedIndex.value = index;
      ref.read(libraryRootVisibleProvider.notifier).state = false;
      context.navigateTo(tiles[index].route);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // auto_route also fires this while it swaps tab routes *during a
        // build* (didPop is true then); touching a provider there throws
        // "Tried to modify a provider while the widget tree was building" and
        // takes the AutoRouteNavigator down with it (frozen body, red
        // ErrorWidget in the status bar). Only the intercepted system back
        // (didPop false) is ours to handle.
        if (didPop) return;
        // A shadcn sheet (header menu, track options) is an overlay, not a
        // route, and its own back handling never runs inside the nested
        // router: a press with one open closes it and stays put.
        if (context.closeOpenDrawer()) return;
        if (!ref.read(libraryRootVisibleProvider)) {
          ref.read(libraryRootVisibleProvider.notifier).state = true;
          return;
        }
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        // One shape at every width, and no `LayoutBuilder` any more. Above
        // 640dp this used to skip the root category list entirely and show
        // the nested router bare with a 32dp `TitleBar` — because the desktop
        // sidebar carried the Playlists / Artists / Albums / Local links
        // there. With the sidebar gone (§38) that left the page **blank** at
        // 1080dp with no way to pick a category at all: `showRoot` was true,
        // so the nested router had nothing to draw, and nothing else was
        // rendered. Measured on the emulator with `wm density 160`.
        child: Builder(builder: (context) {
          final categoryTitle = tiles[selectedIndex.value].title;

          // The nested router stays mounted underneath the root list so a
          // category's scroll position and filter survive going back and
          // forth, the way Poweramp's lists do.
          final nested = Scaffold(
            headers: [
              // `item_top_text_back_decor` — "‹ Library" — then the
              // category's own `scene_top_header` title row.
              ZenithBackDecor(
                label: context.l10n.library,
                onPressed: () =>
                    ref.read(libraryRootVisibleProvider.notifier).state = true,
              ),
              ZenithListTitle(title: categoryTitle),
              const Gap(4),
            ],
            child: const AutoRouter(),
          );

          return Stack(
            children: [
              Offstage(offstage: showRoot, child: nested),
              if (showRoot)
                _LibraryRoot(
                  tiles: tiles,
                  downloadingCount: downloadingCount,
                  onSelected: openCategory,
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// Poweramp's library root: the `scene_top_header` title row with the
/// `header_menu` glyph, then `item_text` rows with a shape tile and a label.
class _LibraryRoot extends StatelessWidget {
  final List<NavTile> tiles;
  final int downloadingCount;
  final ValueChanged<int> onSelected;

  const _LibraryRoot({
    required this.tiles,
    required this.downloadingCount,
    required this.onSelected,
  });

  static ZenithLibraryGlyph _glyphFor(String id) => switch (id) {
        "playlists" => ZenithLibraryGlyph.playlists,
        "artists" => ZenithLibraryGlyph.artists,
        "albums" => ZenithLibraryGlyph.albums,
        "local" => ZenithLibraryGlyph.folders,
        _ => ZenithLibraryGlyph.allSongs,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        ZenithListTitle(
          title: context.l10n.library,
          // Poweramp's library menu (rescan, list options, settings…); here
          // the two places the Home header used to link to.
          trailing: AdaptivePopSheetList<String>(
            tooltip: context.l10n.more_actions,
            icon: ZenithHeaderMenuIcon(
              size: ZenithListHeaderMetrics.menuGlyphSize,
              color: context.theme.colorScheme.primary,
            ),
            items: (context) => [
              // Stats and Profile are here because the desktop sidebar was
              // the ONLY way to either of them, and the sidebar is gone
              // (§38) — Stats was already unreachable on a phone before that
              // (§37g), since `StatsRoute` appeared in no other list.
              // Settings and Devices predate them; this menu is where the
              // Home header's old links live.
              AdaptiveMenuButton(
                value: "stats",
                leading: const Icon(SonolythIcons.chart),
                child: Text(context.l10n.stats),
              ),
              AdaptiveMenuButton(
                value: "profile",
                leading: const Icon(SonolythIcons.user),
                child: Text(context.l10n.profile),
              ),
              AdaptiveMenuButton(
                value: "settings",
                leading: const Icon(SonolythIcons.settings),
                child: Text(context.l10n.settings),
              ),
              AdaptiveMenuButton(
                value: "devices",
                leading: const Icon(SonolythIcons.speaker),
                child: Text(context.l10n.devices),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case "stats":
                  context.navigateTo(const StatsRoute());
                case "profile":
                  context.navigateTo(const ProfileRoute());
                case "settings":
                  context.navigateTo(const SettingsRoute());
                case "devices":
                  context.navigateTo(const ConnectRoute());
              }
            },
          ),
        ),
      ],
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: tiles.length,
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return ZenithListEnter(
            child: _LibraryCategoryRow(
              glyph: _glyphFor(tile.id),
              title: tile.title,
              badgeCount: tile.id == "downloads" ? downloadingCount : 0,
              onPressed: () => onSelected(index),
            ),
          );
        },
      ),
    );
  }
}

/// One `item_text` row: `ItemTextAAImage` (36dp, 24dp in) then
/// `ItemTextTitle` (18dp normal, 8dp margin + 12dp padding), on
/// `textItemSize` 64dp, with `item_bg` — no fill, no stroke.
class _LibraryCategoryRow extends StatelessWidget {
  final ZenithLibraryGlyph glyph;
  final String title;
  final int badgeCount;
  final VoidCallback onPressed;

  const _LibraryCategoryRow({
    required this.glyph,
    required this.title,
    required this.badgeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    // No `label:` here: the row's own `Text(title)` merges into this node, so
    // naming it again read "Playlists, Playlists" in the accessibility tree.
    return Semantics(
      button: true,
      child: ZenithPressable(
        onPressed: onPressed,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 24),
              ZenithLibraryTile(glyph: glyph),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeCount > 99 ? "99+" : badgeCount.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primaryForeground,
                    ),
                  ),
                ),
              const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }
}
