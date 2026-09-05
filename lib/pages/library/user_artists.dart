import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:collection/collection.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';

import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/fallbacks/anonymous_fallback.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_view.dart';
import 'package:sonolyth/modules/artist/artist_card.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/library/artists.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';
import 'package:sonolyth/components/fallbacks/zenith_illustration.dart';

@RoutePage()
class UserArtistsPage extends HookConsumerWidget {
  static const name = 'user_artists';
  const UserArtistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);

    final artistQuery = ref.watch(metadataPluginSavedArtistsProvider);
    final artistQueryNotifier =
        ref.watch(metadataPluginSavedArtistsProvider.notifier);

    final searchText = useState('');

    // Poweramp keeps the view mode in the list header's menu; null = decide
    // from the width, as `PlaybuttonView` always did. Artists only gained a
    // list mode in §34, when `ArtistCard` picked up a `.tile` variant.
    final viewGrid = useState<bool?>(null);

    final filteredArtists = useMemoized(() {
      final artists = artistQuery.asData?.value.items ?? [];

      if (searchText.value.isEmpty) {
        return artists.toList();
      }
      return artists
          .map((e) => (
                weightedRatio(e.name, searchText.value),
                e,
              ))
          .sorted((a, b) => b.$1.compareTo(a.$1))
          .where((e) => e.$1 > 50)
          .map((e) => e.$2)
          .toList();
    }, [artistQuery.asData?.value.items, searchText.value]);

    final controller = useScrollController();

    if (artistQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    if (authenticated.asData?.value != true) {
      return const AnonymousFallback();
    }

    if (artistQuery.hasError) {
      return ErrorBox(
        error: artistQuery.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSavedArtistsProvider);
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        child: material.RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(metadataPluginSavedArtistsProvider);
          },
          child: InterScrollbar(
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  // `merge_item_text_header`: the filter behind the search
                  // glyph.
                  SliverToBoxAdapter(
                    child: ZenithListToolbar(
                      filterPlaceholder: context.l10n.filter_artist,
                      onFilterChanged: (value) => searchText.value = value,
                      menuItems: (context) => [
                        AdaptiveMenuButton(
                          value: "grid",
                          leading: const Icon(SonolythIcons.grid),
                          child: Text(context.l10n.grid_view),
                        ),
                        AdaptiveMenuButton(
                          value: "list",
                          leading: const Icon(SonolythIcons.list),
                          child: Text(context.l10n.list_view),
                        ),
                      ],
                      onMenuSelected: (value) =>
                          viewGrid.value = value == "grid",
                    ),
                  ),
                  if (filteredArtists.isNotEmpty || artistQuery.isLoading)
                    PlaybuttonView(
                      isGrid: viewGrid.value,
                      showViewToggle: false,
                      controller: controller,
                      itemCount: filteredArtists.length,
                      hasMore: artistQuery.asData?.value.hasMore == true,
                      isLoading: artistQuery.isLoading,
                      onRequestMore: artistQueryNotifier.fetchMore,
                      gridItemBuilder: (context, index) =>
                          ArtistCard(filteredArtists[index]),
                      listItemBuilder: (context, index) =>
                          ArtistCard.tile(filteredArtists[index]),
                    )
                  else if (filteredArtists.isEmpty &&
                      searchText.value.isEmpty &&
                      !artistQuery.isLoading)
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          ZenithIllustration(
                            height: 200 * context.theme.scaling,
                            illustration: UndrawIllustration.followMeDrone,
                          ),
                          Text(
                            context.l10n.not_following_artists,
                            textAlign: TextAlign.center,
                          ).muted().small()
                        ],
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          ZenithIllustration(
                            height: 200 * context.theme.scaling,
                            illustration: UndrawIllustration.taken,
                          ),
                          Text(
                            context.l10n.nothing_found,
                            textAlign: TextAlign.center,
                          ).muted().small()
                        ],
                      ),
                    ),
                  const SliverSafeArea(sliver: SliverGap(10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
