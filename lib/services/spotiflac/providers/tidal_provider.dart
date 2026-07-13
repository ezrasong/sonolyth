import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/sourced_track/tidal_dash.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

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
  static const _downloadPath = "/dl/tid";
  static const _publicToken = "49YxDN9a2aFV6RTG";
  static const _countryCode = "US";
  static const _locale = "en_US";
  static const _deviceType = "BROWSER";

  /// Stream resolution goes through the v2 signed-session gateway
  /// (`/v2/dl/tid`); the old `/v1/dl/tid2` was retired.
  final ZarzSession _session;

  /// Kept for API compatibility with existing call sites that inject a playback
  /// [ZarzClient]; v2 resolution no longer uses it (search hits tidal.com).
  // ignore: unused_field
  final ZarzClient _client;

  /// TIDAL metadata search hits a different host (tidal.com, not the gateway)
  /// and needs its own headers, so it uses a dedicated Dio rather than the
  /// gateway client.
  final Dio _searchDio;

  TidalProvider({ZarzClient? client, Dio? searchDio, ZarzSession? session})
      : _client = client ?? zarzClient,
        _session = session ?? ZarzSession.tidal,
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
      final url = await streamUrlForId(tidalId, tier);
      if (url != null) {
        return SpotiFlacDownloadResolution(url: url, fileExtension: "flac");
      }
    }
    return null;
  }

  /// Candidate TIDAL tracks for [track] (raw search maps, each carrying `id`,
  /// `isrc`, `title`, `duration`, `artists`). Exposed for callers that do their
  /// own ISRC-first ranking — the playback audio source — mirroring the Qobuz
  /// provider's searchTracks.
  Future<List<Map>> searchTracks(SonolythFullTrackObject track) async {
    final query =
        "${track.name} ${track.artists.map((a) => a.name).join(" ")}".trim();
    return _search(query, limit: 10);
  }

  /// Resolves a playable FLAC URL for a TIDAL track id at [quality], or null on
  /// a preview / non-lossless / unusable response. Shared by the download path
  /// ([resolve]) and the Tidal playback audio source.
  ///
  /// TIDAL lossless usually comes back as a **DASH manifest** (FLAC segments),
  /// not a single direct file URL. With [allowDash] true (playback) we return
  /// the `.mpd` URL — mpv/media_kit streams DASH directly. With it false
  /// (downloads, which can't fetch an .mpd as a file) DASH is deferred so the
  /// next provider (Deezer) handles it. The rarer "BTS" response carries a
  /// single direct FLAC URL usable by both.
  Future<String?> streamUrlForId(
    String tidalId,
    String quality, {
    bool allowDash = false,
  }) async {
    final Map payload;
    try {
      // The ticket resource hash is derived from the bare track id for Tidal.
      final ticket = await _session.mintTicket("tid", "track", tidalId);
      payload = await _session.signedPostJson(
        _downloadPath,
        {"id": tidalId, "quality": quality},
        extraHeaders: {"X-Zarz-Ticket": ticket},
      );
    } on ZarzRateLimitedException {
      rethrow;
    } on ZarzVerificationRequiredException {
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
    // bake in a worse copy than a later lossless provider could give. The
    // resolved quality is reported both at top level and inside `data`.
    final audioQuality =
        (data["audioQuality"] ?? payload["audioQuality"] ?? "")
            .toString()
            .toUpperCase();
    if (audioQuality.isNotEmpty &&
        audioQuality != "LOSSLESS" &&
        audioQuality != "HI_RES" &&
        audioQuality != "HI_RES_LOSSLESS") {
      return null;
    }

    // v2 embeds the manifest as base64 inside `data.manifest` — either a "BTS"
    // JSON (single direct FLAC URL) or a DASH MPD (the common lossless case).
    final manifestB64 = data["manifest"]?.toString();
    if (manifestB64 == null || manifestB64.isEmpty) return null;

    final String manifestText;
    try {
      manifestText = _decodeBase64(manifestB64);
    } catch (_) {
      return null;
    }

    final trimmed = manifestText.trimLeft();

    // BTS manifest: a JSON object with a single direct file URL.
    if (trimmed.startsWith("{")) {
      try {
        final manifest = jsonDecode(manifestText) as Map;
        final urls = manifest["urls"];
        final directUrl = (urls is List && urls.isNotEmpty)
            ? urls.first?.toString()
            : null;
        if (directUrl == null || directUrl.isEmpty) return null;

        // mp4/m4a containers carry ALAC/AAC, not FLAC — defer so we don't write
        // a non-FLAC file under a .flac name (the downloader's magic check would
        // fail it outright instead of trying Deezer).
        final mime = (manifest["mimeType"]?.toString() ?? "audio/flac")
            .toLowerCase();
        if (mime.contains("mp4") || mime.contains("m4a")) return null;

        return directUrl;
      } catch (_) {
        return null;
      }
    }

    // DASH MPD (the common lossless case). For playback, hand the inline
    // manifest to the server's stitcher as a marked `data:` URI so its FLAC
    // segments are served as one seekable virtual file for mpv. Downloads can't
    // consume an .mpd as a file, so they defer to the next provider (Deezer).
    if (trimmed.startsWith("<")) {
      if (!allowDash) return null;
      final reencoded = base64.encode(utf8.encode(manifestText));
      return markDashUrl("data:application/dash+xml;base64,$reencoded");
    }

    return null;
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
