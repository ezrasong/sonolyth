import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/components/dialogs/prompt_dialog.dart';
import 'package:sonolyth/components/dialogs/select_device_dialog.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/connect/connect.dart';
import 'package:sonolyth/modules/search/loading.dart';
import 'package:sonolyth/pages/search/search.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/connect/connect.dart';
import 'package:sonolyth/provider/metadata_plugin/search/tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class SearchPageTracksTab extends HookConsumerWidget {
  const SearchPageTracksTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final searchTracksSnapshot =
        ref.watch(metadataPluginSearchTracksProvider(searchTerm));
    final searchTracksNotifier =
        ref.read(metadataPluginSearchTracksProvider(searchTerm).notifier);
    final searchTracks =
        searchTracksSnapshot.asData?.value.items ?? [FakeData.track];

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);

    if (searchTracksSnapshot.hasError) {
      return Center(
        child: ErrorBox(
          error: searchTracksSnapshot.error!,
          onRetry: () {
            ref.invalidate(metadataPluginSearchTracksProvider(searchTerm));
          },
        ),
      );
    }

    return SearchPlaceholder(
      snapshot: searchTracksSnapshot,
      child: InfiniteList(
        itemCount: searchTracksSnapshot.asData?.value.items.length ?? 0,
        hasReachedMax: searchTracksSnapshot.asData?.value.hasMore != true,
        isLoading: searchTracksSnapshot.isLoading &&
            !searchTracksSnapshot.isLoadingNextPage,
        loadingBuilder: (context) {
          return Skeletonizer(
            enabled: true,
            child: TrackTile(track: FakeData.track, playlist: playlist),
          );
        },
        onFetchData: () {
          searchTracksNotifier.fetchMore();
        },
        itemBuilder: (context, index) {
          final track = searchTracks[index];

          return TrackTile(
            track: track,
            playlist: playlist,
            index: index,
            onTap: () async {
              final isRemoteDevice = await showSelectDeviceDialog(context, ref);

              if (isRemoteDevice == null) return;

              if (isRemoteDevice) {
                final remotePlayback = ref.read(connectProvider.notifier);
                final remotePlaylist = ref.read(queueProvider);

                final isTrackPlaying =
                    remotePlaylist.activeTrack?.id == track.id;

                if (!isTrackPlaying && context.mounted) {
                  final shouldPlay = (playlist.tracks.length) > 20
                      ? await showPromptDialog(
                          context: context,
                          title: context.l10n.playing_track(
                            track.name,
                          ),
                          message: context.l10n.queue_clear_alert(
                            playlist.tracks.length,
                          ),
                        )
                      : true;

                  if (shouldPlay) {
                    await remotePlayback.load(
                      WebSocketLoadEventData.playlist(
                        tracks: [track],
                      ),
                    );
                  }
                }
              } else {
                final isTrackPlaying = playlist.activeTrack?.id == track.id;
                if (!isTrackPlaying && context.mounted) {
                  final shouldPlay = (playlist.tracks.length) > 20
                      ? await showPromptDialog(
                          context: context,
                          title: context.l10n.playing_track(
                            track.name,
                          ),
                          message: context.l10n.queue_clear_alert(
                            playlist.tracks.length,
                          ),
                        )
                      : true;

                  if (shouldPlay) {
                    await playlistNotifier.load(
                      [track],
                      autoPlay: true,
                    );
                  }
                }
              }
            },
          );
        },
      ),
    );
  }
}
