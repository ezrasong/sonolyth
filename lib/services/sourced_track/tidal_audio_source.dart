import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/spotiflac/streaming_quality.dart';
import 'package:sonolyth/services/sourced_track/tidal_dash.dart';
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

  /// The tier streaming asks for comes from Settings now. It used to be the
  /// constant `"LOSSLESS"` (CD quality, chosen for a fast start), which is
  /// still the default and still what the store reports before it has loaded.
  /// Downloads keep their own per-provider quality.

  final TidalProvider _provider;

  TidalAudioSource([TidalProvider? provider])
      : _provider = provider ?? TidalProvider(client: _tidalPlaybackZarzClient);

  /// Whether [match] was produced by this source (and should be resolved here).
  static bool ownsMatch(SonolythAudioSourceMatchObject match) =>
      match.externalUri.startsWith(externalUriPrefix);

  /// ISRC-first candidate matches for [track], best first (same ranking rules
  /// as the Qobuz source: exact-ISRC hits jump ahead of fuzzy text matches,
  /// which still have to clear the 0.5 score threshold). `sawResults` reports
  /// whether the search returned anything at all — see the Qobuz source.
  Future<({List<SonolythAudioSourceMatchObject> accepted, bool sawResults})>
      matches(
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

      // Fuzzy path only: an exact-ISRC hit above IS the same recording, but a
      // text match must never land on a live / cover / piano / instrumental
      // rendition of the requested song.
      if (TrackMatching.isVariantMismatch(track.name, match.title)) continue;

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
    return (
      accepted: scored.map((e) => e.$1).toList(),
      sawResults: results.isNotEmpty,
    );
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
    final tier = StreamingQualityStore.current;
    final resolved = await _provider.streamForId(
      match.id,
      tier.tidalTier,
      allowDash: true,
      // Only ever true for the data-saver tier, and only for a stream: the
      // provider's container and audioQuality guards stay closed for
      // downloads, which must not write AAC under a .flac name.
      allowLossy: tier.lossy,
    );
    final url = resolved?.url;
    if (url == null || url.isEmpty) return const [];

    // Reported by the provider, which is the only place that can tell: a DASH
    // manifest is FLAC segments however the request was phrased.
    final servedLossy = resolved!.lossy;

    return [
      SonolythAudioSourceStreamObject(
        url: url,
        container: servedLossy ? "m4a" : "flac",
        type: servedLossy
            ? SonolythMediaCompressionType.lossy
            : SonolythMediaCompressionType.lossless,
        codec: servedLossy ? "aac" : "flac",
        bitDepth: servedLossy ? null : (tier.bitDepth ?? 16),
        sampleRate:
            servedLossy ? null : (tier.sampleRate ?? 44100).toDouble(),
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
