import 'dart:io';

import 'package:media_kit/media_kit.dart' hide Track;
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:sonolyth/services/audio_player/custom_player.dart';
import 'dart:async';

import 'package:media_kit/media_kit.dart' as mk;

import 'package:sonolyth/services/audio_player/playback_state.dart';
import 'package:sonolyth/utils/platform.dart';

part 'audio_players_streams_mixin.dart';
part 'audio_player_impl.dart';

class SonolythMedia extends mk.Media {
  static int serverPort = 0;

  /// Track id -> locally downloaded file path, mirrored from the downloaded
  /// tracks registry. Lets the constructor (synchronous, riverpod-free)
  /// prefer the on-disk file over the streaming server URL.
  static Map<String, String> downloadedPaths = const {};

  static String get _host =>
      kIsWindows ? "localhost" : InternetAddress.anyIPv4.address;

  static String _uriFor(SonolythTrackObject track) {
    if (track is SonolythLocalTrackObject) return track.path;
    final downloaded = downloadedPaths[track.id];
    if (downloaded != null && File(downloaded).existsSync()) {
      return downloaded;
    }
    return "http://$_host:$serverPort/stream/${track.id}";
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
        );

  factory SonolythMedia.media(Media media) {
    assert(media.extras != null, "[Media] must have extra metadata set");
    return SonolythMedia(SonolythTrackObject.fromJson(media.extras!));
  }
}

abstract class AudioPlayerInterface {
  final CustomPlayer _mkPlayer;

  AudioPlayerInterface()
      : _mkPlayer = CustomPlayer(
          configuration: const mk.PlayerConfiguration(
            title: "Sonolyth",
            logLevel: kDebugMode ? mk.MPVLogLevel.info : mk.MPVLogLevel.error,
            async: true,
          ),
        ) {
    _mkPlayer.stream.error.listen((event) {
      AppLogger.reportError(event, StackTrace.current);
    });
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

  /// Returns the current volume of the player, between 0 and 1
  double get volume {
    return _mkPlayer.state.volume / 100;
  }

  bool get isBuffering {
    return _mkPlayer.state.buffering;
  }
}
