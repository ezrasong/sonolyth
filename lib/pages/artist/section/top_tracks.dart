import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/pages/artist/section/use_artist_playback.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/top_tracks.dart';

/// The artist's top tracks, as the same 96dp `ItemTrack` rows every other list
/// uses.
///
/// The section used to carry its own white filled play disc and an outlined
/// add-to-queue disc beside the heading — the last two stock discs left in the
/// app after §12 took them off cards and §19 off tiles. Play and shuffle live
/// in the Header Overlay above now, so the heading is just a heading.
class ArtistPageTopTracks extends HookConsumerWidget {
  final String artistId;
  const ArtistPageTopTracks({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);

    final playlist = ref.watch(audioPlayerProvider);
    final topTracksQuery =
        ref.watch(metadataPluginArtistTopTracksProvider(artistId));
    final playback = useArtistPlayback(ref, artistId);

    if (topTracksQuery.hasError) {
      return SliverToBoxAdapter(
        child: Center(
          child: ErrorBox(
            error: topTracksQuery.error!,
            onRetry: () => ref.invalidate(
              metadataPluginArtistTopTracksProvider(artistId),
            ),
          ),
        ),
      );
    }

    final topTracks = topTracksQuery.asData?.value.items ??
        List.generate(10, (index) => FakeData.track);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              context.l10n.top_tracks,
              style: zenithSubhead(theme.colorScheme),
            ),
          ),
        ),
        const SliverGap(10),
        SliverList.builder(
          itemCount: topTracks.length,
          itemBuilder: (context, index) {
            final track = topTracks.elementAt(index);
            return TrackTile(
              index: index,
              playlist: playlist,
              track: track,
              onTap: () => playback.onPlayTrack(track),
            );
          },
        ),
      ],
    );
  }
}
