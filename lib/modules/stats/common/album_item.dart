import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/stats/common/stats_row.dart';

class StatsAlbumItem extends StatelessWidget {
  final SonolythSimpleAlbumObject album;
  final Widget info;
  const StatsAlbumItem({super.key, required this.album, required this.info});

  @override
  Widget build(BuildContext context) {
    // The same join `album_card.dart` makes, and for the same reason: this row
    // used to put `"${albumType.formatted} • "` in a `Row` ahead of an
    // `ArtistLink`, so an album that arrives with no artists — which Spotify's
    // artist endpoints routinely return (§34c) — read as a dangling
    // "Album •". `ItemTrackLine2` is `goneWhenEmpty`; a fact we do not have
    // contributes nothing, not a separator. Lower-case `name` rather than the
    // `formatted` extension, which is what every other album line 2 in the app
    // now shows.
    final description = [
      album.albumType.name,
      album.artists.asString(),
    ].where((part) => part.trim().isNotEmpty).join(" • ");

    return StatsRow(
      imageUrl: (album.images).asUrlString(
        placeholder: ImagePlaceholder.albumArt,
      ),
      title: album.name,
      subtitle: description.isEmpty ? null : Text(description),
      info: info,
      onPressed: () {
        context.navigateTo(AlbumRoute(id: album.id, album: album));
      },
    );
  }
}
