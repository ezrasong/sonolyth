import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What Sonolyth asks Qobuz and TIDAL for when it **streams**.
///
/// Deliberately separate from the per-provider download quality in
/// `download_settings.dart`. The two answer different questions: a download is
/// kept, so it wants the best the catalog has; a stream is heard once and
/// costs mobile data every time, so it wants the smallest thing that still
/// sounds right. Until now the streaming side was two hardcoded constants
/// (Qobuz `"6"`, TIDAL `"LOSSLESS"`) with no way to change either.
enum StreamingQuality {
  /// 24-bit, up to 96kHz. Roughly two to five times the bytes of [lossless]
  /// for a difference most people cannot hear on a phone.
  hiRes(
    id: "hi-res",
    qobuzCode: "7",
    tidalTier: "HI_RES_LOSSLESS",
    lossy: false,
    bitDepth: 24,
    sampleRate: 96000,
  ),

  /// 16-bit / 44.1kHz FLAC. CD quality, and the default: it is what the
  /// hardcoded constants used to be, so nobody's playback changes on upgrade.
  lossless(
    id: "lossless",
    qobuzCode: "6",
    tidalTier: "LOSSLESS",
    lossy: false,
    bitDepth: 16,
    sampleRate: 44100,
  ),

  /// Lossy, about 320kbps: MP3 from Qobuz, AAC from TIDAL. Roughly a third of
  /// the data of [lossless].
  ///
  /// **This tier can silently not happen**, and that is by design. Neither
  /// catalog is contractually obliged to hand a lossy tier to this gateway,
  /// and if it refuses, the provider's fallback chain drops to [lossless]
  /// rather than failing playback. The player's meta chip reads the stream
  /// that was actually resolved, not the tier that was asked for, so a
  /// refusal shows up as "flac" on screen rather than as a quiet lie.
  dataSaver(
    id: "data-saver",
    qobuzCode: "5",
    tidalTier: "HIGH",
    lossy: true,
    bitDepth: null,
    sampleRate: null,
  );

  const StreamingQuality({
    required this.id,
    required this.qobuzCode,
    required this.tidalTier,
    required this.lossy,
    required this.bitDepth,
    required this.sampleRate,
  });

  /// Stable identifier, persisted. Never rename one of these: the stored value
  /// is matched against it and an unknown id falls back to [lossless].
  final String id;

  /// Qobuz `format_id`, as [QobuzProvider] maps it to a gateway quality name.
  final String qobuzCode;

  /// TIDAL's own tier constant, sent to the gateway verbatim.
  final String tidalTier;

  /// Whether this tier may come back as something other than FLAC.
  final bool lossy;

  /// What a stream at this tier carries, when it is lossless. Null for
  /// [dataSaver], where the answer depends on what the catalog actually
  /// served and is read off the response instead of assumed.
  final int? bitDepth;
  final int? sampleRate;

  static StreamingQuality byId(String? id) => values.firstWhere(
        (q) => q.id == id,
        orElse: () => StreamingQuality.lossless,
      );
}

/// The stored streaming tier, readable synchronously from anywhere.
///
/// A static rather than something plumbed through `Ref` because
/// `SourcedTrack._resolveStreams` is a **static** with no ref to read from,
/// and threading one through every call site to carry a single enum would be
/// a worse change than this. The same shape `ZarzSession` already uses for its
/// own preference-backed state.
abstract final class StreamingQualityStore {
  static const _prefsKey = "spotiflac-streaming-quality";

  static StreamingQuality _current = StreamingQuality.lossless;

  /// The tier to ask for right now.
  ///
  /// Before [load] has completed this is [StreamingQuality.lossless], which is
  /// the pre-existing behaviour — so the launch window resolves exactly as it
  /// always did rather than briefly asking for something the user did not
  /// choose.
  static StreamingQuality get current => _current;

  static Future<StreamingQuality> load() async {
    final prefs = await SharedPreferences.getInstance();
    _current = StreamingQuality.byId(prefs.getString(_prefsKey));
    return _current;
  }

  static Future<void> save(StreamingQuality quality) async {
    _current = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, quality.id);
  }
}

class StreamingQualityNotifier extends AsyncNotifier<StreamingQuality> {
  @override
  Future<StreamingQuality> build() => StreamingQualityStore.load();

  Future<void> set(StreamingQuality quality) async {
    await StreamingQualityStore.save(quality);
    state = AsyncData(quality);
  }
}

final streamingQualityProvider =
    AsyncNotifierProvider<StreamingQualityNotifier, StreamingQuality>(
  StreamingQualityNotifier.new,
);
