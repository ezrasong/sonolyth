import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/ui/sheet_aware_pop_scope.dart';

import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/modules/artist/artist_album_list.dart';

import 'package:sonolyth/pages/artist/section/footer.dart';
import 'package:sonolyth/pages/artist/section/header.dart';
import 'package:sonolyth/pages/artist/section/related_artists.dart';
import 'package:sonolyth/pages/artist/section/top_tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/albums.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/artist.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/related.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/top_tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/wikipedia.dart';
import 'package:sonolyth/provider/metadata_plugin/library/artists.dart';

@RoutePage()
class ArtistPage extends HookConsumerWidget {
  static const name = "artist";

  final String artistId;
  const ArtistPage(
    @PathParam("id") this.artistId, {
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();

    final artistQuery = ref.watch(metadataPluginArtistProvider(artistId));

    // Like every collection page (§21e): the header art runs under the status
    // bar and its own "‹ Artists" back decor replaces the title bar. Wide
    // layouts keep a bar for the window controls, without a back button.
    final isWide = MediaQuery.sizeOf(context).mdAndUp;

    return SheetAwarePopScope(
      child: SafeArea(
        top: isWide,
        bottom: false,
        child: Scaffold(
          headers: [
            if (isWide)
              const TitleBar(automaticallyImplyLeading: false, height: 32),
          ],
          child: material.RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(metadataPluginArtistProvider(artistId));
              ref.invalidate(
                metadataPluginArtistRelatedArtistsProvider(artistId),
              );
              ref.invalidate(metadataPluginArtistAlbumsProvider(artistId));
              ref.invalidate(metadataPluginIsSavedArtistProvider(artistId));
              ref.invalidate(metadataPluginArtistTopTracksProvider(artistId));
              if (artistQuery.hasValue) {
                ref.invalidate(
                  artistWikipediaSummaryProvider(artistQuery.asData!.value),
                );
              }
            },
            child: Builder(builder: (context) {
              if (artistQuery.hasError && artistQuery.asData?.value == null) {
                return Center(
                  child: ErrorBox(
                    error: artistQuery.error!,
                    onRetry: () => ref.invalidate(
                      metadataPluginArtistProvider(artistId),
                    ),
                  ),
                );
              }
              return Skeletonizer(
                enabled: artistQuery.isLoading,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: ArtistPageHeader(artistId: artistId),
                    ),
                    const SliverGap(20),
                    ArtistPageTopTracks(artistId: artistId),
                    const SliverGap(20),
                    SliverToBoxAdapter(child: ArtistAlbumList(artistId)),
                    ArtistPageRelatedArtists(artistId: artistId),
                    const SliverGap(20),
                    if (artistQuery.asData?.value != null)
                      SliverToBoxAdapter(
                        child:
                            ArtistPageFooter(artist: artistQuery.asData!.value),
                      ),
                    const SliverSafeArea(sliver: SliverGap(10)),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
