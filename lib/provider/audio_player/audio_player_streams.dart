import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/state.dart';
import 'package:sonolyth/provider/discord_provider.dart';
import 'package:sonolyth/provider/history/history.dart';
import 'package:sonolyth/provider/metadata_plugin/core/scrobble.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/server/routes/playback.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/sourced_track/sourced_track.dart';
import 'package:sonolyth/provider/skip_segments/skip_segments.dart';
import 'package:sonolyth/provider/scrobbler/scrobbler.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/audio_services/audio_services.dart';
import 'package:sonolyth/services/logger/logger.dart';

class AudioPlayerStreamListeners {
  final Ref ref;
  late final AudioServices notificationService;
  AudioPlayerStreamListeners(this.ref) {
    AudioServices.create(ref, ref.read(audioPlayerProvider.notifier)).then(
      (value) => notificationService = value,
    );

    final subscriptions = [
      subscribeToPlaylist(),
      subscribeToSkipSponsor(),
      subscribeToScrobbleChanged(),
      subscribeToPosition(),
      subscribeToNextTrackPrefetch(),
      subscribeToPlayerError(),
    ];

    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
  }

  final Dio _prefetchDio = Dio();

  ScrobblerNotifier get scrobbler => ref.read(scrobblerProvider.notifier);
  UserPreferences get preferences => ref.read(userPreferencesProvider);
  DiscordNotifier get discord => ref.read(discordProvider.notifier);
  AudioPlayerState get audioPlayerState => ref.read(audioPlayerProvider);
  PlaybackHistoryActions get history =>
      ref.read(playbackHistoryActionsProvider);

  StreamSubscription subscribeToPlaylist() {
    return audioPlayer.playlistStream.listen((mpvPlaylist) {
      try {
        if (audioPlayerState.activeTrack == null) return;
        notificationService.addTrack(audioPlayerState.activeTrack!);
        discord.updatePresence(audioPlayerState.activeTrack!);
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
          await ref.read(
            sourcedTrackProvider(nextTrack as SonolythFullTrackObject).future,
          );
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
        lastPrefetchedFor = activeId;

        // Tiny debounce so a skip burst coalesces on the landing track
        // instead of kicking off a fetch per intermediate track.
        await Future.delayed(const Duration(milliseconds: 200));
        if (audioPlayerState.activeTrack?.id != activeId) return;

        // Warm the window IN PARALLEL — sequential warming (one search +
        // manifest at a time) can't keep pace with repeated skips, which is
        // exactly when the window matters. Resolutions are cached per track,
        // so overlapping runs only pay for tracks not already resolved, and
        // one track failing must not sink the rest of the window.
        final upcoming = audioPlayerState.tracks
            .skip(audioPlayerState.currentIndex + 1)
            .whereType<SonolythFullTrackObject>()
            .take(5);

        await Future.wait(
          upcoming.map(
            (track) async {
              try {
                await ref.read(sourcedTrackProvider(track).future);
              } catch (e, stack) {
                AppLogger.reportError(e, stack);
              }
            },
          ),
        );

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
            final sourced =
                await ref.read(sourcedTrackProvider(previous).future);
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

  /// Pokes [sourced]'s stream URL with a one-byte range request; when it no
  /// longer answers (expired/revoked), refreshes the URL while the user is
  /// still on the current track instead of when they press "previous".
  Future<void> _ensureStreamAlive(
    SonolythFullTrackObject track,
    SourcedTrack sourced,
  ) async {
    final url = sourced.url;
    if (url == null) return;
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
    return audioPlayer.errorStream.listen((event) {});
  }
}

final audioPlayerStreamListenersProvider =
    Provider<AudioPlayerStreamListeners>(AudioPlayerStreamListeners.new);
