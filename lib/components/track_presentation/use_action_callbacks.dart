import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/components/dialogs/select_device_dialog.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';

import 'package:sonolyth/models/connect/connect.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/connect/connect.dart';
import 'package:sonolyth/provider/history/history.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

typedef UseActionCallbacks = ({
  bool isActive,
  bool isLoading,
  bool isPlayLoading,
  bool isShuffleLoading,
  Future<void> Function() onShuffle,
  Future<void> Function() onPlay,
});

UseActionCallbacks useActionCallbacks(WidgetRef ref) {
  // Tracked per action so only the pressed button shows a spinner instead of
  // every button swapping its icon at once.
  final isPlayLoading = useState(false);
  final isShuffleLoading = useState(false);
  final context = useContext();
  final options = TrackPresentationOptions.of(context);
  final playlist = ref.watch(audioPlayerProvider);
  final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
  final historyNotifier = ref.watch(playbackHistoryActionsProvider);

  final isActive = useMemoized(
    () => playlist.collections.contains(options.collectionId),
    [playlist.collections, options.collectionId],
  );

  // Warm up the first track's audio source as soon as the page has tracks so
  // pressing play doesn't wait on the YouTube search + manifest round trip.
  final firstTrack = options.tracks.firstOrNull;
  useEffect(() {
    if (firstTrack is SonolythFullTrackObject) {
      Future(() async {
        try {
          await ref.read(sourcedTrackProvider(firstTrack).future);
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      });
    }
    return null;
  }, [firstTrack?.id]);

  final onShuffle = useCallback(() async {
    try {
      isShuffleLoading.value = true;

      final initialTracks = options.tracks;
      if (!context.mounted) return;

      final isRemoteDevice = await showSelectDeviceDialog(context, ref);
      if (isRemoteDevice == null) return;
      if (isRemoteDevice) {
        final allTracks = await options.pagination.onFetchAll();
        final remotePlayback = ref.read(connectProvider.notifier);
        await remotePlayback.load(
          options.collection is SonolythSimpleAlbumObject
              ? WebSocketLoadEventData.album(
                  tracks: allTracks,
                  collection: options.collection as SonolythSimpleAlbumObject,
                  initialIndex: Random().nextInt(allTracks.length))
              : WebSocketLoadEventData.playlist(
                  tracks: allTracks,
                  collection: options.collection as SonolythSimplePlaylistObject,
                  initialIndex: Random().nextInt(allTracks.length),
                ),
        );
        await remotePlayback.setShuffle(true);
      } else {
        if (initialTracks.isEmpty) return;
        // Shuffle the track list in Dart instead of using mpv's shuffle:
        // playback starts instantly on a deterministic index, so the player
        // modal always shows the track that's actually playing (mpv's
        // playlist shuffle reorders out from under the reported index).
        // Shuffle the already-loaded first page and start on its head: that's
        // a random track (not always the collection's first song) while still
        // starting immediately without waiting on the full fetchAll. load()
        // sources the start track itself, so we don't depend on the page's
        // first-track prewarm landing on the chosen one.
        final shuffledTracks = initialTracks.toList()..shuffle();
        await playlistNotifier.load(
          shuffledTracks,
          autoPlay: true,
        );
        // Light the shuffle mode AFTER playback started on the deterministic
        // first track, so the mode reads ON (and persists) without delaying
        // the start. mpv reshuffling an already-shuffled list is harmless.
        await audioPlayer.setShuffle(true);
        playlistNotifier.addCollection(options.collectionId);
        if (options.collection is SonolythSimpleAlbumObject) {
          historyNotifier
              .addAlbums([options.collection as SonolythSimpleAlbumObject]);
        } else {
          historyNotifier.addPlaylists(
              [options.collection as SonolythSimplePlaylistObject]);
        }

        final allTracks = await options.pagination.onFetchAll();

        await playlistNotifier.addTracks(
          allTracks.skip(initialTracks.length).toList()..shuffle(),
        );
      }
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    } finally {
      if (context.mounted) {
        isShuffleLoading.value = false;
      }
    }
  }, [options, playlistNotifier, historyNotifier]);

  final onPlay = useCallback(() async {
    try {
      isPlayLoading.value = true;

      final initialTracks = options.tracks;

      if (!context.mounted) return;

      final isRemoteDevice = await showSelectDeviceDialog(context, ref);
      if (isRemoteDevice == null) return;
      if (isRemoteDevice) {
        final allTracks = await options.pagination.onFetchAll();

        final remotePlayback = ref.read(connectProvider.notifier);
        await remotePlayback.load(
          options.collection is SonolythSimpleAlbumObject
              ? WebSocketLoadEventData.album(
                  tracks: allTracks,
                  collection: options.collection as SonolythSimpleAlbumObject,
                )
              : WebSocketLoadEventData.playlist(
                  tracks: allTracks,
                  collection: options.collection as SonolythSimplePlaylistObject,
                ),
        );
      } else {
        if (initialTracks.isEmpty) return;

        await playlistNotifier.load(initialTracks, autoPlay: true);
        playlistNotifier.addCollection(options.collectionId);

        if (options.collection is SonolythSimpleAlbumObject) {
          historyNotifier.addAlbums(
            [options.collection as SonolythSimpleAlbumObject],
          );
        } else {
          historyNotifier.addPlaylists(
            [options.collection as SonolythSimplePlaylistObject],
          );
        }

        final allTracks = await options.pagination.onFetchAll();

        await playlistNotifier.addTracks(
          allTracks.skip(initialTracks.length).toList(),
        );
      }
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    } finally {
      if (context.mounted) {
        isPlayLoading.value = false;
      }
    }
  }, [options, playlistNotifier, historyNotifier]);

  return (
    isActive: isActive,
    isLoading: isPlayLoading.value || isShuffleLoading.value,
    isPlayLoading: isPlayLoading.value,
    isShuffleLoading: isShuffleLoading.value,
    onShuffle: onShuffle,
    onPlay: onPlay,
  );
}
