import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/collections/routes.gr.dart';

import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/string.dart';
import 'package:sonolyth/hooks/controllers/use_shadcn_text_editing_controller.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/pages/search/search_results_header.dart';
import 'package:sonolyth/pages/search/tabs/albums.dart';
import 'package:sonolyth/pages/search/tabs/all.dart';
import 'package:sonolyth/pages/search/tabs/artists.dart';
import 'package:sonolyth/pages/search/tabs/playlists.dart';
import 'package:sonolyth/pages/search/tabs/tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/search/all.dart';
import 'package:sonolyth/provider/metadata_plugin/search/tracks.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

final searchTermStateProvider = StateProvider<String>((ref) {
  return "";
});

@RoutePage()
class SearchPage extends HookConsumerWidget {
  static const name = "search";

  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useShadcnTextEditingController();
    final focusNode = useFocusNode();

    final searchTerm = ref.watch(searchTermStateProvider);
    final searchChipSnapshot = ref.watch(metadataPluginSearchChipsProvider);
    final selectedChip = useState<String?>(
      searchChipSnapshot.asData?.value.first ?? "all",
    );

    ref.listen(
      metadataPluginSearchChipsProvider,
      (previous, next) {
        selectedChip.value = next.asData?.value.first ?? "all";
      },
    );

    // The results the header row acts on: the current chip's tracks. Both are
    // the providers the tabs already watch, so this never fires a request of
    // its own; a chip with no tracks (Albums, Artists, Playlists) is null and
    // the row's shuffle / play / Select sit disabled.
    final List<SonolythFullTrackObject>? resultTracks =
        switch (selectedChip.value) {
      "tracks" => ref
              .watch(metadataPluginSearchTracksProvider(searchTerm))
              .asData
              ?.value
              .items ??
          const [],
      "all" => ref
              .watch(metadataPluginSearchAllProvider(searchTerm))
              .asData
              ?.value
              .tracks ??
          const [],
      _ => null,
    };

    // View mode for the chips that render a `PlaybuttonView`, owned here so
    // the header menu can hold it (Poweramp's list options live in the
    // `header_menu`, not in a toolbar of their own).
    final viewGrid = useState<bool?>(null);
    // Artists joined the list since §34 — `ArtistCard` grew a `.tile`, which
    // is what the Artists chip's missing `header_menu` was waiting on (§28d).
    const viewModeChips = {"albums", "playlists", "artists"};
    final hasViewMode = viewModeChips.contains(selectedChip.value);

    // A new query drops the selection: it belonged to the old results.
    ref.listen(searchTermStateProvider, (previous, next) {
      ref.read(searchSelectionProvider.notifier).clear();
    });

    useEffect(() {
      controller.text = searchTerm;

      return null;
    }, []);

    void onSubmitted(String value) {
      ref.read(searchTermStateProvider.notifier).state = value;
      focusNode.unfocus();
      if (value.trim().isEmpty) {
        return;
      }
      KVStoreService.setRecentSearches(
        {
          value,
          ...KVStoreService.recentSearches,
        }.toList(),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Only the intercepted system back (didPop false) is ours; auto_route
        // also fires this while it swaps tab routes (see library.dart). And a
        // shadcn sheet (header menu, track options) is an overlay, not a
        // route, whose own back handling never runs inside the nested router:
        // a press with one open closes it and stays — it used to go Home.
        if (didPop || context.closeOpenDrawer()) return;
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          child: Builder(builder: (context) {
            if (searchChipSnapshot.error
                case MetadataPluginException(
                  errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
                  message: _
                )) {
              return const Center(child: NoDefaultMetadataPlugin());
            }

            if (searchChipSnapshot.hasError) {
              return Center(
                child: ErrorBox(
                  error: searchChipSnapshot.error!,
                  onRetry: () {
                    ref.invalidate(metadataPluginSearchChipsProvider);
                  },
                ),
              );
            }

            return Column(
              children: [
                // `TopSearchPanel`: a 48dp row with 12dp margins holding the
                // pill edit (`TopListSearchEditText` on `searchbar_bg`, radius
                // 60, `searchbar_icon` at the left) and, 5dp to its right, the
                // *separate* round close button (`TopSearchCloseButton` on
                // `searchbar_bg_close`) — the skin's screenshots show exactly
                // this pair, both `colorBgPrimary` pills on the black page,
                // 12dp in from either edge with 6dp between them. Close clears
                // the query; with nothing to clear it leaves the search, as
                // Poweramp's does.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) {
                              final suggestions = controller.text.isEmpty
                                  ? KVStoreService.recentSearches
                                  : KVStoreService.recentSearches
                                      .where(
                                        (s) =>
                                            weightedRatio(
                                              s.toLowerCase(),
                                              controller.text.toLowerCase(),
                                            ) >
                                            50,
                                      )
                                      .toList();

                              return AutoComplete(
                                suggestions: suggestions,
                                completer: (suggestion) => suggestion,
                                mode: AutoCompleteMode.replaceAll,
                                child: TextField(
                                  decoration: zenithSearchField(
                                      context.theme.colorScheme),
                                  borderRadius: BorderRadius.circular(60),
                                  border: const Border.fromBorderSide(
                                      BorderSide.none),
                                  filled: false,
                                  autofocus: true,
                                  controller: controller,
                                  focusNode: focusNode,
                                  features: [
                                    InputFeature.leading(
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Icon(
                                          SonolythIcons.search,
                                          size: 22,
                                          color:
                                              context.theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  textInputAction: TextInputAction.search,
                                  placeholder: Text(context.l10n.search),
                                  onSubmitted: onSubmitted,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Semantics(
                          button: true,
                          label: context.l10n.close,
                          child: ZenithPressable(
                            onPressed: () {
                              if (controller.text.isNotEmpty) {
                                controller.clear();
                                ref
                                    .read(searchTermStateProvider.notifier)
                                    .state = "";
                                return;
                              }
                              context.navigateTo(const HomeRoute());
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration:
                                  zenithSearchField(context.theme.colorScheme),
                              child: Icon(
                                SonolythIcons.close,
                                size: 22,
                                color: context.theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // `TopSearchCatsLayout` pads 8 left / 8 top / 12 right, and
                  // each `TopSearchCatButton` carries a 4dp left margin; the
                  // first chip lands where the pill's edge is.
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    spacing: ZenithFilterChip.gap,
                    children: [
                      if (searchChipSnapshot.asData?.value != null)
                        for (final chip in searchChipSnapshot.asData!.value)
                          ZenithFilterChip(
                            label: chip.capitalize(),
                            selected: selectedChip.value == chip,
                            onPressed: () {
                              selectedChip.value = chip;
                              ref
                                  .read(searchSelectionProvider.notifier)
                                  .clear();
                            },
                          ),
                    ],
                  ),
                ),
                // `merge_item_text_header` in `scene_search_header`: the
                // shuffle / play / Select row and the `header_menu` glyph
                // under the chips — the skin's search panel shows it and this
                // page never had it.
                SearchResultsHeader(
                  searchTerm: searchTerm,
                  tracks: resultTracks,
                  isGrid: viewGrid.value,
                  onViewMode:
                      hasViewMode ? (grid) => viewGrid.value = grid : null,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: ZenithMotion.scene,
                    switchInCurve: ZenithMotion.fadeCurve,
                    switchOutCurve: ZenithMotion.fadeCurve,
                    child: switch (selectedChip.value) {
                      "tracks" => const SearchPageTracksTab(),
                      "albums" => SearchPageAlbumsTab(isGrid: viewGrid.value),
                      "artists" => SearchPageArtistsTab(isGrid: viewGrid.value),
                      "playlists" =>
                        SearchPagePlaylistsTab(isGrid: viewGrid.value),
                      _ => const SearchPageAllTab(),
                    },
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
