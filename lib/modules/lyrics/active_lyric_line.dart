/// The key of [lyricsBySecond] for the line playback is on at [position], or
/// `-1` when no line has been reached yet.
///
/// A line is "reached" once `position + delay` (in whole seconds) is at or past
/// its stamp, and the latest such line wins — so a seek, a coarse position tick
/// or a stamp that falls between two ticks all still resolve to the right line.
/// Pure, so it can be tested without a player.
int activeLyricSecond(
  Map<int, String> lyricsBySecond,
  Duration position, {
  int delay = 0,
}) {
  final target = position.inSeconds + delay;
  var best = -1;
  for (final second in lyricsBySecond.keys) {
    if (second <= target && second > best) best = second;
  }
  return best;
}
