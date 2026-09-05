import 'package:flutter/material.dart' show ListTile, ListTileControlAffinity;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';

/// A settings row whose value is picked from a fixed list.
///
/// The current value is a [ZenithValueChip] and a tap — on the chip or on the
/// row — opens the radio picker, on every width. It used to switch to shadcn's
/// `Select` trigger above `sm`, which draws a `border` stroke (`colorStroke` is
/// transparent in `@style/proxima`), and to an `OutlineBadge` below it, which
/// draws another; one idiom now, and it is the same well the library and search
/// chips are made of.
class AdaptiveSelectTile<T> extends HookWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final List<Widget>? trailing;
  final ListTileControlAffinity? controlAffinity;
  final T value;
  final ValueChanged<T?>? onChanged;

  final List<SelectItemButton<T>> options;

  /// Show the current value beside the row. When false only the row is
  /// tappable and nothing is shown until the picker opens.
  final bool showValueWhenUnfolded;

  /// Kept for call-site compatibility; the picker is a dialog on every width
  /// now, so nothing reads them.
  final bool? breakLayout;
  final BoxConstraints? popupConstraints;
  final PopoverConstraint? popupWidthConstraint;

  const AdaptiveSelectTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.options,
    this.controlAffinity = ListTileControlAffinity.trailing,
    this.subtitle,
    this.secondary,
    this.trailing,
    this.breakLayout,
    this.showValueWhenUnfolded = true,
    super.key,
    this.popupConstraints,
    this.popupWidthConstraint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = options.firstWhere((element) => element.value == value);

    Future<void> pick() => showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final item = options[index];

                    return ListTile(
                      iconColor: theme.colorScheme.primary,
                      leading: item.value == value
                          ? const Icon(SonolythIcons.radioChecked)
                          : const Icon(SonolythIcons.radioUnchecked),
                      title: item.child,
                      onTap: () {
                        onChanged?.call(item.value);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            );
          },
        );

    final enabled = onChanged != null;
    final Widget? control = showValueWhenUnfolded
        ? ZenithValueChip(
            onPressed: enabled ? pick : null,
            child: current.child,
          )
        : null;

    // The chip takes its natural width and `ListTile` gives the label
    // whatever is left, so a long value at a large font size squeezed the
    // label to a one-word-per-line column: "Marketplace Region" came out as
    // "Mar / ketp / lace / Regi / on" at 200% (§37). Past
    // [zenithStackedRowTextScale] the value stops sharing the row and sits
    // under the label instead — which is what Android's own settings do, and
    // is invisible at every scale the skin was measured at.
    final stacked = zenithStacksRows(context) && control != null;

    return ListTile(
      title: title,
      subtitle: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) subtitle!,
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: control,
                  ),
                ),
              ],
            )
          : subtitle,
      leading: controlAffinity != ListTileControlAffinity.leading
          ? secondary
          : (stacked ? null : control),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 5,
        children: [
          ...?trailing,
          if (controlAffinity == ListTileControlAffinity.leading &&
              secondary != null)
            secondary!
          else if (controlAffinity == ListTileControlAffinity.trailing &&
              control != null &&
              !stacked)
            control,
        ],
      ),
      onTap: enabled ? pick : null,
    );
  }
}
