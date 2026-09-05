import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:sonolyth/collections/formatters.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/modules/stats/common/artist_item.dart';
import 'package:sonolyth/modules/stats/common/history_duration_chip.dart';
import 'package:sonolyth/extensions/context.dart';

import 'package:sonolyth/provider/history/top.dart';
import 'package:sonolyth/provider/history/top/tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class StatsStreamFeesPage extends HookConsumerWidget {
  static const name = "stats_stream_fees";

  const StatsStreamFeesPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final duration = useState<HistoryDuration>(HistoryDuration.days30);

    final topTracks = ref.watch(
      historyTopTracksProvider(duration.value),
    );
    final topTracksNotifier =
        ref.watch(historyTopTracksProvider(duration.value).notifier);

    final artistsData = useMemoized(
      () => topTracksNotifier.artists,
      [topTracks.asData?.value],
    );

    final total = useMemoized(
      () => artistsData.fold<double>(
        0,
        (previousValue, element) => previousValue + element.count * 0.005,
      ),
      [artistsData],
    );

    final totalText = Text(
      context.l10n.total_money(usdFormatter.format(total)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // The figure is the point of the page, so it takes the same 24dp bold
      // readout a `SummaryCard` gives one (`SleepTimerValue_Text`) rather than
      // shadcn's `.semiBold().large()`.
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: context.theme.colorScheme.foreground,
      ),
    );

    final durationChip = HistoryDurationChip(
      value: duration.value,
      onChanged: (value) => duration.value = value,
    );

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            title: Text(context.l10n.streaming_fees_hypothetical),
          )
        ],
        child: CustomScrollView(
          slivers: [
            SliverCrossAxisConstrained(
              maxCrossAxisExtent: 600,
              alignment: -1,
              child: SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.l10n.hipotetical_calculation,
                    // `ItemTextLine2`'s 11dp, but at `ColorTrackLine`
                    // rather than its `textColorPrimary`: this is a
                    // disclaimer, and §12's rule is that what explains
                    // recedes below what it explains. The token itself is
                    // full-strength because it is used for a settings row's
                    // second line, where the line *is* the content.
                    style: TextStyle(
                      fontSize: 11,
                      color: context.theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // Past `zenithStackedRowTextScale` the total and the chip stop
                // sharing the line: at 200% the chip's natural width left
                // "Total $0.06" ellipsised to "Total $0.…", i.e. it hid the
                // one number the page exists to report. Same rule as the
                // category row in `top.dart` and a settings row in §37b.
                child: zenithStacksRows(context)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          totalText,
                          const Gap(8),
                          durationChip,
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: totalText),
                          const Gap(8),
                          durationChip,
                        ],
                      ),
              ),
            ),
            SliverSafeArea(
              sliver: Skeletonizer.sliver(
                enabled: topTracks.isLoading && !topTracks.isLoadingNextPage,
                child: SliverInfiniteList(
                  onFetchData: () async {
                    await topTracksNotifier.fetchMore();
                  },
                  hasError: topTracks.hasError,
                  isLoading:
                      topTracks.isLoading && !topTracks.isLoadingNextPage,
                  hasReachedMax: topTracks.asData?.value.hasMore ?? true,
                  itemCount: artistsData.length,
                  itemBuilder: (context, index) {
                    final artist = artistsData[index];
                    return StatsArtistItem(
                      artist: artist.artist,
                      info: Text(usdFormatter.format(artist.count * 0.005)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
