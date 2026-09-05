import 'package:auto_size_text/auto_size_text.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/formatters.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

/// A stats figure — a number, its unit, and a line saying what it counts.
///
/// **Every card is the same colour.** It used to take a `ColorShades` and paint
/// its fill, border and *all three* text runs from that family, so the six cards
/// differed from each other by hue family (zinc / neutral / stone / gray /
/// slate). Those are all greys, so the page was not chromatic — but "each tile
/// owns a colour" is still a Material idea, and Proxima has no equivalent: a
/// container is `@drawable/item_bg` or `@drawable/popup_bg`, one flat
/// `#1a1a1a` at `corners_medium`, and what separates the elements inside it is
/// **size and alpha**, never tint.
///
/// So the fill is `card`, there is no border, and the three runs grade
/// 90% → 60% → 50% down the card the same way a track row grades title → line 2
/// → meta.
class SummaryCard extends StatelessWidget {
  final String title;
  final String unit;
  final String description;
  final VoidCallback? onTap;

  SummaryCard({
    super.key,
    required double title,
    required this.unit,
    required this.description,
    this.onTap,
  }) : title = compactNumberFormatter.format(title);

  const SummaryCard.unformatted({
    super.key,
    required this.title,
    required this.unit,
    required this.description,
    this.onTap,
  });

  /// `SleepTimerValue_Text` — 24dp **bold**, the largest numeric readout the
  /// skin has. Well under the 29sp `zenithPageTitle` ceiling, as a figure inside
  /// a tile should be.
  static const figureSize = 24.0;

  /// The unit riding the figure — `ItemTrackLine2`'s step down from it. Named
  /// for the same reason `descriptionSize` is: past
  /// `zenithStackedRowTextScale` the unit can take a line of its own, and the
  /// grid has to give the cell room for it (see `summary.dart`).
  static const unitSize = 13.0;

  /// `ItemTrackMeta_Text` size at `colorTrackMeta` — the bottom step of the
  /// three-step grade. Named because the grid has to know how much a line of it
  /// grows to give the cell room (see `summary.dart`).
  static const descriptionSize = 11.0;

  /// The most description lines any card asks for: the "Owed to artists" card
  /// carries an embedded newline, so it wants two.
  static const maxDescriptionLines = 2;

  /// Between the figure line and the description.
  static const figureToDescription = 5.0;

  /// Above the figure and below the description. Named because the grid adds
  /// it back when it works out how tall the tallest card needs to be.
  static const verticalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    final descriptionNewLines = description.split("").where((s) => s == "\n");

    // At Android's 200% the figure and its unit stopped fitting on one line and
    // `AutoSizeText` could not shrink its way out — `minFontSize` is measured
    // against the ambient style, not against the 24dp span — so it ran out of
    // room and **clipped**. Silently: a clip is not a `RenderFlex` overflow, so
    // logcat said nothing while the "55 minutes" card read "55", which is the
    // half that says nothing on its own. Past `zenithStackedRowTextScale` each
    // of the two texts may take one more line, and `summary.dart` sizes the
    // cell for it.
    final stacked = zenithStacksRows(context);

    return Card(
      fillColor: colorScheme.card,
      filled: true,
      // No border. `item_bg` and `popup_bg` are both a bare `<solid>` — Proxima
      // never outlines a filled container, because the fill is already the only
      // thing separating it from the ground.
      borderColor: Colors.transparent,
      padding: EdgeInsets.zero,
      // `corners_medium` / `corners_popup` = 20dp, which is `radiusXl` now.
      borderRadius: BorderRadius.circular(context.theme.radiusXl),
      child: Button.ghost(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: 15,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AutoSizeText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        fontSize: figureSize,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    TextSpan(
                      // The unit rides the figure but is not part of it, so it
                      // drops a step — `ItemTrackLine2` at 60%.
                      text: " $unit",
                      style: TextStyle(
                        fontSize: unitSize,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
                // Two lines only past the threshold, and it *may* take the
                // second rather than must — "16 songs" still fits on one line
                // at 1.4, so only the cards that need the break take it.
                maxLines: stacked ? 2 : 1,
              ),
              const Gap(figureToDescription),
              AutoSizeText(
                description,
                maxLines: (description.contains("\n")
                        ? descriptionNewLines.length + 1
                        : 1) +
                    (stacked ? 1 : 0),
                minFontSize: 9,
                // `ItemTrackMeta_Text` size at `colorTrackMeta` — the bottom
                // step of the same three-step grade a track row uses.
                style: TextStyle(
                  fontSize: descriptionSize,
                  color: zenithTrackMeta(colorScheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
