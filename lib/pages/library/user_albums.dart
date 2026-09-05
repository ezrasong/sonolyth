import 'package:flutter/material.dart' as material;
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Image;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:collection/collection.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_view.dart';
import 'package:sonolyth/modules/album/album_card.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/components/fallbacks/anonymous_fallback.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/library/albums.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';
import 'package:sonolyth/components/fallbacks/zenith_illustration.dart';

@RoutePage()
class UserAlbumsPage extends HookConsumerWidget {
  static const name = 'user_albums';
  const UserAlbumsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    final albumsQuery = ref.watch(metadataPluginSavedAlbumsProvider);
    final albumsQueryNotifier =
        ref.watch(metadataPluginSavedAlbumsProvider.notifier);

    final controller = useScrollController();

    final searchText = useState('');

    // Poweramp keeps the view mode in the list header's menu; null = decide

    // from the width, as `PlaybuttonView` always did.

    final viewGrid = useState<bool?>(null);

    final albums = useMemoized(() {
      if (searchText.value.isEmpty) {
        return albumsQuery.asData?.value.items ?? [];
      }
      return albumsQuery.asData?.value.items
              .map((e) => (
                    weightedRatio(e.name, searchText.value),
                    e,
                  ))
              .sorted((a, b) => b.$1.compareTo(a.$1))
              .where((e) => e.$1 > 50)
              .map((e) => e.$2)
              .toList() ??
          [];
    }, [albumsQuery.asData?.value, searchText.value]);

    if (albumsQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    if (authenticated.asData?.value != true) {
      return const AnonymousFallback();
    }

    if (albumsQuery.hasError) {
      return ErrorBox(
        error: albumsQuery.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSavedAlbumsProvider);
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        child: material.RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(metadataPluginSavedAlbumsProvider);
          },
          child: InterScrollbar(
            controller: controller,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                // `merge_item_text_header`: the filter behind the search
                // glyph, view mode in the header menu.
                SliverToBoxAdapter(
                  child: ZenithListToolbar(
                    filterPlaceholder: context.l10n.filter_albums,
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
                    onMenuSelected: (value) => viewGrid.value = value == "grid",
                  ),
                ),
                if (albums.isEmpty &&
                    !albumsQuery.isLoading &&
                    searchText.value.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          ZenithIllustration(
                            height: 200 * context.theme.scaling,
                            illustration: UndrawIllustration.followMeDrone,
                          ),
                          Text(
                            context.l10n.no_favorite_albums_yet,
                            textAlign: TextAlign.center,
                          ).muted().small()
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: PlaybuttonView(
                      isGrid: viewGrid.value,
                      showViewToggle: false,
                      controller: controller,
                      itemCount: albums.length,
                      hasMore: albumsQuery.asData?.value.hasMore == true,
                      isLoading: albumsQuery.isLoading,
                      onRequestMore: albumsQueryNotifier.fetchMore,
                      gridItemBuilder: (context, index) => AlbumCard(
                        albums[index],
                      ),
                      listItemBuilder: (context, index) =>
                          AlbumCard.tile(albums[index]),
                    ),
                  ),
                const SliverSafeArea(sliver: SliverGap(10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
