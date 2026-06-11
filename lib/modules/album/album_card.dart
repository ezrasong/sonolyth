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
import 'package:sonolyth/provider/metadata_plugin/tracks/album.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

extension FormattedAlbumType on SonolythAlbumType {
  String get formatted => name.replaceFirst(name[0], name[0].toUpperCase());
}

class AlbumCard extends HookConsumerWidget {
  final SonolythSimpleAlbumObject album;
  final bool _isTile;
  const AlbumCard(
    this.album, {
    super.key,
  }) : _isTile = false;

  const AlbumCard.tile(
    this.album, {
    super.key,
  }) : _isTile = true;

  @override
  Widget build(BuildContext context, ref) {
    final playlistNotifier = ref.read(audioPlayerProvider.notifier);
    final historyNotifier = ref.read(playbackHistoryActionsProvider);
    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);

    // Only rebuild this card when *its* collection's playing status flips,
    // not on every track change / play-pause across the whole queue.
    final isPlaylistPlaying = ref.watch(
      audioPlayerProvider.select((s) => s.containsCollection(album.id)),
    );

    final updating = useState(false);

    final fetchInitialTracks = useCallback(() async {
      final result =
          await ref.read(metadataPluginAlbumTracksProvider(album.id).future);
      return result.items;
    }, [album.id, ref]);

    final fetchAllTrack = useCallback(() async {
      await fetchInitialTracks();
      return ref
          .read(metadataPluginAlbumTracksProvider(album.id).notifier)
          .fetchAll();
    }, [album.id, ref, fetchInitialTracks]);

    final imageUrl = useMemoized(
      () => album.images.from200PxTo300PxOrSmallestImage(
        ImagePlaceholder.collection,
      ),
      [album.images],
    );

    final isLoading =
        (isPlaylistPlaying && isFetchingActiveTrack) || updating.value;
    final description = "${album.albumType.name} • ${album.artists.asString()}";

    final onTap = useCallback(() {
      context.navigateTo(AlbumRoute(id: album.id, album: album));
    }, [context, album]);

    final onPlaybuttonPressed = useCallback(() async {
      updating.value = true;
      try {
        if (isPlaylistPlaying) {
          return audioPlayer.isPlaying
              ? audioPlayer.pause()
              : audioPlayer.resume();
        }

        final fetchedTracks = await fetchAllTrack();

        if (fetchedTracks.isEmpty || !context.mounted) return;

        final isRemoteDevice = await showSelectDeviceDialog(context, ref);
        if (isRemoteDevice == null) return;
        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          await remotePlayback.load(
            WebSocketLoadEventData.album(
              tracks: fetchedTracks,
              collection: album,
            ),
          );
        } else {
          await playlistNotifier.load(fetchedTracks, autoPlay: true);
          playlistNotifier.addCollection(album.id);
          historyNotifier.addAlbums([album]);
        }
      } finally {
        updating.value = false;
      }
    }, [
      isPlaylistPlaying,
      audioPlayer,
      fetchAllTrack,
      context,
      ref,
      playlistNotifier,
      album,
      historyNotifier,
      updating
    ]);

    final onAddToQueuePressed = useCallback(() async {
      if (isPlaylistPlaying) {
        return;
      }

      // Queue the first page immediately so the card doesn't sit in a loading
      // state while the album is fetched page by page; the rest streams in
      // behind the toast.
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
        playlistNotifier.addCollection(album.id);
        historyNotifier.addAlbums([album]);
      } finally {
        updating.value = false;
      }

      final addedIds = initialTracks.map((e) => e.id).toList();
      var undone = false;
      if (context.mounted) {
        showToast(
          context: context,
          builder: (context, overlay) {
            return SurfaceCard(
              child: Basic(
                content: Text(
                  context.l10n.added_to_queue(initialTracks.length),
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

      final allTracks = await fetchAllTrack();
      if (undone) return;
      final rest = allTracks.skip(initialTracks.length).toList();
      if (rest.isEmpty) return;
      addedIds.addAll(rest.map((e) => e.id));
      await playlistNotifier.addTracks(rest);
    }, [
      isPlaylistPlaying,
      fetchInitialTracks,
      fetchAllTrack,
      ref,
      playlistNotifier,
      album.id,
      historyNotifier,
      album,
      context,
      updating
    ]);

    if (_isTile) {
      return PlaybuttonTile(
        imageUrl: imageUrl,
        isPlaying: isPlaylistPlaying,
        isLoading: isLoading,
        title: album.name,
        description: description,
        onTap: onTap,
        onPlaybuttonPressed: onPlaybuttonPressed,
        onAddToQueuePressed: onAddToQueuePressed,
      );
    }

    return PlaybuttonCard(
      imageUrl: imageUrl,
      isPlaying: isPlaylistPlaying,
      isLoading: isLoading,
      title: album.name,
      description: description,
      onTap: onTap,
      onPlaybuttonPressed: onPlaybuttonPressed,
      onAddToQueuePressed: onAddToQueuePressed,
    );
  }
}
