import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/components/ui/sheet_aware_pop_scope.dart';
import 'package:sonolyth/components/track_presentation/presentation_list.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/presentation_state.dart';
import 'package:sonolyth/components/track_presentation/presentation_top.dart';
import 'package:sonolyth/components/track_presentation/presentation_modifiers.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/utils/platform.dart';

class TrackPresentation extends HookConsumerWidget {
  final TrackPresentationOptions options;
  const TrackPresentation({
    super.key,
    required this.options,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();
    final focusNode = useFocusNode();
    final scale = context.theme.scaling;

    // Poweramp reveals the list filter from the header's search glyph and the
    // glyph closes it again; the row is otherwise not there. A selection also
    // brings the row in, because select-all and the bulk-action menu live on
    // it — but without focusing the filter.
    final filterOpen = useState(false);
    final hasSelection = ref.watch(
      presentationStateProvider(options.collection)
          .select((state) => state.isSelecting),
    );

    useEffect(() {
      if (!kIsMobile) return null;
      void listener() {
        if (!scrollController.hasClients) return;

        if (focusNode.hasFocus) {
          scrollController.animateTo(
            300 * scale,
            duration: ZenithMotion.slide,
            curve: ZenithMotion.slideCurve,
          );
        }
      }

      focusNode.addListener(listener);
      return () {
        focusNode.removeListener(listener);
      };
    }, [focusNode, scrollController, scale]);

    // Poweramp's header art runs under the status bar and the header's own
    // back decor ("‹ Albums") replaces a title bar; wide layouts keep a bar for
    // the window controls but drop its back button for the same reason.
    final isWide = MediaQuery.sizeOf(context).mdAndUp;

    return Data<TrackPresentationOptions>.inherit(
      data: options,
      // A collection page is a pushed route with no back handler of its own,
      // so BACK with a track-options or header sheet open used to pop the
      // page and strand the sheet (§29a's fault by a different route).
      child: SheetAwarePopScope(
        child: SafeArea(
          top: isWide,
          bottom: false,
          child: Scaffold(
            headers: [
              if (isWide)
                const TitleBar(automaticallyImplyLeading: false, height: 32),
            ],
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                TrackPresentationTopSection(
                  searchActive: filterOpen.value,
                  onSearch: () => filterOpen.value = !filterOpen.value,
                  selectionActive: hasSelection,
                  // Poweramp's header "Select" toggles selection mode.
                  onSelect: () => ref
                      .read(presentationStateProvider(options.collection)
                          .notifier)
                      .toggleSelectionMode(),
                ),
                const SliverGap(4),
                SliverList.list(
                  children: [
                    TrackPresentationModifiersSection(
                      focusNode: focusNode,
                      expanded: filterOpen.value || hasSelection,
                      filterActive: filterOpen.value,
                    ),
                  ],
                ),
                const PresentationListSection(),
                const SliverSafeArea(sliver: SliverGap(10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
