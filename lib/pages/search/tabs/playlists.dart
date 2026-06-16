import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_view.dart';
import 'package:sonolyth/modules/playlist/playlist_card.dart';
import 'package:sonolyth/modules/search/loading.dart';
import 'package:sonolyth/pages/search/search.dart';
import 'package:sonolyth/provider/metadata_plugin/search/playlists.dart';

class SearchPagePlaylistsTab extends HookConsumerWidget {
  const SearchPagePlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();

    final searchTerm = ref.watch(searchTermStateProvider);
    final searchPlaylistsSnapshot =
        ref.watch(metadataPluginSearchPlaylistsProvider(searchTerm));
    final searchPlaylistsNotifier =
        ref.read(metadataPluginSearchPlaylistsProvider(searchTerm).notifier);
    final searchPlaylists = searchPlaylistsSnapshot.asData?.value.items ??
        [FakeData.playlistSimple];

    if (searchPlaylistsSnapshot.hasError) {
      return Center(
        child: ErrorBox(
          error: searchPlaylistsSnapshot.error!,
          onRetry: () {
            ref.invalidate(metadataPluginSearchPlaylistsProvider(searchTerm));
          },
        ),
      );
    }

    return SearchPlaceholder(
      snapshot: searchPlaylistsSnapshot,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          slivers: [
            PlaybuttonView(
              controller: controller,
              itemCount: searchPlaylists.length,
              hasMore: searchPlaylistsSnapshot.asData?.value.hasMore == true,
              isLoading: searchPlaylistsSnapshot.isLoading,
              onRequestMore: searchPlaylistsNotifier.fetchMore,
              gridItemBuilder: (context, index) =>
                  PlaylistCard(searchPlaylists[index]),
              listItemBuilder: (context, index) =>
                  PlaylistCard.tile(searchPlaylists[index]),
            ),
          ],
        ),
      ),
    );
  }
}
