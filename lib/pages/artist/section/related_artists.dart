import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/modules/artist/artist_card.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/related.dart';

/// "Fans also like".
///
/// The heading lives here rather than on the page so the whole section can
/// disappear together: Spotify's `related` call fails outright on this account
/// (`PluginEndpointException: plugin call 'related' failed`), and the section
/// used to sit under its heading showing four shimmering placeholder cards
/// forever. Nothing to show means nothing on screen — not a permanent
/// pretend-loading state.
class ArtistPageRelatedArtists extends ConsumerWidget {
  final String artistId;
  const ArtistPageRelatedArtists({
    super.key,
    required this.artistId,
  });

  @override
  Widget build(BuildContext context, ref) {
    final relatedArtists =
        ref.watch(metadataPluginArtistRelatedArtistsProvider(artistId));

    final artists = relatedArtists.asData?.value.items;
    // An error, or a page that came back empty: the section is not there.
    if (relatedArtists.hasError || (artists != null && artists.isEmpty)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final heading = SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverToBoxAdapter(
        child: Text(
          context.l10n.fans_also_like,
          style: zenithSubhead(context.theme.colorScheme),
        ),
      ),
    );

    // The same cell geometry every other grid in the app uses — 150dp wide,
    // 225 tall, no delegate spacing because each card carries
    // `ItemTrackAAImage_scene_grid`'s own 8dp margins. It used to be a
    // 200 x 250 delegate around a hard-coded 180dp card, from when
    // `ArtistCard` was a bordered shadcn card with a 130dp avatar (§34).
    final scale = context.theme.scaling;
    final grid = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 150 * scale,
      mainAxisExtent: 225 * scale,
      crossAxisSpacing: 0,
      mainAxisSpacing: 0,
    );

    return SliverMainAxisGroup(
      slivers: [
        heading,
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          sliver: artists == null
              ? SliverGrid.builder(
                  itemCount: 4,
                  gridDelegate: grid,
                  itemBuilder: (context, index) => Skeletonizer(
                    enabled: true,
                    child: ArtistCard(FakeData.artist),
                  ),
                )
              : SliverGrid.builder(
                  itemCount: artists.length,
                  gridDelegate: grid,
                  itemBuilder: (context, index) =>
                      ArtistCard(artists.elementAt(index)),
                ),
        ),
      ],
    );
  }
}
