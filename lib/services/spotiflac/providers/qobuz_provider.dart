import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

/// Qobuz lossless source. Metadata/search still run through the gateway's
/// unsigned v1 endpoint; stream resolution now goes through the **v2
/// signed-session** API (`/v2/dl/qbz`), which requires a verified session and a
/// per-download ticket (the old `/v1/dl/qbz` was retired). The returned URL is a
/// direct, unencrypted FLAC stream.
class QobuzProvider extends SpotiFlacProvider {
  static const _metadataBase = "https://api.zarz.moe/v1/qbz";
  static const _downloadPath = "/dl/qbz";
  static const _appId = "798273057";

  final ZarzClient _client;
  final ZarzSession _session;

  QobuzProvider([ZarzClient? client, ZarzSession? session])
      : _client = client ?? zarzClient,
        _session = session ?? ZarzSession.qobuz;

  @override
  String get id => "qobuz";

  @override
  String get displayName => "Qobuz";

  @override
  List<String> get qualities => const ["27", "7", "6"];

  @override
  String get defaultQuality => "27";

  static const _qualityLabels = {
    "27": "24-Bit Max",
    "7": "24-Bit",
    "6": "Lossless",
  };

  static String labelFor(String quality) =>
      _qualityLabels[quality] ?? "Lossless";

  List<String> _fallbackChain(String quality) {
    switch (quality) {
      case "27":
        return const ["27", "7", "6"];
      case "7":
        return const ["7", "6"];
      default:
        return const ["6"];
    }
  }

  String _mapDownloadQuality(String code) {
    switch (code) {
      case "27":
        return "hi-res-max";
      case "7":
        return "hi-res";
      default:
        return "cd";
    }
  }

  @override
  Future<SpotiFlacDownloadResolution?> resolve(
    SonolythFullTrackObject track,
    String quality,
  ) async {
    final trackId = await _resolveTrackId(track);
    if (trackId == null) return null;

    final url = await streamUrlForId(trackId, quality);
    if (url == null) return null;

    return SpotiFlacDownloadResolution(url: url, fileExtension: "flac");
  }

  /// Resolves a direct, unencrypted FLAC URL for a specific Qobuz track id,
  /// walking the quality fallback chain. Shared by the download path
  /// ([resolve]) and the Qobuz playback audio source.
  Future<String?> streamUrlForId(String qobuzTrackId, String quality) async {
    final trackUrl = "https://open.qobuz.com/track/$qobuzTrackId";
    for (final code in _fallbackChain(quality)) {
      try {
        // The ticket's resource hash must match what the gateway derives at
        // consume time from `body.url` — mint it from the same track URL.
        final ticket = await _session.mintTicket("qbz", "track", trackUrl);
        final payload = await _session.signedPostJson(
          _downloadPath,
          {
            "quality": _mapDownloadQuality(code),
            "upload_to_r2": false,
            "id": qobuzTrackId,
            "type": "track",
            "url": trackUrl,
          },
          extraHeaders: {"X-Zarz-Ticket": ticket},
        );

        if (payload["success"] == false) continue;
        final nested = payload["data"] is Map ? payload["data"] as Map : {};
        final url = (payload["download_url"] ??
                payload["url"] ??
                payload["link"] ??
                nested["download_url"] ??
                nested["url"] ??
                nested["link"])
            ?.toString();
        if (url == null || url.isEmpty) continue;

        return url;
      } on ZarzRateLimitedException {
        // Lower tiers would hit the same limiter; let the caller report it.
        rethrow;
      } on ZarzVerificationRequiredException {
        // No session — the whole provider is unavailable until the user
        // verifies; lower tiers won't help. Let the caller fall through.
        rethrow;
      } catch (_) {
        // Try the next quality tier.
      }
    }
    return null;
  }

  /// Candidate Qobuz tracks for [track], ISRC-first then a text search.
  /// Returns the raw Qobuz track maps so callers can build their own match
  /// objects (the playback audio source needs multiple ranked candidates,
  /// unlike the download path which only needs the single best id).
  Future<List<Map>> searchTracks(SonolythFullTrackObject track) async {
    if (track.isrc.isNotEmpty) {
      final byIsrc = await _search(track.isrc, limit: 5);
      if (byIsrc.isNotEmpty) return byIsrc;
    }
    final query = "${track.name} ${track.artists.map((a) => a.name).join(" ")}";
    return _search(query, limit: 10);
  }

  Future<String?> _resolveTrackId(SonolythFullTrackObject track) async {
    if (track.isrc.isNotEmpty) {
      // Only trust an ISRC hit whose returned isrc actually equals ours —
      // when Qobuz lacks the recording, the search degrades to fuzzy text
      // matching on the ISRC string and the first hit can be an unrelated
      // track (wrong artist entirely).
      final expectedIsrc = track.isrc.trim().toUpperCase();
      final byIsrc = await _search(track.isrc, limit: 5);
      for (final candidate in byIsrc) {
        final candidateIsrc =
            candidate["isrc"]?.toString().trim().toUpperCase() ?? "";
        if (candidateIsrc == expectedIsrc) return candidate["id"]?.toString();
      }
    }

    final query = "${track.name} ${track.artists.map((a) => a.name).join(" ")}";
    final candidates = await _search(query, limit: 10);
    return _bestMatch(track, candidates)?["id"]?.toString();
  }

  Future<List<Map>> _search(String query, {required int limit}) async {
    try {
      final payload = await _client.getJson(
        "$_metadataBase/track/search",
        query: {"query": query, "limit": limit, "app_id": _appId},
      ) as Map;
      final tracks = payload["tracks"];
      final items = tracks is Map ? tracks["items"] : null;
      return items is List ? items.whereType<Map>().toList() : const [];
    } on ZarzRateLimitedException {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  Map? _bestMatch(SonolythFullTrackObject track, List<Map> candidates) {
    Map? best;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final performer = candidate["performer"];
      final artistName =
          performer is Map ? performer["name"]?.toString() ?? "" : "";
      final score = TrackMatching.score(
        expectedTitle: track.name,
        candidateTitle: candidate["title"]?.toString() ?? "",
        expectedArtists: track.artists.map((a) => a.name).toList(),
        candidateArtists: [artistName],
        expectedDurationMs: track.durationMs,
        candidateDurationMs:
            ((candidate["duration"] as num?)?.toInt() ?? 0) * 1000,
      );
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return bestScore >= 0.5 ? best : null;
  }
}
