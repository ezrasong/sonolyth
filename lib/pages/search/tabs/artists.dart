import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_view.dart';
import 'package:sonolyth/modules/artist/artist_card.dart';
import 'package:sonolyth/modules/search/loading.dart';
import 'package:sonolyth/pages/search/search.dart';
import 'package:sonolyth/provider/metadata_plugin/search/artists.dart';

class SearchPageArtistsTab extends HookConsumerWidget {
  const SearchPageArtistsTab({super.key, this.isGrid});

  /// View mode from the search header's `header_menu`, as on Albums and
  /// Playlists. The Artists chip had no menu at all until §34, because
  /// `ArtistCard` had no list variant to offer (§28d).
  final bool? isGrid;

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();

    final searchTerm = ref.watch(searchTermStateProvider);
    final searchArtistsSnapshot =
        ref.watch(metadataPluginSearchArtistsProvider(searchTerm));
    final searchArtistsNotifier =
        ref.read(metadataPluginSearchArtistsProvider(searchTerm).notifier);
    final searchArtists =
        searchArtistsSnapshot.asData?.value.items ?? [FakeData.artist];

    if (searchArtistsSnapshot.hasError) {
      return Center(
        child: ErrorBox(
          error: searchArtistsSnapshot.error!,
          onRetry: () {
            ref.invalidate(metadataPluginSearchArtistsProvider(searchTerm));
          },
        ),
      );
    }

    return SearchPlaceholder(
      snapshot: searchArtistsSnapshot,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          slivers: [
            PlaybuttonView(
              isGrid: isGrid,
              showViewToggle: false,
              controller: controller,
              itemCount: searchArtists.length,
              hasMore: searchArtistsSnapshot.asData?.value.hasMore == true,
              isLoading: searchArtistsSnapshot.isLoading,
              onRequestMore: searchArtistsNotifier.fetchMore,
              gridItemBuilder: (context, index) =>
                  ArtistCard(searchArtists.elementAt(index)),
              listItemBuilder: (context, index) =>
                  ArtistCard.tile(searchArtists.elementAt(index)),
            ),
          ],
        ),
      ),
    );
  }
}
