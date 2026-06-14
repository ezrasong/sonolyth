import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/providers/qobuz_provider.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';

/// Playback resolves must fail fast and fall back to YouTube rather than block
/// on the gateway's patient, download-oriented retry/backoff (up to ~35s). A
/// dedicated fail-fast client (no 429 retries) also gives playback its own
/// pacing lane, so a resolve isn't queued behind a bulk download.
final _playbackZarzClient = ZarzClient(maxAttempts: 1);

/// A native (non-plugin) playback audio source backed by Qobuz via the zarz
/// gateway.
///
/// Unlike the YouTube audio-source plugin — which scores fuzzy title/duration
/// matches and can land on the wrong upload (live/sped-up/cover) — Qobuz
/// resolves by ISRC, so the match is the *exact* recording, with correct
/// tagging, served as a direct unencrypted lossless FLAC stream.
///
/// It is intentionally Qobuz-only: Deezer's CDN stream is Blowfish-encrypted
/// and can't be handed straight to the player without an on-the-fly decrypting
/// proxy, so it stays download-only for now.
class QobuzAudioSource {
  /// Stable slug used to namespace this source's cached matches and presets.
  static const slug = "qobuz";

  /// Marks a match as Qobuz-sourced so stream resolution can route back here
  /// (vs. falling through to the YouTube plugin) without a separate source
  /// field on the shared, plugin-serialized match model.
  static const externalUriPrefix = "https://open.qobuz.com/track/";

  /// Streaming uses CD-lossless (16-bit/44.1kHz, Qobuz quality "6") for a fast
  /// start and modest bandwidth — still lossless, but a fraction of the bytes
  /// of 24-bit hi-res, which keeps playback instant. Downloads keep their own
  /// (higher) per-provider quality from the download settings.
  static const _streamingQuality = "6";

  final QobuzProvider _provider;

  QobuzAudioSource([QobuzProvider? provider])
      : _provider = provider ?? QobuzProvider(_playbackZarzClient);

  /// Whether [match] was produced by this source (and should be resolved here).
  static bool ownsMatch(SonolythAudioSourceMatchObject match) =>
      match.externalUri.startsWith(externalUriPrefix);

  /// ISRC-first candidate matches for [track], best first.
  Future<List<SonolythAudioSourceMatchObject>> matches(
    SonolythFullTrackObject track,
  ) async {
    final results = await _provider.searchTracks(track);
    return results
        .map(_toMatch)
        .whereType<SonolythAudioSourceMatchObject>()
        .toList();
  }

  /// Direct lossless FLAC stream(s) for a previously matched Qobuz track.
  /// Returns an empty list if the gateway can't resolve a URL, so the caller
  /// can fall back to the plugin source rather than hard-failing playback.
  Future<List<SonolythAudioSourceStreamObject>> streams(
    SonolythAudioSourceMatchObject match,
  ) async {
    final url = await _provider.streamUrlForId(match.id, _streamingQuality);
    if (url == null || url.isEmpty) return const [];

    return [
      SonolythAudioSourceStreamObject(
        url: url,
        container: "flac",
        type: SonolythMediaCompressionType.lossless,
        codec: "flac",
      ),
    ];
  }

  SonolythAudioSourceMatchObject? _toMatch(Map candidate) {
    final id = candidate["id"]?.toString();
    if (id == null || id.isEmpty) return null;

    final performer = candidate["performer"];
    final artistName = performer is Map ? performer["name"]?.toString() : null;

    final album = candidate["album"];
    final image = album is Map ? album["image"] : null;
    final thumbnail = image is Map
        ? (image["large"] ?? image["small"] ?? image["thumbnail"])?.toString()
        : null;

    final durationSeconds = (candidate["duration"] as num?)?.toInt() ?? 0;

    return SonolythAudioSourceMatchObject(
      id: id,
      title: candidate["title"]?.toString() ?? "",
      artists: [
        if (artistName != null && artistName.isNotEmpty) artistName,
      ],
      duration: Duration(seconds: durationSeconds),
      thumbnail: thumbnail,
      externalUri: "$externalUriPrefix$id",
    );
  }
}
