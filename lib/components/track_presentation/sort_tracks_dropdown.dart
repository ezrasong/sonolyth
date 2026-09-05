import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/pages/library/user_local_tracks/user_local_tracks.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/extensions/context.dart';

List<AdaptiveMenuButton<SortBy>> _sortItems(BuildContext context, SortBy? value) {
  return [
    AdaptiveMenuButton(
      value: SortBy.none,
      enabled: value != SortBy.none,
      child: Text(context.l10n.none),
    ),
    AdaptiveMenuButton(
      value: SortBy.ascending,
      enabled: value != SortBy.ascending,
      child: Text(context.l10n.sort_a_z),
    ),
    AdaptiveMenuButton(
      value: SortBy.descending,
      enabled: value != SortBy.descending,
      child: Text(context.l10n.sort_z_a),
    ),
    AdaptiveMenuButton(
      value: SortBy.newest,
      enabled: value != SortBy.newest,
      child: Text(context.l10n.sort_newest),
    ),
    AdaptiveMenuButton(
      value: SortBy.oldest,
      enabled: value != SortBy.oldest,
      child: Text(context.l10n.sort_oldest),
    ),
    AdaptiveMenuButton(
      value: SortBy.duration,
      enabled: value != SortBy.duration,
      child: Text(context.l10n.sort_duration),
    ),
    AdaptiveMenuButton(
      value: SortBy.artist,
      enabled: value != SortBy.artist,
      child: Text(context.l10n.sort_artist),
    ),
    AdaptiveMenuButton(
      value: SortBy.album,
      enabled: value != SortBy.album,
      child: Text(context.l10n.sort_album),
    ),
  ];
}

/// Opens the sort picker from somewhere that is not the dropdown button — the
/// collection header's menu, where Poweramp keeps its "Sort" entry. Anchored
/// to [context] on wide layouts; a bottom sheet on phones, like every other
/// [AdaptivePopSheetList].
Future<void> showSortTracksSheet(
  BuildContext context, {
  SortBy? value,
  ValueChanged<SortBy>? onChanged,
}) {
  return AdaptivePopSheetList<SortBy>(
    variance: ButtonVariance.ghost,
    headings: [Text(context.l10n.sort_tracks)],
    onSelected: onChanged,
    tooltip: context.l10n.sort_tracks,
    icon: const Icon(SonolythIcons.sort),
    items: (context) => _sortItems(context, value),
  ).showDropdownMenu(context, Offset.zero);
}

class SortTracksDropdown extends StatelessWidget {
  final SortBy? value;
  final void Function(SortBy)? onChanged;
  const SortTracksDropdown({
    this.onChanged,
    this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptivePopSheetList<SortBy>(
      // `ItemHeader*Button`: a bare glyph, like the rest of the row.
      variance: ButtonVariance.ghost,
      headings: [
        Text(context.l10n.sort_tracks),
      ],
      onSelected: onChanged,
      tooltip: context.l10n.sort_tracks,
      icon: const Icon(SonolythIcons.sort),
      items: (context) => _sortItems(context, value),
    );
  }
}
