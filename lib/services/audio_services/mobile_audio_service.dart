import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/state.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:sonolyth/services/audio_player/playback_state.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/utils/platform.dart';

class MobileAudioService extends BaseAudioHandler {
  /// Custom notification actions (Android renders these as buttons; the
  /// standard setShuffleMode/setRepeatMode session actions get no button).
  static const _actionShuffle = 'sonolythShuffle';
  static const _actionRepeat = 'sonolythRepeat';

  AudioSession? session;
  final AudioPlayerNotifier audioPlayerNotifier;

  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  AudioPlayerState get playlist => audioPlayerNotifier.state;

  MobileAudioService(this.audioPlayerNotifier) {
    AudioSession.instance.then((s) {
      session = s;
      session?.configure(const AudioSessionConfiguration.music());

      bool wasPausedByBeginEvent = false;

      s.interruptionEventStream.listen((event) async {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await audioPlayer.setVolume(audioPlayer.volume / 2);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              {
                wasPausedByBeginEvent = audioPlayer.isPlaying;
                await audioPlayer.pause();
                break;
              }
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Restore the user's saved volume rather than forcing 100%.
              await audioPlayer.setVolume(KVStoreService.volume);
              break;
            case AudioInterruptionType.pause when wasPausedByBeginEvent:
            case AudioInterruptionType.unknown when wasPausedByBeginEvent:
              await audioPlayer.resume();
              wasPausedByBeginEvent = false;
              break;
            default:
              break;
          }
        }
      });

      s.becomingNoisyEventStream.listen((_) {
        audioPlayer.pause();
      });
    });
    audioPlayer.playerStateStream.listen((state) async {
      if (state == AudioPlaybackState.playing) {
        await session?.setActive(true);
      }
      playbackState.add(await _transformEvent());
    });

    audioPlayer.positionStream.listen((pos) async {
      playbackState.add(await _transformEvent());
    });
    audioPlayer.bufferedPositionStream.listen((pos) async {
      playbackState.add(await _transformEvent());
    });
    // Keep the notification's shuffle/repeat button icons in sync when the
    // modes are changed from inside the app.
    audioPlayer.shuffledStream.listen((_) async {
      playbackState.add(await _transformEvent());
    });
    audioPlayer.loopModeStream.listen((_) async {
      playbackState.add(await _transformEvent());
    });
  }

  void addItem(MediaItem item) {
    session?.setActive(true);
    mediaItem.add(item);
  }

  @override
  Future<void> play() => audioPlayer.resume();

  @override
  Future<void> pause() => audioPlayer.pause();

  @override
  Future<void> seek(Duration position) => audioPlayer.seek(position);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await super.setShuffleMode(shuffleMode);

    await audioPlayer.setShuffle(shuffleMode == AudioServiceShuffleMode.all);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await super.setRepeatMode(repeatMode);
    await audioPlayer.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group =>
        PlaylistMode.loop,
      AudioServiceRepeatMode.one => PlaylistMode.single,
      _ => PlaylistMode.none,
    });
  }

  @override
  Future<void> stop() async {
    await audioPlayerNotifier.stop();
    // The queue is empty now, so this broadcasts idle. That transition is
    // what makes the Android side deactivate the media session and tear the
    // notification state down; skipping it leaves the service half-alive
    // after a swipe-dismiss and the notification never reappears on the
    // next play.
    playbackState.add(await _transformEvent());
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    switch (name) {
      case _actionShuffle:
        await audioPlayer.setShuffle(audioPlayer.isShuffled != true);
      case _actionRepeat:
        await audioPlayer.setLoopMode(switch (audioPlayer.loopMode) {
          PlaylistMode.none => PlaylistMode.loop,
          PlaylistMode.loop => PlaylistMode.single,
          PlaylistMode.single => PlaylistMode.none,
        });
      default:
        return super.customAction(name, extras);
    }
    playbackState.add(await _transformEvent());
  }

  @override
  Future<void> skipToNext() async {
    await audioPlayer.skipToNext();
    await super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await audioPlayer.skipToPrevious();
    await super.skipToPrevious();
  }

  @override
  Future<void> onTaskRemoved() async {
    await audioPlayer.pause();
    if (kIsAndroid) {
      // While paused the notification is detached from the service
      // (androidStopForegroundOnPause), so exiting now would strand it:
      // pressing a button on that zombie notification boots a headless
      // engine whose main() used to die before runApp, and the next launch
      // attached to it as a permanently black screen. Broadcast idle —
      // without touching the persisted queue — so the platform side cancels
      // the notification, then give that round trip a beat before exiting.
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
  }

  Future<PlaybackState> _transformEvent() async {
    try {
      return PlaybackState(
        // Android 13+ renders every control as a button (up to five). The
        // transport trio sits centred, flanked by shuffle/repeat whose icons
        // carry a dot when active. Stop stays reachable as a system action
        // (Bluetooth/headset) without hogging a button slot.
        controls: [
          MediaControl.custom(
            androidIcon: audioPlayer.isShuffled == true
                ? 'drawable/sonolyth_shuffle_on'
                : 'drawable/sonolyth_shuffle',
            label: 'Shuffle',
            name: _actionShuffle,
          ),
          MediaControl.skipToPrevious,
          audioPlayer.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: switch (audioPlayer.loopMode) {
              PlaylistMode.loop => 'drawable/sonolyth_repeat_on',
              PlaylistMode.single => 'drawable/sonolyth_repeat_one_on',
              PlaylistMode.none => 'drawable/sonolyth_repeat',
            },
            label: 'Repeat',
            name: _actionRepeat,
          ),
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [1, 2, 3],
        playing: audioPlayer.isPlaying,
        updatePosition: audioPlayer.position,
        bufferedPosition: audioPlayer.bufferedPosition,
        shuffleMode: audioPlayer.isShuffled == true
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (audioPlayer.loopMode) {
          PlaylistMode.loop => AudioServiceRepeatMode.all,
          PlaylistMode.single => AudioServiceRepeatMode.one,
          _ => AudioServiceRepeatMode.none,
        },
        // An empty queue means the session ended (stop, swipe-dismiss): idle
        // tells the platform to release the media session/notification so a
        // later play() can recreate them from scratch.
        processingState: playlist.activeTrack == null
            ? AudioProcessingState.idle
            : audioPlayer.isBuffering
                ? AudioProcessingState.loading
                : AudioProcessingState.ready,
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      rethrow;
    }
  }
}
