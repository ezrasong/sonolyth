import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/modules/search/loading.dart';
import 'package:sonolyth/pages/search/search.dart';
import 'package:sonolyth/modules/search/sections/albums.dart';
import 'package:sonolyth/modules/search/sections/artists.dart';
import 'package:sonolyth/modules/search/sections/playlists.dart';
import 'package:sonolyth/modules/search/sections/tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/search/all.dart';

class SearchPageAllTab extends HookConsumerWidget {
  const SearchPageAllTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();
    final searchTerm = ref.watch(searchTermStateProvider);
    final searchSnapshot =
        ref.watch(metadataPluginSearchAllProvider(searchTerm));

    if (searchSnapshot.hasError) {
      return Center(
        child: ErrorBox(
          error: searchSnapshot.error!,
          onRetry: () {
            ref.invalidate(metadataPluginSearchAllProvider(searchTerm));
          },
        ),
      );
    }

    return SearchPlaceholder(
      snapshot: searchSnapshot,
      child: InterScrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchTracksSection(),
                  SearchPlaylistsSection(),
                  Gap(20),
                  SearchArtistsSection(),
                  Gap(20),
                  SearchAlbumsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
