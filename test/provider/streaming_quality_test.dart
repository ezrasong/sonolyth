import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/provider/spotiflac/streaming_quality.dart';

/// The streaming tier, which until now was two hardcoded constants with no way
/// to change either: Qobuz `"6"` and TIDAL `"LOSSLESS"`.
///
/// What these pin is the pair of properties the feature rests on. **The
/// default is what the app already did**, so nobody's playback changes on
/// upgrade and no launch window quietly asks for something the user did not
/// choose. And **only the data-saver tier is lossy**, because that flag is
/// what opens TIDAL's container and audioQuality guards, which exist to stop a
/// download writing AAC under a `.flac` name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the tiers', () {
    test('lossless is the default, and is the old hardcoded pair', () {
      expect(StreamingQuality.lossless.qobuzCode, "6");
      expect(StreamingQuality.lossless.tidalTier, "LOSSLESS");
      expect(StreamingQualityStore.current, StreamingQuality.lossless);
    });

    test('only data saver is lossy', () {
      // The flag is not cosmetic: it is what `TidalProvider.streamUrlForId`
      // takes as `allowLossy`, and a wrong `true` would let a download accept
      // AAC and write it under a .flac name.
      expect(
        StreamingQuality.values.where((q) => q.lossy),
        [StreamingQuality.dataSaver],
      );
    });

    test('a lossless tier knows what it carries, a lossy one does not', () {
      // bitDepth/sampleRate describe the stream in the player's meta chip.
      // Data saver cannot answer up front: what comes back depends on whether
      // the catalog served the lossy tier at all.
      expect(StreamingQuality.lossless.bitDepth, 16);
      expect(StreamingQuality.lossless.sampleRate, 44100);
      expect(StreamingQuality.hiRes.bitDepth, 24);
      expect(StreamingQuality.dataSaver.bitDepth, isNull);
      expect(StreamingQuality.dataSaver.sampleRate, isNull);
    });

    test('every tier has a distinct id and code', () {
      expect(
        StreamingQuality.values.map((q) => q.id).toSet().length,
        StreamingQuality.values.length,
      );
      expect(
        StreamingQuality.values.map((q) => q.qobuzCode).toSet().length,
        StreamingQuality.values.length,
      );
    });
  });

  group('byId', () {
    test('round-trips every tier', () {
      for (final quality in StreamingQuality.values) {
        expect(StreamingQuality.byId(quality.id), quality);
      }
    });

    test('falls back to lossless, never to a lossy or hi-res surprise', () {
      // A value written by a future version, or a corrupt one. Neither may
      // start costing the user data they did not agree to.
      expect(StreamingQuality.byId(null), StreamingQuality.lossless);
      expect(StreamingQuality.byId(""), StreamingQuality.lossless);
      expect(StreamingQuality.byId("studio-master"), StreamingQuality.lossless);
    });
  });

  group('the store', () {
    test('reads lossless when nothing has been chosen', () async {
      expect(await StreamingQualityStore.load(), StreamingQuality.lossless);
    });

    test('saves, and makes the choice readable synchronously', () async {
      await StreamingQualityStore.save(StreamingQuality.dataSaver);

      // Synchronously is the point: `SourcedTrack._resolveStreams` is a static
      // with no ref and no place to await from.
      expect(StreamingQualityStore.current, StreamingQuality.dataSaver);
      expect(await StreamingQualityStore.load(), StreamingQuality.dataSaver);
    });

    test('survives a reload from disk', () async {
      await StreamingQualityStore.save(StreamingQuality.hiRes);
      // Force the store to answer from storage rather than its cache.
      await StreamingQualityStore.save(StreamingQuality.lossless);
      SharedPreferences.setMockInitialValues({
        "flutter.spotiflac-streaming-quality": "hi-res",
      });

      expect(await StreamingQualityStore.load(), StreamingQuality.hiRes);
    });
  });
}
