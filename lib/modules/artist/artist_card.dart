import 'package:auto_route/auto_route.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_card.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/utils/primitive_utils.dart';

import 'package:sonolyth/provider/blacklist_provider.dart';

/// An artist cell, on the same two shapes every other grid/list item in the
/// app uses — `PlaybuttonCard` and `PlaybuttonTile`.
///
/// This was the **last stock-Spotube grid cell in the app**: a bordered
/// shadcn `Button.card` holding a circular 130dp `Avatar`, a centred bold
/// name and two badges ("ARTIST", and "BLACKLISTED" in shadcn's red). §12
/// took the border and the per-item buttons off the album/playlist cards and
/// §33b took the "Artist" badge and the "Follow" pill off the artist *page*,
/// but the artist card itself was never converted, so Home, Library →
/// Artists, Search → Artists and "Fans also like" all still showed it.
///
/// Three decisions, all so the cell reads as the same system as its
/// neighbours:
///
/// * **Rectangular art, radius 12.** The circle is a Spotify idiom.
///   Poweramp's category art is square (`corners_aa_other_grid_zoomed` =
///   `0.0dip` — artists live under "other"), and the app rounds every art to
///   [ZenithArt.radius] because the skin's screenshots do (§27). Nothing else
///   in the app is a circle, and the artist page's own header photo is a
///   rectangle since §33b.
/// * **No badges.** Poweramp's grid cell has no type badge, and line 2 is
///   where a fact about the item goes. So the genres carry it (the same
///   choice `header.dart` made for the artist page), the follower count backs
///   them up when an artist arrives without genres, and the blacklisted state
///   — the one thing worth interrupting for — takes the line when set.
/// * **No transport.** An artist is not a collection: there is no queue to
///   load without first fetching its top tracks, which is a request per cell.
///   The card's hover overlay is suppressed by passing neither callback (see
///   `PlaybuttonCard`), exactly as Poweramp's artist cell carries no buttons.
class ArtistCard extends ConsumerWidget {
  final SonolythFullArtistObject artist;
  final bool _isTile;

  const ArtistCard(
    this.artist, {
    super.key,
  }) : _isTile = false;

  const ArtistCard.tile(
    this.artist, {
    super.key,
  }) : _isTile = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlackListed = ref.watch(
          blacklistProvider.select(
            (blacklist) => blacklist.asData?.value.any(
              (element) => element.elementId == artist.id,
            ),
          ),
        ) ==
        true;

    final imageUrl = artist.images.asUrlString(
      placeholder: ImagePlaceholder.artist,
    );

    final genres = (artist.genres ?? const <String>[])
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .join(", ");

    // `ItemTrackLine2` is `goneWhenEmpty`, so an artist we know nothing about
    // gets a shorter cell rather than a blank line.
    final description = isBlackListed
        ? context.l10n.blacklisted
        : genres.isNotEmpty
            ? genres
            : artist.followers != null
                ? context.l10n.followers(
                    PrimitiveUtils.toReadableNumber(
                      artist.followers!.toDouble(),
                    ),
                  )
                : null;

    void onTap() {
      context.navigateTo(ArtistRoute(artistId: artist.id));
    }

    if (_isTile) {
      return PlaybuttonTile(
        imageUrl: imageUrl,
        isPlaying: false,
        isLoading: false,
        title: artist.name,
        description: description,
        onTap: onTap,
      );
    }

    return PlaybuttonCard(
      imageUrl: imageUrl,
      isPlaying: false,
      isLoading: false,
      title: artist.name,
      description: description,
      onTap: onTap,
    );
  }
}
