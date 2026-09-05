import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/stats/common/stats_row.dart';

class StatsArtistItem extends StatelessWidget {
  final SonolythSimpleArtistObject artist;
  final Widget info;
  const StatsArtistItem({
    super.key,
    required this.artist,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return StatsRow(
      imageUrl: (artist.images).asUrlString(
        placeholder: ImagePlaceholder.artist,
      ),
      title: artist.name,
      info: info,
      onPressed: () {
        context.navigateTo(ArtistRoute(artistId: artist.id));
      },
    );
  }
}
