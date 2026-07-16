import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/smart_shuffle.dart';
import 'package:sonolyth/provider/audio_player/state.dart';
import 'package:sonolyth/provider/discord_provider.dart';
import 'package:sonolyth/provider/history/history.dart';
import 'package:sonolyth/provider/metadata_plugin/core/scrobble.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/server/routes/playback.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/sourced_track/sourced_track.dart';
import 'package:sonolyth/services/sourced_track/tidal_dash.dart';
import 'package:sonolyth/provider/skip_segments/skip_segments.dart';
import 'package:sonolyth/provider/scrobbler/scrobbler.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/audio_services/audio_services.dart';
import 'package:sonolyth/services/logger/logger.dart';

class AudioPlayerStreamListeners {
  final Ref ref;
  // Nullable + assigned asynchronously: AudioServices.create() resolves after
  // the constructor returns, so a stream emission that lands in that gap must
  // null-check rather than touch an uninitialized `late final` (which throws).
  AudioServices? notificationService;
  AudioPlayerStreamListeners(this.ref) {
    AudioServices.create(ref, ref.read(audioPlayerProvider.notifier)).then(
      (value) {
        notificationService = value;
        // A playlist emission may have arrived before creation finished; push
        // the current track now so the notification isn't left blank.
        final active = ref.read(audioPlayerProvider).activeTrack;
        if (active != null) {
          try {
            value.addTrack(active);
          } catch (_) {}
        }
      },
    );

    // The shuffle->smart transition doesn't change the player's shuffle flag,
    // so no audio_player stream fires — poke the notification directly to
    // swap the shuffle button icon.
    ref.listen(smartShuffleProvider, (previous, next) {
      try {
        notificationService?.mobile?.refreshPlaybackState();
      } catch (_) {
        // notificationService may not be initialized yet.
      }
    });

    final subscriptions = [
      subscribeToPlaylist(),
      subscribeToSkipSponsor(),
      subscribeToScrobbleChanged(),
      subscribeToPosition(),
      subscribeToNextTrackPrefetch(),
      subscribeToShuffleRewarm(),
      subscribeToResumeRewarm(),
      subscribeToPlayerError(),
    ];

    ref.onDispose(() {
      _bufferAheadToken?.cancel();
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
  }

  final Dio _prefetchDio = Dio();

  /// Cancels an in-flight buffer-ahead when the active track changes, so rapid
  /// skips don't pile up background downloads of tracks you've already passed.
  CancelToken? _bufferAheadToken;

  ScrobblerNotifier get scrobbler => ref.read(scrobblerProvider.notifier);
  UserPreferences get preferences => ref.read(userPreferencesProvider);
  DiscordNotifier get discord => ref.read(discordProvider.notifier);
  AudioPlayerState get audioPlayerState => ref.read(audioPlayerProvider);
  PlaybackHistoryActions get history =>
      ref.read(playbackHistoryActionsProvider);

  StreamSubscription subscribeToPlaylist() {
    return audioPlayer.playlistStream.listen((mpvPlaylist) {
      try {
        // Derive the now-playing track from the emitted playlist itself rather
        // than re-reading audioPlayerProvider.activeTrack. The provider's own
        // playlistStream listener (which advances currentIndex) is a *separate*
        // subscriber to this same broadcast stream, so for any given emission
        // it may not have committed the new index yet. Reading shared state
        // here would then push the previous track to the notification/Discord
        // and leave the thumbnail + title stale after a skip.
        final index = mpvPlaylist.index;
        if (index < 0 || index >= mpvPlaylist.medias.length) return;
        final activeTrack = SonolythMedia.media(mpvPlaylist.medias[index]).track;

        notificationService?.addTrack(activeTrack);
        discord.updatePresence(activeTrack);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  StreamSubscription subscribeToSkipSponsor() {
    return audioPlayer.positionStream.listen((position) async {
      try {
        final currentSegments = await ref.read(segmentProvider.future);

        if (currentSegments?.segments.isNotEmpty != true ||
            position < const Duration(seconds: 3)) {
          return;
        }

        for (final segment in currentSegments!.segments) {
          final seconds = position.inSeconds;

          if (seconds < segment.start || seconds >= segment.end) continue;

          await audioPlayer.seek(Duration(seconds: segment.end + 1));
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  StreamSubscription subscribeToScrobbleChanged() {
    String? lastScrobbled;
    return audioPlayer.positionStream.listen((position) async {
      try {
        final uid = audioPlayerState.activeTrack is SonolythLocalTrackObject
            ? (audioPlayerState.activeTrack as SonolythLocalTrackObject).path
            : audioPlayerState.activeTrack?.id;

        /// According to Listenbrainz and Last.fm, a scrobble should be sent
        /// after 4 minutes of listening or 50% of the track duration,
        /// whichever is less.
        final minimumListenTime = min(audioPlayer.duration.inSeconds ~/ 2, 240);

        if (audioPlayerState.activeTrack == null ||
            lastScrobbled == uid ||
            position.inSeconds < minimumListenTime ||
            audioPlayer.duration == Duration.zero ||
            position == Duration.zero) {
          return;
        }

        scrobbler.scrobble(audioPlayerState.activeTrack!);
        ref
            .read(metadataPluginScrobbleProvider.notifier)
            .scrobble(audioPlayerState.activeTrack!);
        lastScrobbled = uid;

        /// The [Track] from Playlist.getTracks doesn't contain artist images
        /// so we need to fetch them from the API
        var activeTrack = audioPlayerState.activeTrack!;
        if (activeTrack.artists.any((a) => a.images == null)) {
          final metadataPlugin = await ref.read(metadataPluginProvider.future);
          final artists = await Future.wait(
            activeTrack.artists
                .map((artist) => metadataPlugin!.artist.getArtist(artist.id)),
          );
          activeTrack = activeTrack.copyWith(
            artists: artists
                .map((e) => SonolythSimpleArtistObject.fromJson(e.toJson()))
                .toList(),
          );
        }

        await history.addTrack(activeTrack);
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  StreamSubscription subscribeToPosition() {
    String lastTrack = ""; // used to prevent multiple calls to the same track
    return audioPlayer.positionStream.listen((event) async {
      final percentProgress =
          (event.inSeconds / max(audioPlayer.duration.inSeconds, 1)) * 100;
      try {
        if (percentProgress < 80 ||
            audioPlayerState.currentIndex == -1 ||
            audioPlayerState.currentIndex ==
                audioPlayerState.tracks.length - 1) {
          return;
        }
        final nextTrack = audioPlayerState.tracks
            .elementAtOrNull(audioPlayerState.currentIndex + 1);

        if (nextTrack == null ||
            lastTrack == nextTrack.id ||
            nextTrack is SonolythLocalTrackObject) {
          return;
        }

        try {
          await readSourcedTrack(ref, nextTrack as SonolythFullTrackObject);
        } finally {
          lastTrack = nextTrack.id;
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  /// Resolves the audio sources of the next few tracks as soon as the
  /// active track changes, so manual skips don't wait on a YouTube
  /// search + stream-manifest round trip. (subscribeToPosition only warms the
  /// next track at 80% progress, which never helps early skips.)
  StreamSubscription subscribeToNextTrackPrefetch() {
    String lastPrefetchedFor = "";
    return audioPlayer.playlistStream.listen((event) async {
      try {
        final activeId = audioPlayerState.activeTrack?.id;
        if (activeId == null || activeId == lastPrefetchedFor) return;

        // Tiny debounce so a skip burst coalesces on the landing track
        // instead of kicking off a fetch per intermediate track.
        await Future.delayed(const Duration(milliseconds: 200));
        if (audioPlayerState.activeTrack?.id != activeId) return;

        // Only mark this active track done when the whole window resolved:
        // a warm that failed (screen-off radio sleep, transient gateway
        // error) used to be marked complete and never retried, leaving the
        // upcoming track cold at the transition. Overlapping re-runs are
        // cheap — resolves are cached per track.
        final allWarmed = await _warmUpcomingWindow();
        if (allWarmed) lastPrefetchedFor = activeId;

        // Resolution alone isn't enough for instant skips: mpv's
        // prefetch-playlist only opens the next entry near the CURRENT track's
        // end, so a mid-track skip (the common case) pays a cold network open —
        // most noticeable on lossless (Qobuz/Tidal FLAC opens heavier than a
        // lossy stream), and a skip of +2 is never prefetched at all. Pull the
        // next couple of tracks into the music cache so a skip plays from disk.
        unawaited(_bufferAheadTracks());

        // "Previous" gets no prefetch from mpv (prefetch-playlist only
        // buffers the next entry), so pressing back pays the full stream
        // open — and a stale URL adds a refresh round trip on top of it,
        // interactively. Verify the previous track's stream still answers
        // now and refresh it in the background if it doesn't.
        final previousIndex = audioPlayerState.currentIndex - 1;
        final previous = previousIndex < 0
            ? null
            : audioPlayerState.tracks.elementAtOrNull(previousIndex);
        if (previous is SonolythFullTrackObject) {
          try {
            final sourced = await readSourcedTrack(ref, previous);
            await _ensureStreamAlive(previous, sourced);
          } catch (e, stack) {
            AppLogger.reportError(e, stack);
          }
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  /// How many upcoming tracks to resolve ahead. Sized so a burst of skips
  /// lands on an already-resolved track: the zarz lanes cap in-flight signed
  /// requests at 4, so a wider window queues (never floods) the gateway.
  static const _warmAheadCount = 8;

  /// How many just-played tracks to keep resolved/buffered behind the active
  /// one, so pressing "previous" is as instant as skipping forward.
  static const _warmBackCount = 2;

  /// Resolves (in parallel) the audio sources of the next few upcoming tracks
  /// — and the couple just played, for instant backtracking — so a manual
  /// skip in either direction never waits on a source search + stream-manifest
  /// round trip. Resolutions are cached per track, so overlapping runs only
  /// pay for tracks not already resolved, and one track failing must not sink
  /// the rest of the window. Returns true when every track in the window
  /// resolved, so callers can retry a partially-failed window later.
  Future<bool> _warmUpcomingWindow() async {
    final tracks = audioPlayerState.tracks;
    final index = audioPlayerState.currentIndex;
    final window = [
      ...tracks.skip(index + 1).whereType<SonolythFullTrackObject>().take(
            _warmAheadCount,
          ),
      for (var i = index - 1; i >= 0 && i >= index - _warmBackCount; i--)
        if (tracks.elementAtOrNull(i) is SonolythFullTrackObject)
          tracks[i] as SonolythFullTrackObject,
    ];

    final warmSw = Stopwatch()..start();
    AppLogger.diag(
      "[prefetch] warming ${window.length} around "
      "'${audioPlayerState.activeTrack?.name}'",
    );
    final results = await Future.wait(
      window.map(
        (track) async {
          try {
            await readSourcedTrack(ref, track);
            return true;
          } catch (e, stack) {
            AppLogger.reportError(e, stack);
            return false;
          }
        },
      ),
    );
    AppLogger.diag(
      "[prefetch] window ready in ${warmSw.elapsedMilliseconds}ms",
    );
    return results.every((ok) => ok);
  }

  /// How many upcoming tracks to prefix-buffer. Each is only a ~9s head (≈1MB),
  /// deduped server-side so a track is fetched at most once, so a wider window
  /// costs little extra data while covering a burst of skips.
  static const _bufferAheadCount = 4;

  /// Prefix-buffers the next few tracks — and the couple just played, so
  /// "previous" starts instantly too (see [ServerPlaybackRoutes.prebufferHead]
  /// for Qobuz heads and [ServerPlaybackRoutes.prewarmDashTrack] for TIDAL
  /// DASH first-segments) — so a skip in either direction starts from memory
  /// while the remainder streams.
  ///
  /// Data-conscious: only the first ~9s / first segment of each track is
  /// fetched (NOT the whole file), so it's safe even on mobile data — and the
  /// bytes are the start of a track you're about to play. Cancels on every
  /// track change so rapid skips don't stack fetches; the server dedups
  /// (already-buffered and disk-cached tracks are cheap no-ops, and dropping
  /// the old client-side "buffered once" set means a head the server evicted
  /// gets re-buffered instead of staying cold forever); a short delay first
  /// lets the current track open before competing for bandwidth.
  Future<void> _bufferAheadTracks() async {
    _bufferAheadToken?.cancel();
    final token = _bufferAheadToken = CancelToken();

    // A brief settle so a skip burst coalesces on the landing track, but short
    // enough that the next track's head is ready before the user skips again.
    // The head is only ~1MB so it doesn't meaningfully contend with playback.
    await Future.delayed(const Duration(milliseconds: 120));
    if (token.isCancelled) return;

    final routes = ref.read(serverPlaybackRoutesProvider);
    final tracks = audioPlayerState.tracks;
    final index = audioPlayerState.currentIndex;
    // Forward first (the likelier direction), then the just-played couple.
    final window = [
      ...tracks.skip(index + 1).whereType<SonolythFullTrackObject>().take(
            _bufferAheadCount,
          ),
      for (var i = index - 1; i >= 0 && i >= index - _warmBackCount; i--)
        if (tracks.elementAtOrNull(i) is SonolythFullTrackObject)
          tracks[i] as SonolythFullTrackObject,
    ];

    for (final track in window) {
      if (token.isCancelled) return;
      try {
        final sourced = await readSourcedTrack(ref, track);
        if (isDashUrl(sourced.url)) {
          await routes.prewarmDashTrack(sourced);
        } else {
          await routes.prebufferHead(sourced, cancelToken: token);
        }
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) return;
      } catch (_) {
        // Best effort — a failed prefix just means a normal cold open on skip.
      }
    }
  }

  /// Re-warms the upcoming window when shuffle is toggled. The upcoming order
  /// changes but the active track doesn't, so [subscribeToNextTrackPrefetch]
  /// (keyed on active-track change) won't re-fire — without this the first skip
  /// after a shuffle would pay the full resolve.
  StreamSubscription subscribeToShuffleRewarm() {
    return audioPlayer.shuffledStream.listen((_) async {
      try {
        // Let mpv commit the reshuffled order first, then warm the new window.
        await Future.delayed(const Duration(milliseconds: 200));
        await _warmUpcomingWindow();
        unawaited(_bufferAheadTracks());
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  /// Re-warms the upcoming window when playback resumes from pause. While
  /// paused with the screen off the app drops its foreground service and
  /// wakelock (androidStopForegroundOnPause), so warms scheduled during the
  /// pause never ran — or failed with the radio asleep — and pressing play
  /// from the lock screen landed on a cold (or error-stuck) next track.
  /// Resolves are cached per track, so when the window is already warm this
  /// is a no-op.
  StreamSubscription subscribeToResumeRewarm() {
    var wasPlaying = false;
    return audioPlayer.playingStream.listen((playing) async {
      final resumed = playing && !wasPlaying;
      wasPlaying = playing;
      if (!resumed) return;
      try {
        await _warmUpcomingWindow();
        unawaited(_bufferAheadTracks());
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    });
  }

  /// Pokes [sourced]'s stream URL with a one-byte range request; when it no
  /// longer answers (expired/revoked), refreshes the URL while the user is
  /// still on the current track instead of when they press "previous".
  Future<void> _ensureStreamAlive(
    SonolythFullTrackObject track,
    SourcedTrack sourced,
  ) async {
    final url = sourced.url;
    // A TIDAL DASH track's url is the `x-tidal-dash:` marker, not a real HTTP
    // URL — probing/refreshing it throws "No host specified". It's served by
    // stitching the manifest server-side, so skip the alive-check here.
    if (url == null || isDashUrl(url)) return;
    try {
      await _prefetchDio.get(
        url,
        options: Options(
          headers: {
            "range": "bytes=0-0",
            "user-agent": streamUserAgentFor(sourced),
          },
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (status) => status != null && status < 400,
        ),
      );
    } catch (_) {
      await ref
          .read(sourcedTrackProvider(track).notifier)
          .refreshStreamingUrl();
    }
  }

  StreamSubscription subscribeToPlayerError() {
    return audioPlayer.errorStream.listen((event) {
      // Don't silently drop playback errors (stream-open / codec failures);
      // surface them to the logs for diagnosis.
      AppLogger.log.e("Audio player error: $event");
    });
  }
}

final audioPlayerStreamListenersProvider =
    Provider<AudioPlayerStreamListeners>(AudioPlayerStreamListeners.new);
