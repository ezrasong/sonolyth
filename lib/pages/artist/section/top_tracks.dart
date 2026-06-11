import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/dialogs/select_device_dialog.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/connect/connect.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/connect/connect.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/top_tracks.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

class ArtistPageTopTracks extends HookConsumerWidget {
  final String artistId;
  const ArtistPageTopTracks({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final isLoading = useState(false);

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final topTracksQuery =
        ref.watch(metadataPluginArtistTopTracksProvider(artistId));

    final isPlaylistPlaying = playlist.containsTracks(
      topTracksQuery.asData?.value.items ?? <SonolythTrackObject>[],
    );
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

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

    void playPlaylist(
      List<SonolythFullTrackObject> tracks, {
      SonolythTrackObject? currentTrack,
    }) async {
      isLoading.value = true;

      currentTrack ??= tracks.first;
      try {
        final isRemoteDevice = await showSelectDeviceDialog(context, ref);

        if (isRemoteDevice == null) return;

        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          final remotePlaylist = ref.read(queueProvider);

          final isPlaylistPlaying = remotePlaylist.containsTracks(tracks);

          if (!isPlaylistPlaying) {
            await remotePlayback.load(
              WebSocketLoadEventData.playlist(
                tracks: tracks,
                collection: null,
                initialIndex:
                    tracks.indexWhere((s) => s.id == currentTrack?.id),
              ),
            );
          } else if (isPlaylistPlaying &&
              currentTrack.id != remotePlaylist.activeTrack?.id) {
            final index = playlist.tracks
                .toList()
                .indexWhere((s) => s.id == currentTrack!.id);
            await remotePlayback.jumpTo(index);
          }
        } else {
          if (!isPlaylistPlaying) {
            playlistNotifier.load(
              tracks,
              initialIndex: tracks.indexWhere((s) => s.id == currentTrack?.id),
              autoPlay: true,
            );
          } else if (isPlaylistPlaying &&
              currentTrack.id != playlist.activeTrack?.id) {
            await playlistNotifier.jumpToTrack(currentTrack);
          }
        }
      } finally {
        isLoading.value = false;
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  context.l10n.top_tracks,
                  style: theme.typography.h4,
                ),
              ),
              if (!isPlaylistPlaying)
                IconButton.outline(
                  icon: const Icon(
                    SonolythIcons.queueAdd,
                  ),
                  onPressed: () {
                    playlistNotifier.addTracks(topTracks.toList());
                    showToast(
                      context: context,
                      location: ToastLocation.topRight,
                      builder: (context, overlay) {
                        return SurfaceCard(
                          child: Text(
                            context.l10n.added_to_queue(
                              topTracks.length,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(width: 5),
              IconButton.primary(
                shape: ButtonShape.circle,
                enabled: !isLoading.value,
                icon: isLoading.value
                    ? CircularProgressIndicator(
                        size: 20 * context.theme.scaling,
                        color: theme.colorScheme.primaryForeground,
                      )
                    : Skeleton.keep(
                        child: Icon(
                          isPlaylistPlaying && playing
                              ? SonolythIcons.pause
                              : SonolythIcons.play,
                        ),
                      ),
                // When this collection is already playing, the button toggles
                // pause/resume instead of being disabled.
                onPressed: isPlaylistPlaying
                    ? () => playing ? audioPlayer.pause() : audioPlayer.resume()
                    : () => playPlaylist(topTracks.toList()),
              )
            ],
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
              onTap: () async {
                playPlaylist(
                  topTracks.toList(),
                  currentTrack: track,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
