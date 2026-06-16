import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';

/// TIDAL lossless source, ported from the SpotiFLAC `tidal-web` extension.
///
/// Two different backends are involved, mirroring the extension:
///  * metadata/search runs against TIDAL's public web API (a public web token,
///    no account) to map a Spotify track to a TIDAL track id; and
///  * the download URL is resolved through the shared zarz gateway
///    (`/v1/dl/tid2`), which returns a base64 manifest.
///
/// TIDAL's lossless manifest is usually a "BTS" payload carrying a single
/// direct FLAC URL — that's the case we download. DASH manifests (and the
/// lossy HIGH/LOW/Atmos tiers) need segment stitching + container conversion
/// the in-app downloader can't do yet, so we return null there and let the
/// next provider (Deezer) take the track instead of producing a worse file.
class TidalProvider extends SpotiFlacProvider {
  static const _searchBase = "https://tidal.com/v1";
  static const _downloadUrl = "https://api.zarz.moe/v1/dl/tid2";
  static const _publicToken = "49YxDN9a2aFV6RTG";
  static const _countryCode = "US";
  static const _locale = "en_US";
  static const _deviceType = "BROWSER";

  /// Download resolution goes through the shared, rate-limited zarz gateway.
  final ZarzClient _client;

  /// TIDAL metadata search hits a different host (tidal.com, not the gateway)
  /// and needs its own headers, so it uses a dedicated Dio rather than the
  /// gateway client.
  final Dio _searchDio;

  TidalProvider({ZarzClient? client, Dio? searchDio})
      : _client = client ?? zarzClient,
        _searchDio = searchDio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                "Accept": "application/json",
                "x-tidal-token": _publicToken,
                "User-Agent":
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/120.0 Safari/537.36",
              },
            ));

  @override
  String get id => "tidal";

  @override
  String get displayName => "Tidal";

  // Only the lossless tiers — both deliver FLAC. We intentionally don't expose
  // HIGH/LOW (lossy AAC): the chain's lossy last-resort is YouTube.
  @override
  List<String> get qualities => const ["HI_RES_LOSSLESS", "LOSSLESS"];

  @override
  String get defaultQuality => "LOSSLESS";

  static const _qualityLabels = {
    "HI_RES_LOSSLESS": "HiRes FLAC",
    "LOSSLESS": "Lossless",
  };

  static String labelFor(String quality) =>
      _qualityLabels[quality] ?? "Lossless";

  /// Lossless-only fallback within TIDAL. We never drop to HIGH/LOW here — a
  /// lossy fallback is the job of the YouTube provider at the end of the chain.
  List<String> _fallbackChain(String quality) {
    switch (quality) {
      case "HI_RES_LOSSLESS":
        return const ["HI_RES_LOSSLESS", "LOSSLESS"];
      default:
        return const ["LOSSLESS"];
    }
  }

  @override
  Future<SpotiFlacDownloadResolution?> resolve(
    SonolythFullTrackObject track,
    String quality,
  ) async {
    final tidalId = await _resolveTrackId(track);
    if (tidalId == null) return null;

    for (final tier in _fallbackChain(quality)) {
      final url = await _streamUrlForId(tidalId, tier);
      if (url != null) {
        return SpotiFlacDownloadResolution(url: url, fileExtension: "flac");
      }
    }
    return null;
  }

  /// Resolves a direct FLAC URL for a TIDAL track id at [quality], or null when
  /// the gateway returns a preview, a non-lossless tier, or a manifest we can't
  /// download directly (DASH/segmented).
  Future<String?> _streamUrlForId(String tidalId, String quality) async {
    final Map payload;
    try {
      payload = await _client.postJson(_downloadUrl, {
        "id": tidalId,
        "quality": quality,
      }) as Map;
    } on ZarzRateLimitedException {
      rethrow;
    } catch (_) {
      return null;
    }

    if (payload["success"] == false) return null;
    final data = payload["data"] is Map ? payload["data"] as Map : payload;

    if ((data["assetPresentation"]?.toString().toUpperCase()) == "PREVIEW") {
      return null;
    }
    // A downgraded tier means TIDAL handed back lossy AAC; defer rather than
    // bake in a worse copy than a later lossless provider could give.
    final audioQuality = (data["audioQuality"]?.toString() ?? "").toUpperCase();
    if (audioQuality.isNotEmpty &&
        audioQuality != "LOSSLESS" &&
        audioQuality != "HI_RES" &&
        audioQuality != "HI_RES_LOSSLESS") {
      return null;
    }

    final manifestB64 = data["manifest"]?.toString();
    if (manifestB64 == null || manifestB64.isEmpty) return null;

    final String manifestText;
    try {
      manifestText = _decodeBase64(manifestB64);
    } catch (_) {
      return null;
    }

    // BTS manifest: a JSON object with a direct file URL. DASH manifests start
    // with '<' (XML) and need stitching — defer those to the next provider.
    final trimmed = manifestText.trimLeft();
    if (!trimmed.startsWith("{")) return null;

    try {
      final manifest = jsonDecode(manifestText) as Map;
      final urls = manifest["urls"];
      final directUrl = (urls is List && urls.isNotEmpty)
          ? urls.first?.toString()
          : null;
      if (directUrl == null || directUrl.isEmpty) return null;

      // mp4/m4a containers carry ALAC/AAC, not FLAC — defer so we don't write a
      // non-FLAC file under a .flac name (the downloader's magic check would
      // fail it outright instead of trying Deezer).
      final mime = (manifest["mimeType"]?.toString() ?? "audio/flac")
          .toLowerCase();
      if (mime.contains("mp4") || mime.contains("m4a")) return null;

      return directUrl;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveTrackId(SonolythFullTrackObject track) async {
    final query =
        "${track.name} ${track.artists.map((a) => a.name).join(" ")}".trim();
    final candidates = await _search(query, limit: 8);
    if (candidates.isEmpty) return null;

    // Prefer an exact ISRC hit; TIDAL search returns the isrc per track.
    if (track.isrc.isNotEmpty) {
      final expectedIsrc = track.isrc.toUpperCase();
      final byIsrc = candidates.firstWhere(
        (c) => (c["isrc"]?.toString().toUpperCase() ?? "") == expectedIsrc,
        orElse: () => const {},
      );
      final id = byIsrc["id"];
      if (id != null) return id.toString();
    }

    return _bestMatch(track, candidates)?["id"]?.toString();
  }

  Future<List<Map>> _search(String query, {required int limit}) async {
    if (query.isEmpty) return const [];
    try {
      final response = await _searchDio.get(
        "$_searchBase/search/tracks",
        queryParameters: {
          "query": query,
          "limit": limit,
          "offset": 0,
          "countryCode": _countryCode,
          "locale": _locale,
          "deviceType": _deviceType,
        },
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      final items = data is Map ? data["items"] : null;
      return items is List ? items.whereType<Map>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  Map? _bestMatch(SonolythFullTrackObject track, List<Map> candidates) {
    Map? best;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final artists = candidate["artists"];
      final candidateArtists = artists is List
          ? artists
              .whereType<Map>()
              .map((a) => a["name"]?.toString() ?? "")
              .where((n) => n.isNotEmpty)
              .toList()
          : <String>[
              if (candidate["artist"] is Map)
                (candidate["artist"] as Map)["name"]?.toString() ?? "",
            ];
      final score = TrackMatching.score(
        expectedTitle: track.name,
        candidateTitle: candidate["title"]?.toString() ?? "",
        expectedArtists: track.artists.map((a) => a.name).toList(),
        candidateArtists: candidateArtists,
        expectedDurationMs: track.durationMs,
        // TIDAL reports track length in seconds.
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

  String _decodeBase64(String value) {
    var s = value.trim().replaceAll("-", "+").replaceAll("_", "/");
    final pad = s.length % 4;
    if (pad > 0) s = s + ("=" * (4 - pad));
    return utf8.decode(base64.decode(s));
  }
}
