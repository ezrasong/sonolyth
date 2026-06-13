import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/components/dialogs/select_device_dialog.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_card.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/connect/connect.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/querying_track_info.dart';
import 'package:sonolyth/provider/connect/connect.dart';
import 'package:sonolyth/provider/history/history.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/metadata_plugin/library/tracks.dart';
import 'package:sonolyth/provider/metadata_plugin/tracks/playlist.dart';
import 'package:sonolyth/provider/metadata_plugin/core/user.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

class PlaylistCard extends HookConsumerWidget {
  final SonolythSimplePlaylistObject playlist;
  final bool _isTile;

  const PlaylistCard(
    this.playlist, {
    super.key,
  }) : _isTile = false;

  const PlaylistCard.tile(
    this.playlist, {
    super.key,
  }) : _isTile = true;

  @override
  Widget build(BuildContext context, ref) {
    final playlistNotifier = ref.read(audioPlayerProvider.notifier);
    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final historyNotifier = ref.read(playbackHistoryActionsProvider);

    // Only rebuild this card when *its* collection's playing status flips,
    // not on every track change across the whole queue.
    final isPlaylistPlaying = ref.watch(
      audioPlayerProvider.select((s) => s.containsCollection(playlist.id)),
    );
    // "Loaded as the queue" isn't "audibly playing" — the button must show
    // play (not pause) while this collection's queue sits paused.
    final isAudioPlaying = ref.watch(
      audioPlayerProvider.select((s) => s.playing && s.tracks.isNotEmpty),
    );

    final updating = useState(false);
    final me = ref.watch(metadataPluginUserProvider);

    final fetchInitialTracks = useCallback(() async {
      if (playlist.id == 'user-liked-tracks') {
        final tracks = await ref.read(metadataPluginSavedTracksProvider.future);
        return tracks.items;
      }

      final result = await ref
          .read(metadataPluginPlaylistTracksProvider(playlist.id).future);

      return result.items;
    }, [playlist.id, ref]);

    final fetchAllTracks = useCallback(() async {
      await fetchInitialTracks();

      if (playlist.id == 'user-liked-tracks') {
        return ref.read(metadataPluginSavedTracksProvider.notifier).fetchAll();
      }

      return ref
          .read(metadataPluginPlaylistTracksProvider(playlist.id).notifier)
          .fetchAll();
    }, [playlist.id, ref, fetchInitialTracks]);

    final onTap = useCallback(() {
      context.navigateTo(PlaylistRoute(id: playlist.id, playlist: playlist));
    }, [context, playlist]);

    final onPlaybuttonPressed = useCallback(() async {
      try {
        updating.value = true;
        if (isPlaylistPlaying && audioPlayer.isPlaying) {
          return audioPlayer.pause();
        } else if (isPlaylistPlaying && !audioPlayer.isPlaying) {
          return audioPlayer.resume();
        }

        final fetchedInitialTracks = await fetchInitialTracks();

        if (fetchedInitialTracks.isEmpty || !context.mounted) return;

        final isRemoteDevice = await showSelectDeviceDialog(context, ref);
        if (isRemoteDevice == null) return;
        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          final allTracks = await fetchAllTracks();
          await remotePlayback.load(
            WebSocketLoadEventData.playlist(
              tracks: allTracks,
              collection: playlist,
            ),
          );
        } else {
          await playlistNotifier.load(fetchedInitialTracks, autoPlay: true);
          playlistNotifier.addCollection(playlist.id);
          historyNotifier.addPlaylists([playlist]);

          final allTracks = await fetchAllTracks();

          await playlistNotifier.addTracks(
              allTracks.skip(fetchedInitialTracks.length).toList());
        }
      } finally {
        if (context.mounted) {
          updating.value = false;
        }
      }
    }, [
      isPlaylistPlaying,
      fetchInitialTracks,
      context,
      showSelectDeviceDialog,
      ref,
      connectProvider,
      fetchAllTracks,
      playlistNotifier,
      playlist.id,
      historyNotifier,
      playlist,
      updating
    ]);

    final onAddToQueuePressed = useCallback(() async {
      if (isPlaylistPlaying) return;

      // Queue the first page immediately so the card doesn't sit in a loading
      // state while a large playlist is fetched page by page; the rest streams
      // in behind the toast.
      var initialTracks = <SonolythTrackObject>[];
      updating.value = true;
      try {
        initialTracks = await fetchInitialTracks();
        if (initialTracks.isEmpty) return;

        if (ref.read(audioPlayerProvider).tracks.isEmpty) {
          // Nothing to queue behind — start playing right away instead of
          // appending tracks to a stopped player.
          await playlistNotifier.load(initialTracks, autoPlay: true);
        } else {
          await playlistNotifier.addTracks(initialTracks);
        }
        playlistNotifier.addCollection(playlist.id);
        historyNotifier.addPlaylists([playlist]);
      } finally {
        updating.value = false;
      }

      final addedIds = initialTracks.map((e) => e.id).toList();
      var undone = false;
      if (context.mounted) {
        showToast(
          context: context,
          // Bottom toasts hide behind the mini player on phones.
          location: ToastLocation.topRight,
          builder: (context, overlay) {
            return SurfaceCard(
              child: Basic(
                content: Text(
                  context.l10n.added_num_tracks_to_queue(initialTracks.length),
                ),
                trailing: Button.outline(
                  child: Text(context.l10n.undo),
                  onPressed: () {
                    undone = true;
                    playlistNotifier.removeTracks(List.of(addedIds));
                  },
                ),
              ),
            );
          },
        );
      }

      final allTracks = await fetchAllTracks();
      if (undone) return;
      final rest = allTracks.skip(initialTracks.length).toList();
      if (rest.isEmpty) return;
      addedIds.addAll(rest.map((e) => e.id));
      await playlistNotifier.addTracks(rest);
    }, [
      isPlaylistPlaying,
      fetchInitialTracks,
      fetchAllTracks,
      ref,
      playlistNotifier,
      playlist.id,
      historyNotifier,
      playlist,
      context,
      updating
    ]);

    final imageUrl = useMemoized(
      () => playlist.images.from200PxTo300PxOrSmallestImage(
        ImagePlaceholder.collection,
      ),
      [playlist.images],
    );

    final isLoading =
        (isPlaylistPlaying && isFetchingActiveTrack) || updating.value;
    final isOwner = playlist.owner.id == me.asData?.value?.id &&
        me.asData?.value?.id != null;

    if (_isTile) {
      return PlaybuttonTile(
        title: playlist.name,
        description: playlist.description,
        image: null,
        imageUrl: imageUrl,
        isPlaying: isPlaylistPlaying && isAudioPlaying,
        isLoading: isLoading,
        isOwner: isOwner,
        onTap: onTap,
        onPlaybuttonPressed: onPlaybuttonPressed,
        onAddToQueuePressed: onAddToQueuePressed,
      );
    }

    return PlaybuttonCard(
      title: playlist.name,
      description: playlist.description,
      image: null,
      imageUrl: imageUrl,
      isPlaying: isPlaylistPlaying && isAudioPlaying,
      isLoading: isLoading,
      isOwner: isOwner,
      onTap: onTap,
      onPlaybuttonPressed: onPlaybuttonPressed,
      onAddToQueuePressed: onAddToQueuePressed,
    );
  }
}
