part of 'audio_player.dart';

mixin SonolythAudioPlayersStreams on AudioPlayerInterface {
  // Every stream here reads the main player. The crossfade engine's second
  // deck only ever carries the tail of a track main has already moved on
  // from, so the main player is always the current track — no consumer (UI,
  // media notification, Connect clients, scrobbling, prefetch) has to know a
  // crossfade is in progress.

  // stream getters
  Stream<Duration> get durationStream {
    return _mkPlayer.stream.duration;
  }

  Stream<Duration> get positionStream {
    return _mkPlayer.stream.position;
  }

  Stream<Duration> get bufferedPositionStream {
    return _mkPlayer.stream.buffer;
  }

  Stream<void> get completedStream {
    return _mkPlayer.stream.completed;
  }

  /// Stream that emits when the player is almost (%) complete
  Stream<int> percentCompletedStream(double percent) {
    return positionStream
        .asyncMap(
          (position) async => duration == Duration.zero
              ? 0
              : (position.inSeconds / duration.inSeconds * 100).toInt(),
        )
        .where((event) => event >= percent);
  }

  Stream<bool> get playingStream {
    return _mkPlayer.stream.playing;
  }

  Stream<bool> get shuffledStream {
    // if (mkSupportedPlatform) {
    return _mkPlayer.shuffleStream;
    // } else {
    //   return _justAudio!.shuffleModeEnabledStream;
    // }
  }

  Stream<PlaylistMode> get loopModeStream {
    // if (mkSupportedPlatform) {
    return _mkPlayer.stream.playlistMode;
    // } else {
    //   return _justAudio!.loopModeStream
    //       .map(PlaylistMode.fromLoopMode)
    //       ;
    // }
  }

  /// The volume the USER set, not the decks' momentary output gain — during
  /// a crossfade both decks ride a fade ramp that no consumer should mirror.
  Stream<double> get volumeStream {
    return _engine.userVolumeStream;
  }

  Stream<bool> get bufferingStream {
    // if (mkSupportedPlatform) {
    return Stream.value(false);
    // } else {
    //   return _justAudio!.playerStateStream
    //       .map(
    //         (event) =>
    //             event.processingState == ja.ProcessingState.buffering ||
    //             event.processingState == ja.ProcessingState.loading,
    //       )
    //       ;
    // }
  }

  Stream<AudioPlaybackState> get playerStateStream {
    return _mkPlayer.playerStateStream;
  }

  Stream<int> get currentIndexChangedStream {
    // if (mkSupportedPlatform) {
    return _mkPlayer.indexChangeStream;
    // } else {
    //   return _justAudio!.sequenceStateStream
    //       .map((event) => event?.currentIndex ?? -1)
    //       ;
    // }
  }

  Stream<String> get activeSourceChangedStream {
    // if (mkSupportedPlatform) {
    return _mkPlayer.indexChangeStream
        .map((event) {
          return _mkPlayer.state.playlist.medias.elementAtOrNull(event)?.uri;
        })
        .where((event) => event != null)
        .cast<String>();
    // } else {
    //   return _justAudio!.sequenceStateStream
    //       .map((event) {
    //         return (event?.currentSource as ja.UriAudioSource?)?.uri.toString();
    //       })
    //       .where((event) => event != null)
    //       .cast<String>();
    // }
  }

  Stream<List<mk.AudioDevice>> get devicesStream =>
      _mkPlayer.stream.audioDevices.asBroadcastStream();

  Stream<mk.AudioDevice> get selectedDeviceStream =>
      _mkPlayer.stream.audioDevice.asBroadcastStream();

  Stream<String> get errorStream => _mkPlayer.stream.error;

  Stream<mk.Playlist> get playlistStream => _mkPlayer.stream.playlist;
}
