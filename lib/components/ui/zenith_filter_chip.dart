import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

/// Proxima's category selector — `@style/TopSearchCatButton`, whose background
/// Proxima re-points at `@drawable/search_filter_checkable_non_tr_rounded_large`.
///
/// **Selection is shown by the label, not by the pill.** The skin's store
/// screenshots (the reference) measure every chip in the row — "All",
/// "Albums", "Artists", "Album Artists" — as the same `#0E0E0E` pill
/// (`colorBgPrimary`) on the black page, 27dp tall, and only the selected
/// one's label is at full `textColorPrimary`; the rest sit at
/// `textColorSecondary` (60%). A Material chip inverts its fill when checked;
/// this one never changes fill at all. Under the skin's default *Dark*
/// background the unchecked pill would be `colorAABgColor`, a well one step
/// below the page — but the pictures run the Black option, where that well
/// and the page are the same black, and the pictures win.
///
/// Note `textColorPrimaryInverse` is `#e6ffffff` in `@style/proxima` — the same
/// value as `textColorPrimary`. The skin deliberately neutralises "inverse":
/// an achromatic dark theme has nothing to invert to.
class ZenithFilterChip extends StatelessWidget {
  const ZenithFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  /// Sits inside the pill, after the label — the download count on the
  /// library's "Downloads" chip.
  final Widget? trailing;

  /// `corners_large` in `@style/proxima`.
  static const radius = 30.0;

  /// `TopSearchCatButton` padding: 12 / 5 / 12 / 5.
  static const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 5);

  /// `TopSearchCatButton` `layout_marginLeft`.
  static const gap = 4.0;

  /// `TopSearchTarget_Text` — 13dp **bold**. `Capitalizer` is false in
  /// `@style/proxima`, so it is not all-caps.
  static const textSize = 13.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: ZenithPressable(
        onPressed: onPressed,
        child: AnimatedContainer(
          duration: ZenithMotion.fade,
          curve: ZenithMotion.fadeCurve,
          padding: padding,
          decoration: BoxDecoration(
            color: zenithBgPrimary(colorScheme),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colorScheme.foreground
                      : colorScheme.mutedForeground,
                ),
              ),
              if (trailing != null) ...[
                const Gap(6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A value or a tag as a chip: the same `TopSearchCatButton` pill as
/// [ZenithFilterChip], but the label is `textColorPrimary`.
///
/// It states what something currently *is* — a setting's value, a plugin's
/// version, the host it came from — rather than offering one option among
/// several, so it does not dim the way an unselected filter does. Tappable when
/// [onPressed] is given (a value that opens its picker, a host that opens its
/// page), static otherwise.
///
/// This replaces three stock things at once: shadcn's `OutlineBadge` and the
/// `Select` trigger (both draw a `border` stroke, and `colorStroke` is
/// transparent in `@style/proxima`), and `PrimaryBadge`/`SecondaryBadge`,
/// whose fills are pure white and the card colour — the first has no source in
/// an achromatic skin, and the second vanishes on a `popup_bg` card.
class ZenithValueChip extends StatelessWidget {
  const ZenithValueChip({
    super.key,
    required this.child,
    this.icon,
    this.leading,
    this.onPressed,
  });

  final Widget child;
  final IconData? icon;

  /// A leading widget that is not a glyph — a colour swatch, an avatar. Used
  /// in place of [icon] when both are given.
  final Widget? leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    final chip = Container(
      padding: ZenithFilterChip.padding,
      decoration: BoxDecoration(
        color: zenithBgPrimary(colorScheme),
        borderRadius: BorderRadius.circular(ZenithFilterChip.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const Gap(6),
          ] else if (icon != null) ...[
            Icon(icon, size: 14, color: colorScheme.foreground),
            const Gap(6),
          ],
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: ZenithFilterChip.textSize,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: child,
          ),
        ],
      ),
    );

    if (onPressed == null) return chip;
    // `ZenithPressable` is a bare `GestureDetector`, which annotates the node
    // the label already contributes to but claims no role — the §36 shape of
    // defect. The label names it; only `button` is missing, and adding a
    // `label:` here would have it read twice (§36b).
    return Semantics(
      button: true,
      child: ZenithPressable(onPressed: onPressed, child: chip),
    );
  }
}
