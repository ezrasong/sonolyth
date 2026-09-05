import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/extensions/string.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/stats/common/stats_row.dart';

class StatsPlaylistItem extends StatelessWidget {
  final SonolythSimplePlaylistObject playlist;
  final Widget info;
  const StatsPlaylistItem(
      {super.key, required this.playlist, required this.info});

  @override
  Widget build(BuildContext context) {
    final description = playlist.description.unescapeHtml().cleanHtml();

    return StatsRow(
      imageUrl: (playlist.images).asUrlString(
        placeholder: ImagePlaceholder.collection,
      ),
      title: playlist.name,
      // A description arrives as HTML from the metadata plugin, and an empty
      // one must not leave an empty line 2 behind — `PlaybuttonTile` cleans
      // and drops it the same way.
      subtitle: description.isEmpty ? null : Text(description),
      info: info,
      onPressed: () {
        context.navigateTo(PlaylistRoute(id: playlist.id, playlist: playlist));
      },
    );
  }
}
