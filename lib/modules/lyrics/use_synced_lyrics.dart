import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonolyth/modules/lyrics/active_lyric_line.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// The second (a key of [lyricsMap]) of the lyric line playback is on, or `-1`
/// when no line has been reached yet.
///
/// The active line is the latest stamp at or before `position + delay`, so a
/// seek, a coarse position tick or a stamp between two ticks all still land on
/// the right line. It is recomputed from the live position whenever
/// [lyricsMap] or [delay] changes — which is what a track change is — so the
/// previous track's second cannot stay lit into the next one. The old
/// `containsKey` match only ever moved on an exact whole-second hit and never
/// reset, so after a track change the stale second stayed highlighted (and if
/// the new track had a line at that same second, that line lit up at 0:00)
/// until the new track happened to hit a stamp exactly.
int useSyncedLyrics(
  WidgetRef ref,
  Map<int, String> lyricsMap,
  int delay,
) {
  final currentTime = useState(-1);

  useEffect(() {
    int resolve(Duration position) =>
        activeLyricSecond(lyricsMap, position, delay: delay);

    // Seed from where playback is right now: a page opened mid-track, or a
    // map that just changed under a playing track, should not wait for the
    // next position event.
    currentTime.value = resolve(audioPlayer.position);

    return audioPlayer.positionStream.listen((position) {
      try {
        final next = resolve(position);
        if (next != currentTime.value) currentTime.value = next;
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    }).cancel;
  }, [lyricsMap, delay]);

  return currentTime.value;
}
