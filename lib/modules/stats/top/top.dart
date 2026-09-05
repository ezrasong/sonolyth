import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/modules/stats/common/history_duration_chip.dart';
import 'package:sonolyth/modules/stats/top/albums.dart';
import 'package:sonolyth/modules/stats/top/artists.dart';
import 'package:sonolyth/modules/stats/top/tracks.dart';
import 'package:sonolyth/extensions/context.dart';

import 'package:sonolyth/provider/history/top.dart';

/// The Stats page's category switcher and the window it counts over.
///
/// **Selection is a chip, not an underline.** This was a Material `TabList`
/// inside a `SliverAppBar`, so the one screen no Zenith pass could open (§38d)
/// was also the only place in the app still marking a selection with a rule
/// under the label — which §27b rules out: Zenith shows selection by a colour
/// swap or a pill, never a ring or an underline. `ZenithFilterChip` is the
/// same `TopSearchCatButton` row the search screen and the library wear, and
/// it says the same thing.
///
/// **One shape at every width.** The duration control used to jump between the
/// bar's trailing slot above `md` and a right-aligned sliver of its own below
/// it. §38's lesson is that a width branch outlives the layout it was written
/// for; the chips scroll horizontally instead and the duration chip keeps its
/// place beside them.
class StatsPageTopSection extends HookConsumerWidget {
  const StatsPageTopSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final selectedIndex = useState(0);
    final historyDuration = ref.watch(playbackHistoryTopDurationProvider);
    final historyDurationNotifier =
        ref.watch(playbackHistoryTopDurationProvider.notifier);

    // "Tracks / Artists / Albums", not "Top Tracks / Top Artists / Top
    // Albums": the three long labels plus the duration chip needed 438dp of a
    // 411dp screen, so the third chip sat clipped under the duration chip
    // until you scrolled the row. "Top" is carried by the section, and these
    // are the same three words the search screen's chips use.
    final categories = [
      context.l10n.tracks,
      context.l10n.artists,
      context.l10n.albums,
    ];

    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // `TopSearchCatsLayout` pads 8 left / 8 top / 12 right and each chip
      // carries a 4dp left margin, as on the search screen.
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        spacing: ZenithFilterChip.gap,
        children: [
          for (final (index, label) in categories.indexed)
            ZenithFilterChip(
              label: label,
              selected: selectedIndex.value == index,
              onPressed: () => selectedIndex.value = index,
            ),
        ],
      ),
    );

    final durationChip = HistoryDurationChip(
      value: historyDuration,
      onChanged: (value) => historyDurationNotifier.update((_) => value),
    );

    final stacked = zenithStacksRows(context);

    return SliverMainAxisGroup(
      slivers: [
        // Pinned rather than floating: the switcher governs the list under it,
        // and an infinite list is exactly where you want to change categories
        // without scrolling back. `SliverPinnedHeader` measures its child, so
        // the row grows with the viewer's font size instead of clipping at a
        // fixed extent (§37).
        SliverPinnedHeader(
          child: Container(
            // The page colour, not a raised band — content scrolls *under*
            // this, so it has to be opaque, and nothing in Zenith is raised
            // above the page for a header (§27b).
            color: context.theme.colorScheme.background,
            child: stacked
                // Past `zenithStackedRowTextScale` the duration chip is wide
                // enough to push "Albums" out of the scroll view, so the third
                // category is only findable by dragging a row with no
                // affordance. It stops sharing the line instead — the same
                // answer, at the same threshold, that §37b gave a settings
                // row's label and value.
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      chips,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: durationChip,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: chips),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: durationChip,
                      ),
                    ],
                  ),
          ),
        ),
        switch (selectedIndex.value) {
          1 => const TopArtists(),
          2 => const TopAlbums(),
          _ => const TopTracks(),
        },
      ],
    );
  }
}
