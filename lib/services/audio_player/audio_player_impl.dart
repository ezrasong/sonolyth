part of 'audio_player.dart';

final audioPlayer = SonolythAudioPlayer();

class SonolythAudioPlayer extends AudioPlayerInterface
    with SonolythAudioPlayersStreams {
  Future<void> pause() async {
    await _engine.pause();
  }

  Future<void> resume() async {
    await _engine.resume();
  }

  Future<void> stop() async {
    // Drop the shadow deck before stopping: the queue is being torn down, so
    // there is nothing left to cross-fade into and the engine must go back to
    // its dormant single-player state.
    await _engine.reset();
    await _mkPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
  }

  /// Volume is between 0 and 1
  Future<void> setVolume(double volume) async {
    assert(volume >= 0 && volume <= 1);
    await _engine.setUserVolume(volume);
  }

  Future<void> setSpeed(double speed) async {
    await _engine.applyToDecks((deck) => deck.setRate(speed));
  }

  Future<void> setAudioDevice(mk.AudioDevice device) async {
    await _engine.applyToDecks((deck) => deck.setAudioDevice(device));
  }

  /// Length of the crossfade between tracks. [Duration.zero] turns crossfading
  /// off entirely, which leaves playback on the single main player exactly as
  /// it behaves without the engine.
  Future<void> setCrossfadeDuration(Duration duration) async {
    await _engine.setFadeDuration(duration);
  }

  Future<void> setCrossfadeCurve(CrossfadeCurve curve) async {
    _engine.curve = curve;
  }

  Future<void> dispose() async {
    await _engine.dispose();
    await _mkPlayer.dispose();
  }

  // Playlist related

  Future<void> openPlaylist(
    List<mk.Media> tracks, {
    bool autoPlay = true,
    int initialIndex = 0,
  }) async {
    assert(tracks.isNotEmpty);
    assert(initialIndex <= tracks.length - 1);
    // A new queue replaces whatever the decks were doing; park the engine so
    // playback restarts cleanly on the main player.
    await _engine.reset();
    await _mkPlayer.open(
      mk.Playlist(tracks, index: initialIndex),
      play: autoPlay,
    );
  }

  List<String> get sources {
    return _mkPlayer.state.playlist.medias.map((e) => e.uri).toList();
  }

  String? get currentSource {
    if (_mkPlayer.state.playlist.index == -1) return null;
    return _mkPlayer.state.playlist.medias
        .elementAtOrNull(_mkPlayer.state.playlist.index)
        ?.uri;
  }

  String? get nextSource {
    if (loopMode == PlaylistMode.loop &&
        _mkPlayer.state.playlist.index ==
            _mkPlayer.state.playlist.medias.length - 1) {
      return sources.first;
    }

    return _mkPlayer.state.playlist.medias
        .elementAtOrNull(_mkPlayer.state.playlist.index + 1)
        ?.uri;
  }

  String? get previousSource {
    if (loopMode == PlaylistMode.loop && _mkPlayer.state.playlist.index == 0) {
      return sources.last;
    }

    return _mkPlayer.state.playlist.medias
        .elementAtOrNull(_mkPlayer.state.playlist.index - 1)
        ?.uri;
  }

  int get currentIndex => _mkPlayer.state.playlist.index;

  Future<void> skipToNext() async {
    await _engine.skipToNext();
  }

  /// How far into a track "previous" still means *the previous track*.
  /// Past this it restarts the track you are listening to, which is what
  /// every other player does — and what you actually want when you press it
  /// to hear a verse again.
  static const restartInsteadOfPreviousAfter = Duration(seconds: 5);

  Future<void> skipToPrevious() async {
    final position = _mkPlayer.state.position;
    // With nothing before this track, "previous" can only mean "start it
    // again" — it used to be a no-op, so the button did nothing at all on
    // the first track of a queue.
    final hasPrevious = _mkPlayer.state.playlist.index > 0 ||
        _mkPlayer.state.playlistMode == mk.PlaylistMode.loop;
    AppLogger.diag(
      "[prev] position=${position.inMilliseconds}ms index="
      "${_mkPlayer.state.playlist.index} hasPrevious=$hasPrevious",
    );
    if (position > restartInsteadOfPreviousAfter || !hasPrevious) {
      await seek(Duration.zero);
      return;
    }
    await _engine.skipToPrevious();
  }

  Future<void> jumpTo(int index) async {
    await _engine.jumpTo(index);
  }

  Future<void> addTrack(mk.Media media) async {
    await _mkPlayer.add(media);
  }

  Future<void> addTrackAt(mk.Media media, int index) async {
    await _mkPlayer.insert(index, media);
  }

  Future<void> removeTrack(int index) async {
    await _mkPlayer.remove(index);
  }

  Future<void> moveTrack(int from, int to) async {
    await _mkPlayer.move(from, to);
  }

  Future<void> clearPlaylist() async {
    await _engine.reset();
    _mkPlayer.stop();
  }

  Future<void> setShuffle(bool shuffle) async {
    await _mkPlayer.setShuffle(shuffle);
  }

  Future<void> setLoopMode(PlaylistMode loop) async {
    await _mkPlayer.setPlaylistMode(loop);
  }

  Future<void> setAudioNormalization(bool normalize) async {
    await _engine.applyToDecks(
      (deck) => deck.setAudioNormalization(normalize),
    );
  }

  Future<void> setDemuxerBufferSize(int sizeInBytes) async {
    await _engine.applyToDecks(
      (deck) => deck.setDemuxerBufferSize(sizeInBytes),
    );
  }
}
