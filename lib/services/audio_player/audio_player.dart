import 'dart:io';

import 'package:media_kit/media_kit.dart' hide Track;
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:sonolyth/services/audio_player/custom_player.dart';
import 'dart:async';

import 'package:media_kit/media_kit.dart' as mk;

import 'package:sonolyth/services/audio_player/crossfade_engine.dart';
import 'package:sonolyth/services/audio_player/playback_state.dart';

part 'audio_players_streams_mixin.dart';
part 'audio_player_impl.dart';

class SonolythMedia extends mk.Media {
  static int serverPort = 0;

  /// Track id -> locally downloaded file path, mirrored from the downloaded
  /// tracks registry. Lets the constructor (synchronous, riverpod-free)
  /// prefer the on-disk file over the streaming server URL.
  static Map<String, String> downloadedPaths = const {};

  static String get _host => InternetAddress.anyIPv4.address;

  /// Absolute file path -> where that file's music actually starts and ends,
  /// mirrored from the track-trim registry. Lets the constructor (synchronous,
  /// riverpod-free) skip edge silence.
  static Map<String, ({Duration start, Duration end})> trimPoints = const {};

  static String _uriFor(SonolythTrackObject track) {
    if (track is SonolythLocalTrackObject) return track.path;
    final downloaded = downloadedPaths[track.id];
    if (downloaded != null && File(downloaded).existsSync()) {
      return downloaded;
    }
    return "http://$_host:$serverPort/stream/${track.id}";
  }

  /// Edge silence measured for the file this media will open, when it opens a
  /// local file at all. A streamed track's URI points at the in-app proxy,
  /// whose bytes depend on the source the track currently resolves to, so no
  /// stored measurement can be proven to describe them — those play untrimmed.
  static ({Duration start, Duration end})? _trimFor(String uri) {
    return trimPoints[uri];
  }

  final SonolythTrackObject track;
  SonolythMedia(this.track)
      : assert(
          track is SonolythLocalTrackObject || track is SonolythFullTrackObject,
          "Track must be a either a local track or a full track object with ISRC",
        ),
        // Local tracks and downloaded tracks play from disk; everything else
        // goes through the in-app streaming server.
        super(
          _uriFor(track),
          extras: track.toJson(),
          start: _trimFor(_uriFor(track))?.start,
          end: _trimFor(_uriFor(track))?.end,
        );

  factory SonolythMedia.media(Media media) {
    assert(media.extras != null, "[Media] must have extra metadata set");
    return SonolythMedia(SonolythTrackObject.fromJson(media.extras!));
  }
}

abstract class AudioPlayerInterface {
  final CustomPlayer _mkPlayer;

  /// Owns the optional second deck used for crossfading. While crossfade is
  /// off it stays dormant and every call passes straight through to
  /// [_mkPlayer]; while it's on, it briefly runs a second deck carrying the
  /// outgoing track's tail. [_mkPlayer] is the current track either way.
  late final CrossfadeEngine _engine;

  static const mk.PlayerConfiguration _playerConfiguration =
      mk.PlayerConfiguration(
    title: "Sonolyth",
    logLevel: kDebugMode ? mk.MPVLogLevel.info : mk.MPVLogLevel.error,
    async: true,
  );

  AudioPlayerInterface() : _mkPlayer = CustomPlayer(
          configuration: _playerConfiguration,
        ) {
    _mkPlayer.stream.error.listen((event) {
      AppLogger.reportError(event, StackTrace.current);
    });

    _engine = CrossfadeEngine(
      mainPlayer: _mkPlayer,
      shadowFactory: () async {
        final deck = CustomPlayer(
          configuration: _playerConfiguration,
          isShadow: true,
        );
        deck.stream.error.listen((event) {
          AppLogger.reportError(event, StackTrace.current);
        });
        // Share the main player's Android audio session so the system
        // equalizer keeps applying while the shadow deck is audible.
        await deck.attachToAudioSession(
          await _mkPlayer.androidAudioSessionIdFuture,
        );
        return deck;
      },
    );
  }

  /// Whether the current platform supports the audioplayers plugin
  static const bool _mkSupportedPlatform = true;

  bool get mkSupportedPlatform => _mkSupportedPlatform;

  Duration get duration {
    return _mkPlayer.state.duration;
  }

  Playlist get playlist {
    return _mkPlayer.state.playlist;
  }

  Duration get position {
    return _mkPlayer.state.position;
  }

  Duration get bufferedPosition {
    return _mkPlayer.state.buffer;
  }

  Future<mk.AudioDevice> get selectedDevice async {
    return _mkPlayer.state.audioDevice;
  }

  Future<List<mk.AudioDevice>> get devices async {
    return _mkPlayer.state.audioDevices;
  }

  bool get hasSource {
    return _mkPlayer.state.playlist.medias.isNotEmpty;
  }

  // states
  bool get isPlaying {
    return _mkPlayer.state.playing;
  }

  bool get isPaused {
    return !_mkPlayer.state.playing;
  }

  bool get isStopped {
    return !hasSource;
  }

  Future<bool> get isCompleted async {
    return _mkPlayer.state.completed;
  }

  bool get isShuffled {
    return _mkPlayer.shuffled;
  }

  PlaylistMode get loopMode {
    return _mkPlayer.state.playlistMode;
  }

  /// Returns the current volume of the player, between 0 and 1.
  ///
  /// This is the volume the USER set — mid-crossfade the decks sit at
  /// transient fade gains, which are an implementation detail nothing outside
  /// the engine should observe (the Connect clients mirror this value, and
  /// the ducking logic multiplies it).
  double get volume {
    return _engine.userVolume;
  }

  bool get isBuffering {
    return _mkPlayer.state.buffering;
  }

  /// Length of the crossfade between tracks; [Duration.zero] disables it.
  Duration get crossfadeDuration => _engine.fadeDuration;
}
