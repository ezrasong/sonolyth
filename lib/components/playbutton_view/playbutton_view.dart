import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_card.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_tile.dart';
import 'package:sonolyth/components/waypoint.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';
import 'package:sonolyth/components/fallbacks/zenith_illustration.dart';

const _dummyPlaybuttonCard = PlaybuttonCard(
  imageUrl: 'https://placehold.co/150x150.png',
  isLoading: false,
  isPlaying: false,
  title: "Playbutton",
  description: "A really cool playbutton",
  isOwner: false,
);

const _dummyPlaybuttonTile = PlaybuttonTile(
  imageUrl: 'https://placehold.co/150x150.png',
  isLoading: false,
  isPlaying: false,
  title: "Playbutton",
  description: "A really cool playbutton",
  isOwner: false,
);

/// A [PlaybuttonCard] grid/list view (selectable) sliver widget
/// with support for infinite scrolling
class PlaybuttonView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) gridItemBuilder;
  final Widget Function(BuildContext context, int index) listItemBuilder;
  final bool hasMore;
  final bool isLoading;
  final VoidCallback onRequestMore;
  final ScrollController controller;

  final Widget? leading;

  /// The view mode, when the page owns it (Poweramp keeps it in the list
  /// header's menu). Null lets the view decide from its width and show its
  /// own switch, unless [showViewToggle] is false.
  final bool? isGrid;
  final bool showViewToggle;

  const PlaybuttonView({
    super.key,
    required this.itemCount,
    required this.gridItemBuilder,
    required this.listItemBuilder,
    required this.hasMore,
    required this.isLoading,
    required this.onRequestMore,
    required this.controller,
    this.leading,
    this.isGrid,
    this.showViewToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    final scale = context.theme.scaling;

    return SliverLayoutBuilder(
      builder: (context, constrains) => HookBuilder(builder: (context) {
        final gridState = useState(constrains.mdAndUp);
        final hasUserInteracted = useRef(false);

        useEffect(() {
          if (hasUserInteracted.value) return null;
          if (gridState.value != constrains.mdAndUp) {
            gridState.value = constrains.mdAndUp;
          }
          return null;
        }, [constrains]);

        final grid = isGrid ?? gridState.value;
        final hasToolbar = showViewToggle || leading != null;

        return SliverMainAxisGroup(
          slivers: [
            if (hasToolbar)
              SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (leading != null) leading!,
                    // The view-mode switch shows its active half the way
                    // Proxima's activated buttons do — a `colorBgPrimary` pill
                    // behind the glyph (see `zenithSelectableGhost`). The stock
                    // `Toggle` fills its selected state with `secondary` and
                    // outlines the other, which Zenith never does.
                    if (showViewToggle) ...[
                      _ZenithViewToggle(
                        icon: SonolythIcons.grid,
                        label: context.l10n.grid_view,
                        selected: grid,
                        onPressed: () {
                          gridState.value = true;
                          hasUserInteracted.value = true;
                        },
                      ),
                      _ZenithViewToggle(
                        icon: SonolythIcons.list,
                        label: context.l10n.list_view,
                        selected: !grid,
                        onPressed: () {
                          gridState.value = false;
                          hasUserInteracted.value = true;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            if (hasToolbar) const SliverGap(10),
            // Toggle between grid and list view
            switch ((grid, isLoading)) {
              (true, _) => !isLoading && itemCount == 0
                  ? SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      // `ItemEmptyList`: one centred line at 60%, no art.
                      sliver: SliverToBoxAdapter(
                        child: ZenithEmptyListText(context.l10n.nothing_found),
                      ),
                    )
                  : SliverGrid.builder(
                      itemCount: isLoading ? 6 : itemCount + 1,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150 * scale,
                        // Grows with the system font size; see
                        // [ZenithCardMetrics.extent].
                        mainAxisExtent: ZenithCardMetrics.extent(context),
                        // 0, deliberately. `ItemTrackAAImage_scene_grid` gives
                        // every cell an 8dp margin of its own, so two adjacent
                        // cells are already 16dp apart; a delegate spacing on
                        // top of that would double the skin's gutter.
                        crossAxisSpacing: 0,
                        mainAxisSpacing: 0,
                      ),
                      itemBuilder: (context, index) {
                        if (isLoading) {
                          return const Skeletonizer(
                            enabled: true,
                            child: _dummyPlaybuttonCard,
                          );
                        }

                        if (index == itemCount) {
                          if (!hasMore) return const SizedBox.shrink();
                          return Waypoint(
                            controller: controller,
                            isGrid: true,
                            onTouchEdge: onRequestMore,
                            child: const Skeletonizer(
                              enabled: true,
                              child: _dummyPlaybuttonCard,
                            ),
                          );
                        }

                        // `anim_fade_in_move_up` on arrival.
                        return ZenithListEnter(
                          child: gridItemBuilder(context, index),
                        );
                      },
                    ),
              (false, true) => Skeletonizer.sliver(
                  enabled: true,
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _dummyPlaybuttonTile,
                      childCount: 6,
                    ),
                  ),
                ),
              (false, false) => SliverInfiniteList(
                  itemCount: itemCount,
                  loadingBuilder: (context) => const Skeletonizer(
                    enabled: true,
                    child: _dummyPlaybuttonTile,
                  ),
                  // `anim_fade_in_move_up` on arrival.
                  itemBuilder: (context, index) => ZenithListEnter(
                    child: listItemBuilder(context, index),
                  ),
                  onFetchData: onRequestMore,
                  hasReachedMax: !hasMore,
                  isLoading: isLoading,
                  emptyBuilder: (context) =>
                      ZenithEmptyListText(context.l10n.nothing_found),
                ),
            }
          ],
        );
      }),
    );
  }
}

/// One half of the grid/list switch: a ghost glyph on the activated pill when
/// it is the current mode. See [zenithSelectableGhost] for the token.
class _ZenithViewToggle extends StatelessWidget {
  const _ZenithViewToggle({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    return ZenithTooltip(
      message: label,
      child: IconButton(
        icon: Icon(
          icon,
          // The glyph steps from `mutedForeground` to `foreground` with the
          // pill, the way the nav bar's does with its colour swap.
          color:
              selected ? colorScheme.foreground : colorScheme.mutedForeground,
        ),
        variance: zenithSelectableGhost(colorScheme, selected: selected),
        onPressed: onPressed,
      ),
    );
  }
}
