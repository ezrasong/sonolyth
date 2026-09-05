import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/collections/formatters.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/modules/stats/summary/summary_card.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/history/summary.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

class StatsPageSummarySection extends HookConsumerWidget {
  const StatsPageSummarySection({super.key});

  /// Between the cards, and the padding around the grid.
  static const _spacing = 10.0;

  @override
  Widget build(BuildContext context, ref) {
    final summary = ref.watch(playbackHistorySummaryProvider);

    // A failed load must not present FakeData numbers as real stats.
    if (summary.hasError && summary.asData?.value == null) {
      return SliverToBoxAdapter(
        child: Center(
          child: ErrorBox(
            error: summary.error!,
            onRetry: () => ref.invalidate(playbackHistorySummaryProvider),
          ),
        ),
      );
    }

    final summaryData = summary.asData?.value ?? FakeData.historySummary;

    return Skeletonizer.sliver(
      enabled: summary.isLoading,
      child: SliverPadding(
        padding: const EdgeInsets.all(_spacing),
        sliver: SliverLayoutBuilder(builder: (context, constrains) {
          final crossAxisCount = constrains.isXs
              ? 2
              : constrains.smAndDown
                  ? 3
                  : constrains.mdAndDown
                      ? 4
                      : constrains.lgAndDown
                          ? 5
                          : 6;

          // The cell is sized by an aspect ratio, i.e. by a box — so at
          // Android's 200% font size the figure and its description needed
          // 0.3px more than the box gave and the card's `Column` overflowed.
          // §37 swept thirteen screens for exactly this and missed it, because
          // Stats had no phone entry point until §38d.
          //
          // Same rule as everywhere else: keep the measured proportion, add
          // only what the text grows by (§37b). `zenithLineGrowth` is 0 at the
          // default scale, so the cards are pixel-identical at 100%.
          final ratio = constrains.isXs ? 1.3 : 1.5;
          final cellWidth =
              (constrains.crossAxisExtent - _spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
          const figureStyle = TextStyle(fontSize: SummaryCard.figureSize);
          const descriptionStyle =
              TextStyle(fontSize: SummaryCard.descriptionSize);

          // Past the threshold the card lets its unit drop under the figure and
          // its description take one more line, because below it both were
          // *clipped* — silently, since a clip is not an overflow (item 55).
          final stacked = zenithStacksRows(context);

          // A line's height at the default scale — what the measured box was
          // sized around. `zenithLineGrowth` is the difference between the two,
          // so this needs no third helper.
          double atDefault(TextStyle style) =>
              zenithScaledLineHeight(context, style) -
              zenithLineGrowth(context, style);

          // How many lines each text may take. The unit's line is budgeted at
          // the **figure's** height, not its own: under `Skeletonizer` the
          // figure-plus-unit span is boned at its root style, so both lines
          // come out 24dp tall. Budgeting it at the unit's 13dp is what left
          // the loading state 8.3px short.
          final figureLines = stacked ? 2 : 1;
          final descriptionLines =
              SummaryCard.maxDescriptionLines + (stacked ? 1 : 0);

          double textHeight(double Function(TextStyle) lineOf, int figureCount,
                  int descriptionCount) =>
              figureCount * lineOf(figureStyle) +
              SummaryCard.figureToDescription +
              descriptionCount * lineOf(descriptionStyle) +
              SummaryCard.verticalPadding * 2;

          // Everything in the cell that is *not* text — the ghost button's own
          // padding, the card's inset — stays in the measured proportion, so
          // it is carried across rather than modelled: the box grows by
          // exactly what its text grew by, and by nothing else.
          final grown = cellWidth / ratio -
              textHeight(atDefault, 1, SummaryCard.maxDescriptionLines) +
              textHeight((style) => zenithScaledLineHeight(context, style),
                  figureLines, descriptionLines);

          // The measured proportion wins wherever it is the taller of the two,
          // which at the default font size it always is — so the grid stays
          // pixel-identical to §39's and only grows when the text needs it.
          final cellHeight = math.max(cellWidth / ratio, grown);

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: _spacing,
              crossAxisSpacing: _spacing,
              childAspectRatio: cellWidth / cellHeight,
            ),
            // The cards no longer differentiate by colour at all — not even
            // across neutral shade families. Proxima has one container fill;
            // see `SummaryCard`.
            delegate: SliverChildListDelegate([
              SummaryCard(
                title: summaryData.duration.inMinutes.toDouble(),
                unit: context.l10n
                    .summary_minutes(summaryData.duration.inMinutes),
                description: context.l10n.summary_listened_to_music,
                onTap: () {
                  context.navigateTo(const StatsMinutesRoute());
                },
              ),
              SummaryCard(
                title: summaryData.tracks.toDouble(),
                unit: context.l10n.summary_songs(summaryData.tracks),
                description: context.l10n.summary_streamed_overall,
                onTap: () {
                  context.navigateTo(const StatsStreamsRoute());
                },
              ),
              SummaryCard.unformatted(
                title: usdFormatter.format(summaryData.fees.toDouble()),
                unit: "",
                description: context.l10n.summary_owed_to_artists,
                onTap: () {
                  context.navigateTo(const StatsStreamFeesRoute());
                },
              ),
              SummaryCard(
                title: summaryData.artists.toDouble(),
                unit: context.l10n.summary_artists(summaryData.artists),
                description: context.l10n.summary_music_reached_you,
                onTap: () {
                  context.navigateTo(const StatsArtistsRoute());
                },
              ),
              SummaryCard(
                title: summaryData.albums.toDouble(),
                unit: context.l10n.summary_full_albums(summaryData.albums),
                description: context.l10n.summary_got_your_love,
                onTap: () {
                  context.navigateTo(const StatsAlbumsRoute());
                },
              ),
              SummaryCard(
                title: summaryData.playlists.toDouble(),
                unit: context.l10n.summary_playlists(summaryData.playlists),
                description: context.l10n.summary_were_on_repeat,
                onTap: () {
                  context.navigateTo(const StatsPlaylistsRoute());
                },
              ),
            ]),
          );
        }),
      ),
    );
  }
}
