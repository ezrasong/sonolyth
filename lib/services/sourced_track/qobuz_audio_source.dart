import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/providers/qobuz_provider.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';

/// Playback gets its own gateway lane, tuned for interactivity rather than the
/// download client's patient, serialized pacing:
/// - **Concurrent + gap-free** (`maxConcurrent`, no 2.1s throttle) so warming
///   the next few tracks resolves in parallel — that overlap is what keeps
///   FLAC skip-forward/back from lagging. The gateway tolerates these bursts.
/// - **One quick 429 retry** (`maxAttempts: 2`, short capped backoff) so a
///   momentary rate-limit is absorbed instead of instantly abandoning lossless
///   for YouTube, without stalling on the (up to ~35s) download backoff chain.
final _playbackZarzClient = ZarzClient(
  maxAttempts: 2,
  maxConcurrent: 4,
  maxRetryBackoff: const Duration(seconds: 2),
);

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

    // ISRC is an authoritative recording identifier. If Qobuz tags a candidate
    // with the EXACT ISRC we asked for, it is the same recording — accept it
    // with top priority even when the title/artist text differs (romanized
    // titles, "Various Artists"/composer tagging, remaster suffixes). This is
    // what unlocks lossless for tracks the fuzzy score would otherwise drop.
    //
    // Everything else came from the text-search fallback (ISRC missed); there a
    // loose result could be the "wrong song" — the very thing Qobuz is here to
    // avoid — so it still has to clear the 0.5 score threshold the download
    // path uses.
    final expectedIsrc = track.isrc.trim().toUpperCase();
    final scored = <(SonolythAudioSourceMatchObject, double)>[];
    for (final candidate in results) {
      final match = _toMatch(candidate);
      if (match == null) continue;

      final candidateIsrc =
          candidate["isrc"]?.toString().trim().toUpperCase() ?? "";
      if (expectedIsrc.isNotEmpty && candidateIsrc == expectedIsrc) {
        // Score 2.0 sorts it ahead of any fuzzy match (max ~1.05).
        scored.add((match, 2.0));
        continue;
      }

      final score = TrackMatching.score(
        expectedTitle: track.name,
        candidateTitle: match.title,
        expectedArtists: track.artists.map((a) => a.name).toList(),
        candidateArtists: match.artists,
        expectedDurationMs: track.durationMs,
        candidateDurationMs: match.duration.inMilliseconds,
      );
      if (score >= 0.5) scored.add((match, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
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
