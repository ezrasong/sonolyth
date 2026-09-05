import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Image;
import 'package:sonolyth/collections/assets.gen.dart';

import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_view.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/playlist/playlist_create_dialog.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/components/fallbacks/anonymous_fallback.dart';
import 'package:sonolyth/modules/playlist/playlist_card.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/library/playlists.dart';
import 'package:sonolyth/provider/metadata_plugin/core/user.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';

@RoutePage()
class UserPlaylistsPage extends HookConsumerWidget {
  static const name = 'user_playlists';
  const UserPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchText = useState('');
    // Poweramp keeps the view mode in the list header's menu; null = decide
    // from the width, as `PlaybuttonView` always did.
    final viewGrid = useState<bool?>(null);

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);

    final me = ref.watch(metadataPluginUserProvider);
    final playlistsQuery = ref.watch(metadataPluginSavedPlaylistsProvider);
    final playlistsQueryNotifier =
        ref.watch(metadataPluginSavedPlaylistsProvider.notifier);

    // The Liked Tracks row must not come and go with the profile fetch. It
    // used to exist only while `metadataPluginUserProvider` held data, and
    // the list below was memoized on the playlists query alone — so when the
    // profile resolved after the playlists (a cold start, a 401 retry) the
    // row never appeared, and when the profile reloaded it vanished, shifting
    // every playlist up under a finger already on its way down: tapping
    // "Liked Tracks" opened the playlist that had taken its place. Every
    // authenticated user has this collection, so build it from the loaded
    // profile, else the cached one, else a blank owner.
    final owner = me.asData?.value ?? _cachedOrBlankUser();
    final likedTracksPlaylist = useMemoized(
      () => SonolythSimplePlaylistObject(
        id: "user-liked-tracks",
        name: context.l10n.liked_tracks,
        description: context.l10n.liked_tracks_description,
        externalUri: "",
        owner: owner,
        images: [
          SonolythImageObject(
            url: Assets.images.likedTracks.path,
            width: 300,
            height: 300,
          )
        ],
      ),
      [context.l10n, owner],
    );

    final playlists = useMemoized(
      () {
        if (searchText.value.isEmpty) {
          return [
            likedTracksPlaylist,
            ...?playlistsQuery.asData?.value.items,
          ];
        }
        return [
          likedTracksPlaylist,
          ...?playlistsQuery.asData?.value.items,
        ]
            .map((e) => (weightedRatio(e.name, searchText.value), e))
            .sorted((a, b) => b.$1.compareTo(a.$1))
            .where((e) => e.$1 > 50)
            .map((e) => e.$2)
            .toList();
      },
      [playlistsQuery, searchText.value, likedTracksPlaylist],
    );

    final controller = useScrollController();

    if (playlistsQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    if (authenticated.asData?.value != true) {
      return const AnonymousFallback();
    }

    if (playlistsQuery.hasError) {
      return ErrorBox(
        error: playlistsQuery.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSavedPlaylistsProvider);
        },
      );
    }

    return material.RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(metadataPluginSavedPlaylistsProvider);
      },
      child: SafeArea(
        bottom: false,
        child: InterScrollbar(
          controller: controller,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              // `merge_item_text_header`: the filter behind the search glyph,
              // "+" for a new playlist, view mode in the header menu.
              SliverToBoxAdapter(
                child: ZenithListToolbar(
                  filterPlaceholder: context.l10n.filter_playlists,
                  onFilterChanged: (value) => searchText.value = value,
                  buttons: [
                    ZenithHeaderButton(
                      tooltip: context.l10n.playlist,
                      icon: SonolythIcons.addFilled,
                      onPressed: () => showDialog(
                        context: context,
                        alignment: Alignment.center,
                        builder: (context) => const ToastLayer(
                          child: PlaylistCreateDialog(),
                        ),
                      ),
                    ),
                  ],
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: PlaybuttonView(
                  isGrid: viewGrid.value,
                  showViewToggle: false,
                  controller: controller,
                  hasMore: playlistsQuery.asData?.value.hasMore == true,
                  isLoading: playlistsQuery.isLoading,
                  onRequestMore: playlistsQueryNotifier.fetchMore,
                  itemCount: playlists.length,
                  gridItemBuilder: (context, index) {
                    return PlaylistCard(playlists[index]);
                  },
                  listItemBuilder: (context, index) {
                    return PlaylistCard.tile(playlists[index]);
                  },
                ),
              ),
              const SliverSafeArea(sliver: SliverGap(10)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The last profile the app saw, or a blank owner when there is none yet.
/// Only the Liked Tracks pseudo-playlist uses it, for its header subtitle.
SonolythUserObject _cachedOrBlankUser() {
  final cached = KVStoreService.cachedUserProfile;
  if (cached != null) {
    try {
      return SonolythUserObject.fromJson(cached);
    } catch (_) {
      // A malformed cache entry is not worth failing the row over.
    }
  }
  return SonolythUserObject(id: "", name: "", externalUri: "");
}
