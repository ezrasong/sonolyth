import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';

/// The load-time gate that keeps a queue out of mpv while nothing in it could
/// be opened (§43, CONTEXT item 57).
///
/// mpv's answer to a failed open is `playlist-next`, and it cannot be told
/// otherwise. With lossless access unverified that turns a queue into a
/// machine that walks itself — a track every 7.5s before §42 held the stream
/// request open, one per ~100s after — and every step writes mpv's playlist
/// index into the database, so the saved place goes with it. §42 made mpv wait
/// at the far end; this is the near end, and it is the half that closes it.
///
/// The decision has to fail **open**, and that is what these pin. A wrong
/// `false` refuses to play a queue that would have worked — a far worse bug
/// than the one being fixed, and one that would only show up for the users
/// whose music never needed the gateway at all.
void main() {
  final album = SonolythSimpleAlbumObject(
    id: 'a1',
    name: 'Only U',
    externalUri: 'https://example.test/album',
    artists: const [],
    albumType: SonolythAlbumType.single,
  );

  SonolythFullTrackObject wireTrack() => SonolythFullTrackObject(
        id: 'wire-1',
        name: 'Only U',
        externalUri: 'https://example.test/track',
        album: album,
        durationMs: 210000,
        isrc: 'KRA401700001',
        explicit: false,
      );

  SonolythLocalTrackObject localTrack() => SonolythLocalTrackObject(
        id: 'local-1',
        name: 'tone',
        externalUri: '',
        album: album,
        durationMs: 30000,
        path: '/storage/emulated/0/Music/tone.flac',
      );

  group('AudioPlayerNotifier.mpvCanOpenTrack', () {
    test('holds a wire track back when no lossless source is usable', () {
      // The only case that is gated: every open would fail, so handing mpv the
      // playlist buys nothing and costs the user their place in it.
      expect(
        AudioPlayerNotifier.mpvCanOpenTrack(
          wireTrack(),
          isDownloaded: false,
          losslessUsable: false,
        ),
        isFalse,
      );
    });

    test('opens a wire track the moment a session is usable', () {
      expect(
        AudioPlayerNotifier.mpvCanOpenTrack(
          wireTrack(),
          isDownloaded: false,
          losslessUsable: true,
        ),
        isTrue,
      );
    });

    test('never holds back a local file', () {
      // A local file is read off disk; the gateway is not involved at any
      // point, so a blocked session must not stop a folder from playing.
      expect(
        AudioPlayerNotifier.mpvCanOpenTrack(
          localTrack(),
          isDownloaded: false,
          losslessUsable: false,
        ),
        isTrue,
      );
    });

    test('never holds back a downloaded track', () {
      // `_serveDownloadedFile` answers before any resolve is attempted, so a
      // fully downloaded queue plays with no session at all — the offline
      // case, and the one a careless gate would break.
      expect(
        AudioPlayerNotifier.mpvCanOpenTrack(
          wireTrack(),
          isDownloaded: true,
          losslessUsable: false,
        ),
        isTrue,
      );
    });
  });
}
