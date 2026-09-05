/// Shape of the gain ramps used while two tracks overlap during a crossfade.
///
/// Lives here (rather than beside the engine) so both the persisted
/// preference and the audio layer can name it without the database depending
/// on the player.
enum CrossfadeCurve {
  /// Gain moves linearly. The summed loudness dips ~3dB at the midpoint,
  /// which is audible on sustained material but keeps each track's own fade
  /// perfectly even.
  linear,

  /// Sine/cosine ramps whose squares sum to 1, so the perceived loudness
  /// stays constant across the overlap. The better default for music.
  equalPower;
}
