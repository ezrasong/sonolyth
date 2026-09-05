import 'package:flutter/material.dart' show ListTile;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/history/top.dart';

/// The window a stats figure is measured over — "This month", "All time" — as
/// a [ZenithValueChip] that opens the radio picker.
///
/// Both places that offer it (the Stats page's top lists and the streaming
/// fees page) used shadcn's `Select`. Its trigger draws a `border` stroke and
/// a chevron, and `colorStroke` is transparent in `@style/proxima`, so what
/// was left on the page was a floating label with an arrow beside it and no
/// container at all. §20a settled the idiom for a value the viewer can change:
/// the chip well with a `textColorPrimary` label, and a tap opens the same
/// radio dialog `AdaptiveSelectTile` opens. This is that, for the one value
/// the Stats screens have.
class HistoryDurationChip extends StatelessWidget {
  const HistoryDurationChip({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HistoryDuration value;
  final ValueChanged<HistoryDuration> onChanged;

  static Map<HistoryDuration, String> labelsOf(BuildContext context) => {
        HistoryDuration.days7: context.l10n.this_week,
        HistoryDuration.days30: context.l10n.this_month,
        HistoryDuration.months6: context.l10n.last_6_months,
        HistoryDuration.year: context.l10n.this_year,
        HistoryDuration.years2: context.l10n.last_2_years,
        HistoryDuration.allTime: context.l10n.all_time,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = labelsOf(context);

    return ZenithValueChip(
      // A `ZenithValueChip` and a selected `ZenithFilterChip` are the same
      // pill with the same full-strength label, so beside the three category
      // chips this read as a fourth selected category. The glyph is what
      // separates a value from an option.
      icon: SonolythIcons.clock,
      onPressed: () => showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: HistoryDuration.values.length,
                itemBuilder: (context, index) {
                  final item = HistoryDuration.values[index];

                  return ListTile(
                    iconColor: theme.colorScheme.primary,
                    leading: item == value
                        ? const Icon(SonolythIcons.radioChecked)
                        : const Icon(SonolythIcons.radioUnchecked),
                    title: Text(labels[item]!),
                    onTap: () {
                      onChanged(item);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
      child: Text(labels[value]!),
    );
  }
}
