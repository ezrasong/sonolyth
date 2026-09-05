import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';

/// What the play button does while §43's gate is holding a queue out of mpv
/// (CONTEXT item 65).
///
/// `resume()` is a no-op there — mpv's playlist is empty — so the transport
/// was the one control on the player that neither worked nor said why. It
/// runs the verify dialog instead, and the queue is marked to *start* rather
/// than merely be handed over, because `resumeDeferredQueue` replays the
/// intent the queue was deferred with.
///
/// Both failures this can have are ordering, which is why the sequence is a
/// static and these are the tests for it: mark after the dialog and a grant
/// lands on the old intent (the queue arrives paused, a second dead press);
/// leave the mark set after a cancel and the launch warm-up or the keep-alive
/// self-heal starts music minutes later with nobody's finger near the app.
void main() {
  /// A stand-in for `_deferredQueue`, recording every write in order so the
  /// tests can assert on *when* the mark was set, not just where it ended up.
  ({bool autoPlay})? field;
  late List<({bool autoPlay})?> writes;

  void write(({bool autoPlay})? value) {
    field = value;
    writes.add(value);
  }

  setUp(() {
    field = null;
    writes = [];
  });

  group('AudioPlayerNotifier.runDeferredPlay', () {
    test('does nothing at all when no queue is deferred', () async {
      // The ordinary press: the button resumes and never reaches here, so a
      // stray write would arm a gate over a playing queue.
      var verified = false;
      await AudioPlayerNotifier.runDeferredPlay(
        read: () => field,
        write: write,
        verify: () async => verified = true,
      );

      expect(writes, isEmpty);
      expect(verified, isFalse, reason: 'nothing to verify for');
    });

    test('marks the queue to autoplay *before* running the verify', () async {
      field = (autoPlay: false);
      ({bool autoPlay})? seenByVerify;

      await AudioPlayerNotifier.runDeferredPlay(
        read: () => field,
        write: write,
        verify: () async => seenByVerify = field,
      );

      // The whole point: a grant arriving inside `verify` reads the intent,
      // and it has to read the press, not the launch that deferred the queue.
      expect(seenByVerify, (autoPlay: true));
    });

    test('leaves the handed-over queue alone when the grant lands', () async {
      field = (autoPlay: false);

      await AudioPlayerNotifier.runDeferredPlay(
        read: () => field,
        write: write,
        // What `resumeDeferredQueue` does once it has opened the playlist.
        verify: () async => write(null),
      );

      expect(field, isNull);
      expect(
        writes,
        [(autoPlay: true), null],
        reason: 'nothing may be written back over the cleared flag',
      );
    });

    test('puts the old intent back when the dialog is cancelled', () async {
      field = (autoPlay: false);

      await AudioPlayerNotifier.runDeferredPlay(
        read: () => field,
        write: write,
        verify: () async {},
      );

      expect(field, (autoPlay: false));
    });

    test('puts a play-deferred intent back as a play-deferred intent',
        () async {
      // The queue was deferred *from a play action*, so it was already going
      // to start; a cancelled press must not quietly downgrade that.
      field = (autoPlay: true);

      await AudioPlayerNotifier.runDeferredPlay(
        read: () => field,
        write: write,
        verify: () async {},
      );

      expect(field, (autoPlay: true));
    });

    test('puts the intent back when the verify throws', () async {
      field = (autoPlay: false);

      await expectLater(
        AudioPlayerNotifier.runDeferredPlay(
          read: () => field,
          write: write,
          verify: () async => throw StateError('gateway down'),
        ),
        throwsStateError,
      );

      // A gateway that fails mid-dialog is the same "not now" as a cancel:
      // without the `finally` the mark survives and plays later, unasked.
      expect(field, (autoPlay: false));
    });
  });
}
