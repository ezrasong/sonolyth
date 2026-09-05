import 'dart:async';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:audio_session/audio_session.dart';
// ignore: implementation_imports
import 'package:sonolyth/services/audio_player/playback_state.dart';
import 'package:sonolyth/utils/platform.dart';

/// MediaKit [Player] by default doesn't have a state stream.
/// This class adds a state stream to the [Player] class.
class CustomPlayer extends Player {
  final StreamController<AudioPlaybackState> _playerStateStream;

  late final List<StreamSubscription> _subscriptions;

  /// Shadow decks (the crossfade engine's second player) piggyback on the
  /// main player's Android audio session instead of generating/broadcasting
  /// their own, so the system equalizer applies to whichever deck is audible.
  final bool isShadow;

  int _androidAudioSessionId = 0;
  final Completer<int?> _androidAudioSessionIdCompleter = Completer();
  String _packageName = "";
  AndroidAudioManager? _androidAudioManager;

  /// Resolves to this player's Android audio session id once it has been
  /// generated and applied (null on other platforms and on shadow decks).
  Future<int?> get androidAudioSessionIdFuture =>
      _androidAudioSessionIdCompleter.future;

  CustomPlayer({super.configuration, this.isShadow = false})
      : _playerStateStream = StreamController.broadcast() {
    nativePlayer.setProperty("network-timeout", "120");
    // Keep a generous decode-ahead so a brief network dip drains the demuxer
    // cache instead of stalling the audio.
    nativePlayer.setProperty("cache", "yes");
    nativePlayer.setProperty("demuxer-readahead-secs", "30");
    // How much has to be re-buffered before audio resumes after the cache
    // runs dry. This was 2 seconds, which is fine for a network dip in the
    // middle of a track and **wrong for a seek**: dropping the demuxer cache
    // is exactly what a seek does, so every scrub into un-buffered audio
    // bought two seconds of silence on top of the fetch itself — the "pause
    // before it starts again after scrubbing". Half a second of lossless is
    // ~60 KB, quick to refill, and still enough not to resume straight into
    // another starve.
    nativePlayer.setProperty("cache-pause-wait", "0.5");
    // Seeking backwards should never touch the network: keep the bytes
    // already played in the cache so a scrub back into the last half-minute
    // is served from memory. (`setDemuxerBufferSize` keeps this in step with
    // the forward cache; this is the floor before a quality preset lands.)
    nativePlayer.setProperty("demuxer-max-back-bytes", "4194304");
    // Reuse the audio output across track boundaries so an album plays
    // gaplessly. Deliberately "weak", not "yes": "yes" would also keep the
    // output open across a sample-format change (44.1k FLAC -> 48k Opus),
    // which requires pinning + resampling the output and gives up bit-perfect
    // lossless. Gapless matters within an album, and albums are
    // format-homogeneous; the crossfade engine covers the mixed-format case.
    nativePlayer.setProperty("gapless-audio", "weak");
    if (!isShadow) {
      // Open + buffer the next playlist entry while the current one plays so
      // track changes start instantly instead of waiting on the stream setup.
      // (A shadow deck only ever holds a single entry — nothing to prefetch.)
      nativePlayer.setProperty("prefetch-playlist", "yes");
    }

    _subscriptions = [
      stream.buffering.listen((event) {
        _playerStateStream.add(AudioPlaybackState.buffering);
      }),
      stream.playing.listen((playing) {
        if (playing) {
          _playerStateStream.add(AudioPlaybackState.playing);
        } else {
          _playerStateStream.add(AudioPlaybackState.paused);
        }
      }),
      stream.completed.listen((isCompleted) async {
        if (!isCompleted) return;
        _playerStateStream.add(AudioPlaybackState.completed);
      }),
      stream.playlist.listen((event) {
        if (event.medias.isEmpty) {
          _playerStateStream.add(AudioPlaybackState.stopped);
        }
      }),
      stream.error.listen((event) {
        AppLogger.reportError('[MediaKitError] \n$event', StackTrace.current);
      }),
    ];
    PackageInfo.fromPlatform().then((packageInfo) {
      _packageName = packageInfo.packageName;
    });
    if (kIsAndroid && !isShadow) {
      _androidAudioManager = AndroidAudioManager();
      AudioSession.instance.then((s) async {
        _androidAudioSessionId =
            await _androidAudioManager!.generateAudioSessionId();
        notifyAudioSessionUpdate(true);

        await nativePlayer.setProperty(
          "audiotrack-session-id",
          _androidAudioSessionId.toString(),
        );
        await nativePlayer.setProperty("ao", "audiotrack,opensles,");
        if (!_androidAudioSessionIdCompleter.isCompleted) {
          _androidAudioSessionIdCompleter.complete(_androidAudioSessionId);
        }
      });
    } else if (!_androidAudioSessionIdCompleter.isCompleted) {
      _androidAudioSessionIdCompleter.complete(null);
    }
  }

  /// Binds a shadow deck to the main player's audio session, so effects
  /// (system equalizer, loudness enhancer) attached to that session keep
  /// applying while the shadow deck is the audible one. Broadcasting a second
  /// OPEN_AUDIO_EFFECT_CONTROL_SESSION is deliberately skipped — the session
  /// is already open and owned by the main player.
  Future<void> attachToAudioSession(int? sessionId) async {
    if (!kIsAndroid || sessionId == null) return;
    _androidAudioSessionId = sessionId;
    await nativePlayer.setProperty(
      "audiotrack-session-id",
      sessionId.toString(),
    );
    await nativePlayer.setProperty("ao", "audiotrack,opensles,");
  }

  Future<void> notifyAudioSessionUpdate(bool active) async {
    if (isShadow) return;
    if (kIsAndroid) {
      sendBroadcast(
        BroadcastMessage(
          name: active
              ? "android.media.action.OPEN_AUDIO_EFFECT_CONTROL_SESSION"
              : "android.media.action.CLOSE_AUDIO_EFFECT_CONTROL_SESSION",
          data: {
            "android.media.extra.AUDIO_SESSION": _androidAudioSessionId,
            "android.media.extra.PACKAGE_NAME": _packageName
          },
        ),
      );
    }
  }

  bool get shuffled => state.shuffle;

  Stream<AudioPlaybackState> get playerStateStream => _playerStateStream.stream;
  Stream<bool> get shuffleStream => stream.shuffle;
  Stream<int> get indexChangeStream {
    int oldIndex = state.playlist.index;
    return stream.playlist.map((event) => event.index).where((newIndex) {
      if (newIndex != oldIndex) {
        oldIndex = newIndex;
        return true;
      }
      return false;
    });
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    await super.setShuffle(shuffle);
  }

  @override
  Future<void> stop() async {
    await super.stop();

    _playerStateStream.add(AudioPlaybackState.stopped);
  }

  @override
  Future<void> dispose() async {
    for (var element in _subscriptions) {
      element.cancel();
    }
    await notifyAudioSessionUpdate(false);
    return super.dispose();
  }

  NativePlayer get nativePlayer => platform as NativePlayer;

  Future<void> insert(int index, Media media) async {
    final addedMediaCompleter = Completer<int>();
    final playlistStream = stream.playlist.listen(
      (event) {
        final mediaAddedIndex =
            event.medias.indexWhere((m) => m.uri == media.uri);
        if (mediaAddedIndex != -1 && !addedMediaCompleter.isCompleted) {
          addedMediaCompleter.complete(mediaAddedIndex);
        }
      },
    );
    try {
      await add(media);
      final mediaAddedIndex = await addedMediaCompleter.future;
      await move(mediaAddedIndex, index);
    } finally {
      playlistStream.cancel();
    }
  }

  Future<void> setAudioNormalization(bool normalize) async {
    if (normalize) {
      await nativePlayer.setProperty('af', 'dynaudnorm=g=5:f=250:r=0.9:p=0.5');
    } else {
      await nativePlayer.setProperty('af', '');
    }
  }

  Future<void> setDemuxerBufferSize(int sizeInBytes) async {
    await nativePlayer.setProperty('demuxer-max-bytes', sizeInBytes.toString());
    await nativePlayer.setProperty(
      'demuxer-max-back-bytes',
      sizeInBytes.toString(),
    );
  }
}
