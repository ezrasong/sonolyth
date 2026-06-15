import 'dart:math';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/extensions/list.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/state.dart';
import 'package:sonolyth/provider/blacklist_provider.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/discord_provider.dart';
import 'package:sonolyth/provider/server/server.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  BlackListNotifier get _blacklist => ref.read(blacklistProvider.notifier);

  void _assertAllowedTracks(Iterable<SonolythTrackObject> tracks) {
    assert(
      tracks.every(
        (track) =>
            track is SonolythFullTrackObject || track is SonolythLocalTrackObject,
      ),
      'All tracks must be either SonolythFullTrackObject or SonolythLocalTrackObject',
    );
  }

  void _assertAllowedTrack(SonolythTrackObject tracks) {
    assert(
      tracks is SonolythFullTrackObject || tracks is SonolythLocalTrackObject,
      'Track must be either SonolythFullTrackObject or SonolythLocalTrackObject',
    );
  }

  Future<void> _syncSavedState() async {
    final database = ref.read(databaseProvider);

    var playerState =
        await database.select(database.audioPlayerStateTable).getSingleOrNull();

    if (playerState == null) {
      await database.into(database.audioPlayerStateTable).insert(
            AudioPlayerStateTableCompanion.insert(
              playing: audioPlayer.isPlaying,
              loopMode: audioPlayer.loopMode,
              shuffled: audioPlayer.isShuffled,
              collections: <String>[],
              tracks: const Value(<SonolythTrackObject>[]),
              currentIndex: const Value(0),
              id: const Value(0),
            ),
          );

      playerState =
          await database.select(database.audioPlayerStateTable).getSingle();
    } else {
      await audioPlayer.setLoopMode(playerState.loopMode);
      await audioPlayer.setShuffle(playerState.shuffled);
    }

    final tracks = playerState.tracks;
    final currentIndex = playerState.currentIndex;

    if (tracks.isEmpty && state.tracks.isNotEmpty) {
      await _updatePlayerState(
        AudioPlayerStateTableCompanion(
          tracks: Value(state.tracks),
          currentIndex: Value(currentIndex),
        ),
      );
    } else if (tracks.isNotEmpty) {
      // Media URIs embed the local playback server's port — wait for the
      // server to be up before building them, or every restored track points
      // at port 0 and can never play.
      await ref.read(serverProvider.future);

      // The user may have started playing something while we were waiting on
      // the server; restoring now would rip their queue (and modes) out from
      // under them.
      if (state.tracks.isNotEmpty) return;

      // A corrupt/legacy row could carry an index past the restored queue;
      // openPlaylist asserts initialIndex <= length-1, so clamp it.
      final safeIndex = currentIndex.clamp(0, tracks.length - 1);

      state = state.copyWith(
        tracks: tracks,
        currentIndex: safeIndex,
      );
      await audioPlayer.openPlaylist(
        tracks.asMediaList(),
        initialIndex: safeIndex,
        autoPlay: false,
      );

      // Opening a playlist resets mpv's modes; re-apply the saved ones so
      // shuffle/repeat survive an app restart.
      await audioPlayer.setLoopMode(playerState.loopMode);
      await audioPlayer.setShuffle(playerState.shuffled);

      // Eagerly resolve the restored active track's stream, the same way load()
      // boosts a freshly-opened queue. Without this, on a cold start the
      // (kept-alive) sourcedTrackProvider isn't primed until a player widget
      // first watches it — so the play button can sit on its loading spinner
      // while nothing has actually started resolving the track.
      final restoredActiveTrack = state.activeTrack;
      if (restoredActiveTrack is SonolythFullTrackObject) {
        ref.read(sourcedTrackProvider(restoredActiveTrack).future);
      }
    }

    if (playerState.collections.isNotEmpty) {
      state = state.copyWith(
        collections: playerState.collections,
      );
    }
  }

  Future<void> _updatePlayerState(
    AudioPlayerStateTableCompanion companion,
  ) async {
    final database = ref.read(databaseProvider);

    await (database.update(database.audioPlayerStateTable)
          ..where((tb) => tb.id.equals(0)))
        .write(companion);
  }

  @override
  build() {
    final subscriptions = [
      audioPlayer.playingStream.listen((playing) async {
        try {
          state = state.copyWith(playing: playing);

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              playing: Value(playing),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
      audioPlayer.loopModeStream.listen((loopMode) async {
        try {
          state = state.copyWith(loopMode: loopMode);

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              loopMode: Value(loopMode),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
      audioPlayer.shuffledStream.listen((shuffled) async {
        try {
          state = state.copyWith(shuffled: shuffled);

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              shuffled: Value(shuffled),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
      audioPlayer.playlistStream.listen((playlist) async {
        try {
          final tracks =
              playlist.medias.map((e) => SonolythMedia.media(e).track).toList();

          state = state.copyWith(
            tracks: tracks,
            currentIndex: playlist.index,
          );

          await _updatePlayerState(
            AudioPlayerStateTableCompanion(
              currentIndex: Value(state.currentIndex),
              tracks: Value(state.tracks),
            ),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }),
    ];

    _syncSavedState().catchError((e, stack) {
      AppLogger.reportError(e, stack);
    });

    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });

    return AudioPlayerState(
      loopMode: audioPlayer.loopMode,
      playing: audioPlayer.isPlaying,
      shuffled: audioPlayer.isShuffled,
      tracks: [],
      collections: [],
    );
  }

  // Collection related methods
  Future<void> addCollections(List<String> collectionIds) async {
    state = state.copyWith(collections: [
      ...state.collections,
      ...collectionIds,
    ]);

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        collections: Value(state.collections),
      ),
    );
  }

  Future<void> addCollection(String collectionId) async {
    await addCollections([collectionId]);
  }

  Future<void> removeCollections(List<String> collectionIds) async {
    state = state.copyWith(
      collections: state.collections
          .where((element) => !collectionIds.contains(element))
          .toList(),
    );

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        collections: Value(state.collections),
      ),
    );
  }

  Future<void> removeCollection(String collectionId) async {
    await removeCollections([collectionId]);
  }

  Future<void> addTracksAtFirst(
    Iterable<SonolythTrackObject> tracks, {
    bool allowDuplicates = false,
  }) async {
    _assertAllowedTracks(tracks);
    if (state.tracks.length == 1) {
      return addTracks(tracks);
    }

    final addableTracks = _blacklist
        .filter(tracks)
        .where(
          (track) =>
              allowDuplicates ||
              !state.tracks.any((element) => _compareTracks(element, track)),
        )
        .toList();

    state = state.copyWith(
      tracks: [...addableTracks, ...state.tracks],
    );

    for (int i = 0; i < addableTracks.length; i++) {
      final track = addableTracks.elementAt(i);

      await audioPlayer.addTrackAt(
        SonolythMedia(track),
        max(state.currentIndex, 0) + i + 1,
      );
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> addTrack(SonolythTrackObject track) async {
    _assertAllowedTrack(track);

    if (_blacklist.contains(track)) return;
    if (state.tracks.any((element) => _compareTracks(element, track))) return;

    state = state.copyWith(
      tracks: [...state.tracks, track],
    );

    await audioPlayer.addTrack(SonolythMedia(track));

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> addTracks(Iterable<SonolythTrackObject> tracks) async {
    _assertAllowedTracks(tracks);

    tracks = _blacklist.filter(tracks).toList();
    state = state.copyWith(
      tracks: [...state.tracks, ...tracks],
    );

    for (final track in tracks) {
      await audioPlayer.addTrack(SonolythMedia(track));
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> removeTrack(String trackId) async {
    final index = state.tracks.indexWhere((element) => element.id == trackId);

    if (index == -1) return;

    state = state.copyWith(
      tracks: List.of(state.tracks)..removeAt(index),
    );

    await audioPlayer.removeTrack(index);

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> removeTracks(Iterable<String> trackIds) async {
    final trackIndexes = state.tracks
        .mapIndexed((index, element) => (index, element.id))
        .where((entry) => trackIds.contains(entry.$2))
        .map((entry) => entry.$1)
        .toList();

    final tracks = state.tracks.where(
      (element) => !trackIds.contains(element.id),
    );

    state = state.copyWith(
      tracks: tracks.toList(),
    );

    // Remove from the end so earlier indexes stay valid as the player's
    // playlist shrinks.
    for (final index in trackIndexes.reversed) {
      await audioPlayer.removeTrack(index);
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  bool _compareTracks(SonolythTrackObject a, SonolythTrackObject b) {
    if (a.runtimeType != b.runtimeType) {
      return false;
    }

    return a is SonolythLocalTrackObject && b is SonolythLocalTrackObject
        ? a.path == b.path
        : a.id == b.id;
  }

  Future<void> load(
    List<SonolythTrackObject> tracks, {
    int initialIndex = 0,
    bool autoPlay = false,
  }) async {
    _assertAllowedTracks(tracks);

    final medias = _blacklist
        .filter(tracks)
        .toList()
        .asMediaList()
        .unique((a, b) => a.uri == b.uri);

    // Giving the initial track a boost so MediaKit won't skip
    // because of timeout
    final intendedActiveTrack = medias.elementAt(initialIndex);
    if (intendedActiveTrack.track is! SonolythLocalTrackObject) {
      ref.read(
        sourcedTrackProvider(
          intendedActiveTrack.track as SonolythFullTrackObject,
        ).future,
      );
    }

    if (medias.isEmpty) return;

    // Shuffle/repeat are sticky player modes (like Spotify): starting a new
    // queue must not silently reset them, but mpv's open() does exactly that
    // — so capture them here and re-apply after the playlist is opened.
    final previousLoopMode = audioPlayer.loopMode;
    final previousShuffle = audioPlayer.isShuffled;

    state = state.copyWith(
      // These are filtered tracks as well
      tracks: medias.map((media) => media.track).toList(),
      currentIndex: initialIndex,
      collections: [],
    );

    await audioPlayer.openPlaylist(
      medias,
      initialIndex: initialIndex,
      autoPlay: autoPlay,
    );

    await audioPlayer.setLoopMode(previousLoopMode);
    if (previousShuffle) {
      await audioPlayer.setShuffle(true);
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(max(state.currentIndex, 0)),
      ),
    );
  }

  Future<void> swapActiveSource() async {
    if (state.tracks.isEmpty || state.activeTrack is! SonolythFullTrackObject) {
      return;
    }

    final oldState = state;
    await audioPlayer.stop();

    // load() re-applies the sticky shuffle/loop modes itself, but stop()
    // resets them in mpv first — hand the pre-stop modes back explicitly.
    await audioPlayer.setLoopMode(oldState.loopMode);
    await load(
      oldState.tracks,
      initialIndex: oldState.currentIndex,
      autoPlay: true,
    );
    state = state.copyWith(
      collections: oldState.collections,
    );
    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: Value(state.currentIndex),
        collections: Value(state.collections),
        loopMode: Value(state.loopMode),
        playing: Value(state.playing),
        shuffled: Value(state.shuffled),
      ),
    );
  }

  Future<void> jumpToTrack(SonolythTrackObject track) async {
    final index =
        state.tracks.toList().indexWhere((element) => element.id == track.id);
    if (index == -1) return;
    await audioPlayer.jumpTo(index);
  }

  Future<void> moveTrack(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex ||
        newIndex < 0 ||
        oldIndex < 0 ||
        newIndex > state.tracks.length - 1 ||
        oldIndex > state.tracks.length - 1) {
      return;
    }

    await audioPlayer.moveTrack(oldIndex, newIndex);
  }

  Future<void> stop() async {
    // Shuffle/repeat are sticky preferences: stopping (including the media
    // notification being dismissed) clears the queue, not the modes —
    // otherwise every session starts with shuffle/repeat silently reset.
    final loopMode = state.loopMode;
    final shuffled = state.shuffled;

    state = state.copyWith(
      tracks: [],
      currentIndex: 0,
      collections: [],
      playing: false,
    );
    await audioPlayer.stop();

    // mpv's stop resets its shuffle flag; re-arm the saved modes so the next
    // load() picks them up again.
    await audioPlayer.setLoopMode(loopMode);
    if (shuffled) {
      await audioPlayer.setShuffle(true);
    }

    await _updatePlayerState(
      AudioPlayerStateTableCompanion(
        tracks: Value(state.tracks),
        currentIndex: const Value(0),
        collections: const Value(<String>[]),
        playing: const Value(false),
      ),
    );
    ref.read(discordProvider.notifier).clear();
  }
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  () => AudioPlayerNotifier(),
);
