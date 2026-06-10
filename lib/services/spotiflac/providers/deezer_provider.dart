import 'package:dio/dio.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';

/// Deezer lossless source. Track matching uses Deezer's public API; the
/// download URL comes from the zarz gateway and the CDN stream is
/// Blowfish-encrypted (decrypted client-side by the downloader).
class DeezerProvider extends SpotiFlacProvider {
  static const _deezerApi = "https://api.deezer.com";
  static const _downloadUrl = "https://api.zarz.moe/v1/dl/dzr";

  final ZarzClient _client;
  final Dio _deezerDio;

  DeezerProvider({ZarzClient? client, Dio? deezerDio})
      : _client = client ?? zarzClient,
        _deezerDio = deezerDio ?? Dio() {
    _deezerDio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15)
      ..headers["User-Agent"] =
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";
  }

  @override
  String get id => "deezer";

  @override
  String get displayName => "Deezer";

  @override
  List<String> get qualities => const ["FLAC"];

  @override
  String get defaultQuality => "FLAC";

  @override
  Future<SpotiFlacDownloadResolution?> resolve(
    SonolythFullTrackObject track,
    String quality,
  ) async {
    final trackId = await _resolveTrackId(track);
    if (trackId == null) return null;

    try {
      final descriptor = await _client.postJson(_downloadUrl, {
        "platform": "deezer",
        "url": "https://www.deezer.com/track/$trackId",
      }) as Map;

      if (descriptor["success"] == false) return null;

      final directDownloadable = descriptor["direct_downloadable"] == true;
      final url = (directDownloadable
                  ? descriptor["direct_download_url"]
                  : null) ??
              descriptor["download_url"] ??
              descriptor["deezer_cdn_url"] ??
              descriptor["direct_download_url"];
      if (url == null || url.toString().isEmpty) return null;

      final requiresDecryption = descriptor["requires_client_decryption"] ==
              true ||
          (descriptor.containsKey("direct_downloadable")
              ? !directDownloadable
              : descriptor["deezer_encrypted"] == true);

      final format =
          (descriptor["deezer_format"]?.toString() ?? "flac").toLowerCase();

      return SpotiFlacDownloadResolution(
        url: url.toString(),
        fileExtension: format.contains("mp3") ? "mp3" : "flac",
        encryption: requiresDecryption
            ? SpotiFlacEncryption.deezerBlowfish
            : SpotiFlacEncryption.none,
        decryptionSeed: trackId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveTrackId(SonolythFullTrackObject track) async {
    if (track.isrc.isNotEmpty) {
      try {
        final response = await _deezerDio.get(
          "$_deezerApi/2.0/track/isrc:${Uri.encodeComponent(track.isrc)}",
        );
        final data = response.data;
        if (data is Map && data["id"] != null) return data["id"].toString();
      } catch (_) {
        // Fall through to text search.
      }
    }

    final query = "${track.name} ${track.artists.map((a) => a.name).join(" ")}";
    try {
      final response = await _deezerDio.get(
        "$_deezerApi/search",
        queryParameters: {"q": query, "limit": 10},
      );
      final data = response.data;
      final results = data is Map ? data["data"] : null;
      if (results is List) {
        final best = _bestMatch(track, results.whereType<Map>().toList());
        return best?["id"]?.toString();
      }
    } catch (_) {
      // No match.
    }
    return null;
  }

  Map? _bestMatch(SonolythFullTrackObject track, List<Map> candidates) {
    Map? best;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final artist = candidate["artist"];
      final artistName = artist is Map ? artist["name"]?.toString() ?? "" : "";
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
