import 'dart:math';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/extensions/list.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/state.dart';
import 'package:sonolyth/provider/blacklist_provider.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/discord_provider.dart';
import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/provider/server/server.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  BlackListNotifier get _blacklist => ref.read(blacklistProvider.notifier);

  /// A queue that was built and shown but deliberately **not** handed to mpv,
  /// because nothing in it could have been opened.
  ///
  /// **Why this exists.** mpv's answer to a failed open is `playlist-next`,
  /// and it cannot be told otherwise — there is no "stop on error". So while
  /// lossless access is unverified, handing it a queue starts a machine that
  /// walks the whole thing: measured at a track every 7.5s before §42 held the
  /// stream request open, and still one per ~100s after, which is a 233-track
  /// queue gone in six hours rather than in half an hour (§42b, item 57).
  /// Every step of that walk also writes mpv's playlist index into the
  /// database, so the user's saved place dies with it.
  ///
  /// §42 attacked the symptom from the far end — hold the request, make mpv
  /// wait. This is the other end, and it is the one that closes it: **never
  /// hand mpv an entry it cannot open.** Nothing is lost by waiting, because
  /// nothing could have played anyway; the queue is already in [state], so the
  /// player and the queue page show it in full, and the meta chip says why it
  /// is not moving (§42a).
  ///
  /// Only the *intent* is kept, never a copy of the queue: [state] stays the
  /// truth while mpv is empty, and every queue mutation already writes itself
  /// there before telling mpv. A snapshot taken at defer time would go stale
  /// the moment the user reordered or removed anything, and resuming would
  /// quietly restore the queue they had edited away.
  ({bool autoPlay})? _deferredQueue;

  /// Whether a queue is being held out of mpv pending verification.
  bool get hasDeferredQueue => _deferredQueue != null;

  /// The one place [_deferredQueue] is written, so [playbackDeferredProvider]
  /// cannot fall out of step with it.
  ///
  /// The flag is a field rather than part of [AudioPlayerState] on purpose —
  /// that state is persisted column by column and a transient "mpv is empty
  /// right now" has no business surviving a restart. But the seek bar has to
  /// know (item 64), so the field is mirrored into a provider instead of
  /// making the state carry it.
  void _setDeferredQueue(({bool autoPlay})? value) {
    if (_deferredQueue == value) return;
    _deferredQueue = value;
    ref.read(playbackDeferredProvider.notifier).state = value != null;
  }

  /// Hands [medias] to mpv, or holds them back if the entry it would open is
  /// one the stream route is going to refuse.
  ///
  /// Deliberately gated on the **local** session state and not on a resolve:
  /// awaiting a resolve here would put a gateway round trip in front of every
  /// play, which is the one thing playback is not allowed to do. A live
  /// session takes the same path it always did.
  Future<void> _openPlaylistOrDefer(
    List<SonolythMedia> medias, {
    required int initialIndex,
    required bool autoPlay,
  }) async {
    if (await _mpvCanOpen(medias.elementAtOrNull(initialIndex))) {
      _setDeferredQueue(null);
      await audioPlayer.openPlaylist(
        medias,
        initialIndex: initialIndex,
        autoPlay: autoPlay,
      );
      return;
    }

    // Set **before** the teardown below: the playlist mirror is suppressed
    // only while this is non-null, and clearing mpv's playlist raises exactly
    // the empty-playlist event §43d had to stop being written through
    // (`current_index = -1, tracks = 0` — the queue erased in one step).
    _setDeferredQueue((autoPlay: autoPlay));

    // Whatever mpv is holding is not this queue. Deferring only declines to
    // *give* it the new one, so left alone it plays the old one on: measured
    // on the device, tapping a blocked Spotify track while a 30-second tone
    // was playing switched every surface to the new track and let the tone
    // run to 29999ms and stop there. The user hears one track and reads
    // another. `state` is the truth while mpv is empty (§43d), so this costs
    // the queue nothing.
    await audioPlayer.clearPlaylist();

    AppLogger.diag(
      "[verify-gate] holding ${medias.length} tracks out of mpv at index "
      "$initialIndex — no lossless source is usable, and a queue mpv cannot "
      "open is a queue it walks",
    );
  }

  /// Whether mpv could actually open [media] right now.
  ///
  /// Reads the two facts and hands the decision to [mpvCanOpenTrack]; the
  /// judgement is there so it can be checked without a player, a database or a
  /// gateway.
  Future<bool> _mpvCanOpen(SonolythMedia? media) async {
    final track = media?.track;
    if (track == null) return true;

    // `DownloadedTracksNotifier.build()` can only kick its registry read off
    // asynchronously, so for a window after launch every track reads as *not*
    // downloaded — which is exactly the mistake its own doc comment warns
    // callers about, and here it would hold a fully downloaded queue out of
    // mpv because no session exists to stream music nobody needs to stream.
    // The restore path runs inside that window by definition.
    final downloads = ref.read(downloadedTracksProvider.notifier);
    await downloads.ready;

    return mpvCanOpenTrack(
      track,
      isDownloaded: downloads.isDownloaded(track.id),
      losslessUsable: await ZarzSession.anyLosslessUsable(),
    );
  }

  /// Whether mpv could open [track], given what is known locally.
  ///
  /// **Only the total blackout is gated.** A local file and a downloaded track
  /// are served off disk and never touch the gateway, so a queue sitting on
  /// one starts exactly as it always did; a usable session means every entry
  /// resolves the way it always has. What is left — an entry that can only
  /// come off the wire, and nothing to fetch it with — is the one case where
  /// *every* open fails, and so the one case where handing mpv the playlist
  /// does nothing but damage.
  ///
  /// Erring towards `true` is deliberate. A wrong `false` refuses to play
  /// something that would have worked; a wrong `true` is only ever what the
  /// app did before this gate existed.
  @visibleForTesting
  static bool mpvCanOpenTrack(
    SonolythTrackObject track, {
    required bool isDownloaded,
    required bool losslessUsable,
  }) {
    if (track is SonolythLocalTrackObject) return true;
    if (isDownloaded) return true;
    return losslessUsable;
  }

  /// Hands a held-back queue to mpv now that lossless access is usable.
  ///
  /// Called from `reloadPlaybackAfterVerification`, which is the one place
  /// that runs after a Turnstile is passed. Returns whether anything was
  /// opened, so the caller knows the jump it was about to do is redundant.
  Future<bool> resumeDeferredQueue() async {
    final deferred = _deferredQueue;
    if (deferred == null || state.tracks.isEmpty) return false;

    final medias = state.tracks.asMediaList();
    final index = state.currentIndex.clamp(0, medias.length - 1);
    if (!await _mpvCanOpen(medias.elementAtOrNull(index))) return false;

    // Cleared *before* the open: the playlist mirror is suppressed while this
    // is set, and mpv is about to start reporting the truth again.
    _setDeferredQueue(null);
    AppLogger.diag(
      "[verify-gate] lossless is usable again — handing ${medias.length} "
      "tracks to mpv at index $index",
    );
    await audioPlayer.openPlaylist(
      medias,
      initialIndex: index,
      // A queue held back at launch was never playing; one held back from a
      // play action was, and the user is still waiting for it.
      autoPlay: deferred.autoPlay,
    );
    // openPlaylist resets mpv's modes, the same way load() and restore have to
    // put them back.
    await audioPlayer.setLoopMode(state.loopMode);
    if (state.shuffled) await audioPlayer.setShuffle(true);
    return true;
  }

  /// Runs [verify] with the held-back queue marked to **start playing** the
  /// moment access lands, and takes the mark back if it never did.
  ///
  /// This is what the transport's play button does while a queue is deferred
  /// (item 65). `resume()` is a no-op there — mpv holds nothing to resume —
  /// so the button was the one control on the player that neither worked nor
  /// said why, next to a meta chip already offering the fix. Verification is
  /// the only thing that can make play work, so play *is* verify here.
  ///
  /// The mark matters because [resumeDeferredQueue] replays the intent the
  /// queue was deferred with: a queue held back at launch carries
  /// `autoPlay: false`, so without this a granted challenge would hand it to
  /// mpv and leave it paused — a second dead press.
  ///
  /// It is put back on failure for the opposite reason. A cancelled dialog
  /// means "not now", and a mark left set outlives the press: the launch
  /// warm-up and the keep-alive self-heal both call
  /// `reloadPlaybackAfterVerification` headlessly, so music would start
  /// minutes later with nobody's finger anywhere near the app. Nothing is put
  /// back when the queue *was* handed over — [resumeDeferredQueue] has already
  /// consumed the intent and cleared the field.
  Future<void> playDeferredQueue(Future<void> Function() verify) =>
      runDeferredPlay(
        read: () => _deferredQueue,
        write: _setDeferredQueue,
        verify: verify,
      );

  /// The order [playDeferredQueue] runs in, split out so it can be checked
  /// without a player, a gateway or a dialog — the same reason
  /// [mpvCanOpenTrack] is a static.
  ///
  /// What is worth pinning here is a *sequence*, not a value, and both ways it
  /// can go wrong are ordering: marking after the dialog rather than before
  /// (the grant lands first and hands the queue over paused), and leaving the
  /// mark set when nothing was granted (headless verification starts music
  /// minutes later, unasked). Neither shows up in a type.
  @visibleForTesting
  static Future<void> runDeferredPlay({
    required ({bool autoPlay})? Function() read,
    required void Function(({bool autoPlay})?) write,
    required Future<void> Function() verify,
  }) async {
    final before = read();
    if (before == null) return;
    write((autoPlay: true));
    try {
      await verify();
    } finally {
      // `null` means the queue was handed to mpv while the dialog was up:
      // `resumeDeferredQueue` has consumed the intent already and writing the
      // old one back would re-arm a gate that is no longer holding anything.
      if (read() != null) write(before);
    }
  }

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
      await _openPlaylistOrDefer(
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
          // mpv's playlist is the queue's mirror only while mpv HAS the queue.
          // A queue held back by the verify gate (§43) leaves mpv empty, and
          // this stream reports empty as `index: -1` with no medias — writing
          // that through would erase the user's queue and their place in it in
          // a single step, which is a sharper version of the very damage the
          // gate exists to prevent. Measured, not reasoned about: the first
          // gated launch put `current_index = -1, tracks = 0` into the
          // database. While something is deferred, [_deferredQueue] is the
          // truth and [state] already holds it.
          if (_deferredQueue != null) return;

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

    // Remember which track the caller actually wants BEFORE filtering:
    // blacklisting and URI de-duplication shrink the list, so an index
    // computed against `tracks` (the full/visible collection) can point past
    // the end of `medias` — which threw
    // "RangeError (length): Invalid value: Not in inclusive range 0..738: 744"
    // on elementAt below and killed playback on tap.
    final intendedTrack =
        initialIndex >= 0 && initialIndex < tracks.length
            ? tracks[initialIndex]
            : null;

    final medias = _blacklist
        .filter(tracks)
        .toList()
        .asMediaList()
        .unique((a, b) => a.uri == b.uri);

    if (medias.isEmpty) return;

    // Re-resolve the requested track's position in the filtered list; fall
    // back to a clamped index when it was itself filtered out.
    var effectiveIndex = intendedTrack == null
        ? -1
        : medias.indexWhere((m) => _compareTracks(m.track, intendedTrack));
    if (effectiveIndex < 0) {
      effectiveIndex = initialIndex.clamp(0, medias.length - 1);
    }

    // Giving the initial track a boost so MediaKit won't skip
    // because of timeout
    final intendedActiveTrack = medias.elementAt(effectiveIndex);
    if (intendedActiveTrack.track is! SonolythLocalTrackObject) {
      ref.read(
        sourcedTrackProvider(
          intendedActiveTrack.track as SonolythFullTrackObject,
        ).future,
      );
    }

    // Shuffle/repeat are sticky player modes (like Spotify): starting a new
    // queue must not silently reset them, but mpv's open() does exactly that
    // — so capture them here and re-apply after the playlist is opened.
    final previousLoopMode = audioPlayer.loopMode;
    final previousShuffle = audioPlayer.isShuffled;

    state = state.copyWith(
      // These are filtered tracks as well
      tracks: medias.map((media) => media.track).toList(),
      currentIndex: effectiveIndex,
      collections: [],
    );

    await _openPlaylistOrDefer(
      medias,
      initialIndex: effectiveIndex,
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
    // Nothing is being held back from a player with no queue. Left set, the
    // flag would keep the playlist mirror suppressed (line ~330) and hold the
    // seek bar inert for whatever plays next.
    _setDeferredQueue(null);
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

/// Whether the queue is currently held out of mpv by the §43 verify gate.
///
/// Written only by [AudioPlayerNotifier._setDeferredQueue]. Anything reading
/// the engine's own streams needs this, because while it is `true` **mpv holds
/// nothing**: its duration stream still reports the last media it actually
/// opened, so a deferred track sat under a seek bar reading `00:00 / 00:30`
/// with the 30 seconds belonging to the track played before it (item 64).
final playbackDeferredProvider = StateProvider<bool>((ref) => false);
