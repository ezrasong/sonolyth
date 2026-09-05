import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/components/track_presentation/sort_tracks_dropdown.dart';
import 'package:sonolyth/components/track_presentation/presentation_actions.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/presentation_state.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/hooks/controllers/use_shadcn_text_editing_controller.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

/// The list-filter row under a collection header: select-all, the filter
/// field (`TopListSearchEditText`), sort, and the bulk-action menu.
///
/// Poweramp does not show this permanently — the header's search glyph
/// reveals the list filter and the glyph closes it again — so the row is
/// collapsed to nothing until [expanded] asks for it. [filterActive] is the
/// glyph's own state: flipping it on focuses the field, flipping it off clears
/// the filter. A selection also expands the row (without stealing focus), since
/// the select-all box and the bulk-action menu live here.
class TrackPresentationModifiersSection extends HookConsumerWidget {
  final FocusNode? focusNode;
  final bool expanded;
  final bool filterActive;

  const TrackPresentationModifiersSection({
    super.key,
    this.focusNode,
    this.expanded = true,
    this.filterActive = true,
  });

  @override
  Widget build(BuildContext context, ref) {
    final options = TrackPresentationOptions.of(context);
    final state = ref.watch(presentationStateProvider(options.collection));
    final notifier = ref.watch(
      presentationStateProvider(options.collection).notifier,
    );

    final controller = useShadcnTextEditingController();
    final scale = context.theme.scaling;

    // The filter is a fuzzy scan over the whole track list; debounce it so it
    // runs once per pause in typing instead of on every keystroke.
    final filterDebounce = useRef<Timer?>(null);
    useEffect(() => () => filterDebounce.value?.cancel(), const []);

    // Opening from the header glyph focuses the field once it has laid out;
    // closing drops whatever was typed so the list goes back to the whole
    // collection, the way Poweramp's close does.
    final wasFilterActive = usePrevious(filterActive);
    useEffect(() {
      if (filterActive && wasFilterActive != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) focusNode?.requestFocus();
        });
      } else if (!filterActive && wasFilterActive == true) {
        filterDebounce.value?.cancel();
        focusNode?.unfocus();
        if (controller.text.isNotEmpty) {
          controller.clear();
          notifier.clearFilter();
        }
      }
      return null;
    }, [filterActive]);

    return LayoutBuilder(builder: (context, constrains) {
      final row = Padding(
        padding: EdgeInsets.fromLTRB(
          (constrains.mdAndUp ? 16 : 8) * scale,
          8 * scale,
          (constrains.mdAndUp ? 16 : 8) * scale,
          8 * scale,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  state: options.tracks.isNotEmpty &&
                          state.selectedTracks.length == options.tracks.length
                      ? CheckboxState.checked
                      : CheckboxState.unchecked,
                  onChanged: (value) {
                    if (value == CheckboxState.checked) {
                      notifier.selectAllTracks();
                    } else {
                      notifier.deselectAllTracks();
                    }
                  },
                ),
              ],
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 320 * scale,
                        maxHeight: 38 * scale,
                      ),
                      child: TextField(
                        // `searchbar_bg`: fully round, page-coloured,
                        // no stroke. See `zenithSearchField`.
                        decoration:
                            zenithSearchField(context.theme.colorScheme),
                        controller: controller,
                        focusNode: focusNode,
                        placeholder: Text(context.l10n.search_tracks),
                        onChanged: (value) {
                          filterDebounce.value?.cancel();
                          if (value.isEmpty) {
                            notifier.clearFilter();
                            return;
                          }
                          filterDebounce.value = Timer(
                            const Duration(milliseconds: 250),
                            () => notifier.filterTracks(value),
                          );
                        },
                        features: [
                          InputFeature.leading(
                            Icon(
                              SonolythIcons.search,
                              color: context.theme.colorScheme.mutedForeground,
                            ),
                          ),
                          InputFeature.trailing(
                            ListenableBuilder(
                                listenable: controller,
                                builder: (context, _) {
                                  return AnimatedCrossFade(
                                    duration: ZenithMotion.fade,
                                    firstCurve: ZenithMotion.fadeCurve,
                                    secondCurve: ZenithMotion.fadeCurve,
                                    crossFadeState: controller.text.isEmpty
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    firstChild:
                                        const SizedBox.square(dimension: 20),
                                    // No scale-from-zero pop: Proxima swaps
                                    // state with alpha alone.
                                    secondChild: ZenithTooltip(
                                      message: context.l10n.clear_filter,
                                      child: IconButton.ghost(
                                        size: const ButtonSize(.6),
                                        icon: const Icon(SonolythIcons.close),
                                        onPressed: () {
                                          filterDebounce.value?.cancel();
                                          controller.clear();
                                          notifier.clearFilter();
                                        },
                                      ),
                                    ),
                                  );
                                }),
                          )
                        ],
                      ),
                    ),
                  ),
                  SortTracksDropdown(
                    value: state.sortBy,
                    onChanged: (value) {
                      notifier.sortTracks(value);
                    },
                  ),
                  const TrackPresentationActionsSection(),
                ],
              ),
            ),
          ],
        ),
      );

      // Expand / collapse is a reflow, so it takes the scene token; the
      // collapsed state is a zero-height box, not an `Offstage`, so the
      // height animates both ways.
      return AnimatedSize(
        duration: ZenithMotion.scene,
        curve: ZenithMotion.slideCurve,
        alignment: Alignment.topCenter,
        child:
            expanded ? row : const SizedBox(width: double.infinity, height: 0),
      );
    });
  }
}
