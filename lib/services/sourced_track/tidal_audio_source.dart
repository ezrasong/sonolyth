import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/providers/tidal_provider.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';

/// Playback gateway lane for Tidal — same tuning as the Qobuz one: concurrent
/// and gap-free so prefetching upcoming tracks overlaps, with a single quick
/// 429 retry so a momentary rate-limit is absorbed instead of instantly
/// abandoning lossless.
final _tidalPlaybackZarzClient = ZarzClient(
  maxAttempts: 2,
  maxConcurrent: 4,
  maxRetryBackoff: const Duration(seconds: 2),
);

/// Native (non-plugin) playback audio source backed by Tidal via the zarz
/// gateway. Like [QobuzAudioSource] it resolves by ISRC for the exact recording
/// and serves a lossless FLAC stream. Most Tidal lossless tracks come back as a
/// DASH manifest; that URL is tagged with [dashUrlMarker] and the playback
/// server stitches its FLAC segments into one fMP4 stream for mpv. Only when
/// the gateway returns nothing usable does the caller fall through to the next
/// source (YouTube).
class TidalAudioSource {
  /// Stable slug used to namespace this source.
  static const slug = "tidal";

  /// Marks a match as Tidal-sourced (vs Qobuz / the YouTube plugin) so stream
  /// resolution routes back here without a separate source field on the shared
  /// match model.
  static const externalUriPrefix = "https://tidal.com/browse/track/";

  /// CD-lossless FLAC for a fast start (Tidal "LOSSLESS" tier). Downloads use
  /// their own (higher) per-provider quality from the download settings.
  static const _streamingQuality = "LOSSLESS";

  final TidalProvider _provider;

  TidalAudioSource([TidalProvider? provider])
      : _provider = provider ?? TidalProvider(client: _tidalPlaybackZarzClient);

  /// Whether [match] was produced by this source (and should be resolved here).
  static bool ownsMatch(SonolythAudioSourceMatchObject match) =>
      match.externalUri.startsWith(externalUriPrefix);

  /// ISRC-first candidate matches for [track], best first (same ranking rules
  /// as the Qobuz source: exact-ISRC hits jump ahead of fuzzy text matches,
  /// which still have to clear the 0.5 score threshold).
  Future<List<SonolythAudioSourceMatchObject>> matches(
    SonolythFullTrackObject track,
  ) async {
    final results = await _provider.searchTracks(track);

    final expectedIsrc = track.isrc.trim().toUpperCase();
    final scored = <(SonolythAudioSourceMatchObject, double)>[];
    for (final candidate in results) {
      final match = _toMatch(candidate);
      if (match == null) continue;

      final candidateIsrc =
          candidate["isrc"]?.toString().trim().toUpperCase() ?? "";
      if (expectedIsrc.isNotEmpty && candidateIsrc == expectedIsrc) {
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

  /// Lossless FLAC stream(s) for a previously matched Tidal track, or an empty
  /// list when the gateway can't serve anything usable (preview / lossy
  /// downgrade) so the caller can fall back to the next source. A DASH manifest
  /// comes back as a [dashUrlMarker]-tagged URL the playback server stitches.
  Future<List<SonolythAudioSourceStreamObject>> streams(
    SonolythAudioSourceMatchObject match,
  ) async {
    // allowDash: TIDAL serves lossless as a DASH manifest. The marked `.mpd`
    // URL is stitched into a single fMP4 FLAC stream by the playback server
    // (downloads can't consume an .mpd as a file, so they don't set this).
    final url = await _provider.streamUrlForId(
      match.id,
      _streamingQuality,
      allowDash: true,
    );
    if (url == null || url.isEmpty) return const [];

    return [
      SonolythAudioSourceStreamObject(
        url: url,
        container: "flac",
        type: SonolythMediaCompressionType.lossless,
        codec: "flac",
        // TIDAL "LOSSLESS" tier is CD quality (16-bit / 44.1kHz).
        bitDepth: 16,
        sampleRate: 44100,
      ),
    ];
  }

  SonolythAudioSourceMatchObject? _toMatch(Map candidate) {
    final id = candidate["id"]?.toString();
    if (id == null || id.isEmpty) return null;

    final artistsRaw = candidate["artists"];
    final artists = artistsRaw is List
        ? artistsRaw
            .whereType<Map>()
            .map((a) => a["name"]?.toString() ?? "")
            .where((n) => n.isNotEmpty)
            .toList()
        : <String>[
            if (candidate["artist"] is Map)
              (candidate["artist"] as Map)["name"]?.toString() ?? "",
          ];

    // TIDAL reports track length in seconds.
    final durationSeconds = (candidate["duration"] as num?)?.toInt() ?? 0;

    return SonolythAudioSourceMatchObject(
      id: id,
      title: candidate["title"]?.toString() ?? "",
      artists: artists,
      duration: Duration(seconds: durationSeconds),
      thumbnail: null,
      externalUri: "$externalUriPrefix$id",
    );
  }
}
