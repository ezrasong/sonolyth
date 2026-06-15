import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/links/artist_link.dart';
import 'package:sonolyth/components/links/hyper_link.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/duration.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/sourced_track/qobuz_audio_source.dart';

class TrackDetailsDialog extends HookConsumerWidget {
  final SonolythFullTrackObject track;
  const TrackDetailsDialog({
    super.key,
    required this.track,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    // watch (not read): the card must update when the track finishes resolving
    // or its stream URL is refreshed, so the Source/URL rows reflect what's
    // actually playing instead of a stale/empty snapshot from when it opened.
    final sourcedTrack = ref.watch(sourcedTrackProvider(track));

    final detailsMap = {
      context.l10n.title: track.name,
      context.l10n.artist: ArtistLink(
        artists: track.artists,
        mainAxisAlignment: WrapAlignment.start,
        textStyle: TextStyle(color: theme.colorScheme.primary),
        hideOverflowArtist: false,
      ),
      // context.l10n.album: LinkText(
      //   track.album!.name!,
      //   AlbumRoute(album: track.album!, id: track.album!.id!),
      //   overflow: TextOverflow.ellipsis,
      //   style: const TextStyle(color: Colors.blue),
      // ),
      context.l10n.duration: sourcedTrack.asData != null
          ? sourcedTrack.asData!.value.info.duration.toHumanReadableString()
          : Duration(milliseconds: track.durationMs).toHumanReadableString(),
      if (track.album.releaseDate != null)
        context.l10n.released: track.album.releaseDate,
    };

    final sourceInfo = sourcedTrack.asData?.value.info;
    final streamUrl = sourcedTrack.asData?.value.url;
    final isQobuz =
        sourceInfo != null && QobuzAudioSource.ownsMatch(sourceInfo);

    final ytTracksDetailsMap = sourceInfo == null
        ? {}
        : {
            // Show the REAL source. A Qobuz-served track plays lossless FLAC
            // even though SourcedTrack.source carries the plugin slug for cache
            // namespacing — so derive the label from the match, not the slug.
            "Source": Text(
              isQobuz ? "Qobuz · FLAC Lossless" : "YouTube",
              style: theme.typography.normal,
            ),
            // Only YouTube/plugin tracks are actually on Piped; a Qobuz track
            // links to its Qobuz page instead of a bogus piped.video URL built
            // from a numeric Qobuz id.
            if (isQobuz)
              "Qobuz": Hyperlink(
                sourceInfo.externalUri,
                sourceInfo.externalUri,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              context.l10n.youtube: Hyperlink(
                "https://piped.video/watch?v=${sourceInfo.id}",
                "https://piped.video/watch?v=${sourceInfo.id}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            context.l10n.channel: Text(sourceInfo.artists.join(", ")),
            if (streamUrl != null)
              context.l10n.streamUrl: Hyperlink(
                streamUrl,
                streamUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          };

    return AlertDialog(
      surfaceBlur: 0,
      surfaceOpacity: 1,
      title: Row(
        spacing: 8,
        children: [
          const Icon(SonolythIcons.info),
          Text(
            context.l10n.details,
            style: theme.typography.h4,
          ),
        ],
      ),
      content: SizedBox(
        width: mediaQuery.mdAndUp ? double.infinity : 700,
        child: Table(
          columnWidths: const {
            0: FixedTableSize(95),
            1: FixedTableSize(10),
            2: FlexTableSize(),
          },
          theme: const TableTheme(
            backgroundColor: Colors.transparent,
            cellTheme: TableCellTheme(
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
          rowHeights: const {0: FixedTableSize(40)},
          rows: [
            for (final entry in detailsMap.entries)
              TableRow(
                cells: [
                  TableCell(
                    child: Text(
                      entry.key,
                      style: theme.typography.bold,
                    ),
                  ),
                  const TableCell(
                    child: Text(":"),
                  ),
                  TableCell(
                    child: entry.value is Widget
                        ? entry.value as Widget
                        : (entry.value is String)
                            ? Text(
                                entry.value as String,
                                style: theme.typography.normal,
                              )
                            : const Text(""),
                  ),
                ],
              ),
            for (final entry in ytTracksDetailsMap.entries)
              TableRow(
                cells: [
                  TableCell(
                    child: Text(
                      entry.key,
                      style: theme.typography.bold,
                    ),
                  ),
                  const TableCell(
                    child: Text(":"),
                  ),
                  TableCell(
                    child: entry.value is Widget
                        ? entry.value as Widget
                        : Text(
                            entry.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.normal,
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
