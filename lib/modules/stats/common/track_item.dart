import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/components/links/artist_link.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/stats/common/stats_row.dart';

class StatsTrackItem extends StatelessWidget {
  final SonolythTrackObject track;
  final Widget info;
  const StatsTrackItem({
    super.key,
    required this.track,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return StatsRow(
      imageUrl: (track.album.images).asUrlString(
        placeholder: ImagePlaceholder.albumArt,
      ),
      title: track.name,
      subtitle: ArtistLink(
        artists: track.artists,
        mainAxisAlignment: WrapAlignment.start,
        onOverflowArtistClick: () {
          context.navigateTo(TrackRoute(trackId: track.id));
        },
      ),
      info: info,
      onPressed: () {
        context.navigateTo(TrackRoute(trackId: track.id));
      },
    );
  }
}
