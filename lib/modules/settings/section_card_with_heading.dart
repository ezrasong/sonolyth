import 'package:flutter/material.dart' show ListTileTheme, ListTileThemeData;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Theme, ThemeData;
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

/// A settings group: a `SubheadText` label over a run of flat rows.
///
/// **The rows carry no card and no border.** Poweramp's list item background is
/// `@drawable/item_bg`, and at the level a normal row is drawn at
/// (`ITEM_BG_LEVEL_FEEDBACK`) that resolves to `ripple_rounded_medium_library`
/// — a ripple with a rounded mask and *no fill*. Only intermediate and popup
/// levels get a solid colour. So a settings row in Zenith is transparent, sits
/// directly on the ground, and shows nothing at all until it is touched. The
/// outlined cards this used to draw were the loudest remaining bit of stock
/// Spotube on the screen.
class SectionCardWithHeading extends StatelessWidget {
  final String heading;
  final List<Widget> children;
  const SectionCardWithHeading({
    super.key,
    required this.heading,
    required this.children,
  });

  /// `corners_medium` in `@style/proxima` — the radius of the row's ripple
  /// mask. It is the only rounding a row has.
  static const rowRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    return ListTileTheme(
      data: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rowRadius),
        ),
        textColor: colorScheme.foreground,
        iconColor: colorScheme.foreground,
        selectedColor: colorScheme.accent,
        // `ItemTextLine2` — 11dp at `textColorPrimary`, taken literally.
        // Poweramp does not dim an item's second line the way it dims a track
        // row's: `ItemTextLine2` and `ItemTextTitle` are both primary, and only
        // size separates them.
        subtitleTextStyle: TextStyle(
          fontSize: 11,
          color: colorScheme.foreground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // `ItemSubheadWithButton` pads 8dp left/top/right.
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              heading,
              // `SubheadText`. A settings group heading is the same kind of
              // label as a rail heading, so it uses the same token.
              style: zenithSubhead(colorScheme),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // No gap: Poweramp's rows are contiguous. Their own vertical
              // padding is the separation, the way a track list's rows are
              // separated.
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
