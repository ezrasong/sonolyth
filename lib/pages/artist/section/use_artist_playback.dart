import 'dart:math';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/components/dialogs/select_device_dialog.dart';
import 'package:sonolyth/models/connect/connect.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/connect/connect.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/top_tracks.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

typedef ArtistPlayback = ({
  List<SonolythFullTrackObject> tracks,
  bool hasTracks,

  /// The queue is playing *this* artist's top tracks.
  bool isActive,
  bool playing,
  bool isPlayLoading,
  bool isShuffleLoading,
  bool isLoading,
  Future<void> Function() onPlay,
  Future<void> Function() onShuffle,
  Future<void> Function(SonolythTrackObject track) onPlayTrack,
});

/// The artist page's top tracks as one playable thing, shared by the header
/// buttons and the rows under them.
///
/// The queue is tagged `artist:<id>` the way the search results are tagged
/// `search:<term>` (§28), so the header can show pause and the shuffle mode
/// while its own tracks play instead of guessing from queue contents.
ArtistPlayback useArtistPlayback(WidgetRef ref, String artistId) {
  final context = useContext();
  final isPlayLoading = useState(false);
  final isShuffleLoading = useState(false);

  final playlist = ref.watch(audioPlayerProvider);
  final playlistNotifier = ref.read(audioPlayerProvider.notifier);
  final topTracksQuery =
      ref.watch(metadataPluginArtistTopTracksProvider(artistId));

  final tracks =
      topTracksQuery.asData?.value.items ?? const <SonolythFullTrackObject>[];
  final collectionId = "artist:$artistId";
  final isActive =
      tracks.isNotEmpty && playlist.collections.contains(collectionId);
  final playing =
      useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

  Future<void> start({
    required bool shuffle,
    SonolythTrackObject? from,
  }) async {
    final flag = shuffle ? isShuffleLoading : isPlayLoading;
    if (tracks.isEmpty) return;
    try {
      flag.value = true;

      final isRemoteDevice = await showSelectDeviceDialog(context, ref);
      if (isRemoteDevice == null) return;

      final startIndex = from == null
          ? 0
          : tracks
              .indexWhere((t) => t.id == from.id)
              .clamp(0, tracks.length - 1);

      if (isRemoteDevice) {
        final remotePlayback = ref.read(connectProvider.notifier);
        await remotePlayback.load(
          WebSocketLoadEventData.playlist(
            tracks: tracks,
            initialIndex:
                shuffle ? Random().nextInt(tracks.length) : startIndex,
          ),
        );
        if (shuffle) await remotePlayback.setShuffle(true);
        return;
      }

      // Already playing this artist and the row tapped is another track:
      // jump instead of reloading the queue.
      if (isActive && from != null && playlist.activeTrack?.id != from.id) {
        await playlistNotifier.jumpToTrack(from);
        return;
      }

      // Shuffled in Dart and started on a deterministic index, like the
      // collection header (see `useActionCallbacks`); the mode is lit after
      // the start so it persists without delaying it.
      final list = shuffle ? (tracks.toList()..shuffle()) : tracks;
      await playlistNotifier.load(
        list,
        initialIndex: shuffle ? 0 : startIndex,
        autoPlay: true,
      );
      if (shuffle) await audioPlayer.setShuffle(true);
      playlistNotifier.addCollection(collectionId);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    } finally {
      if (context.mounted) flag.value = false;
    }
  }

  return (
    tracks: tracks,
    hasTracks: tracks.isNotEmpty,
    isActive: isActive,
    playing: playing,
    isPlayLoading: isPlayLoading.value,
    isShuffleLoading: isShuffleLoading.value,
    isLoading: isPlayLoading.value || isShuffleLoading.value,
    onPlay: () => start(shuffle: false),
    onShuffle: () => start(shuffle: true),
    onPlayTrack: (track) => start(shuffle: false, from: track),
  );
}
