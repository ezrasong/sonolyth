import 'package:collection/collection.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/youtube_engine/youtube_engine.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Last-resort download source: when no lossless provider has the track, pull
/// the best audio-only stream from YouTube. This downloads AUDIO only (never
/// the video/mp4 muxed stream); YouTube serves AAC (m4a) or Opus (webm) — there
/// is no MP3 stream and the app has no transcoder, so we prefer the m4a/AAC
/// stream (cleanly taggable) and fall back to whatever container is available.
///
/// The [engine] is injected at download time by the download manager because
/// the active engine depends on user preferences (Riverpod-scoped).
class YouTubeProvider extends SpotiFlacProvider {
  final YouTubeEngine? engine;

  YouTubeProvider({this.engine});

  @override
  String get id => "youtube";

  @override
  String get displayName => "YouTube";

  @override
  List<String> get qualities => const ["best"];

  @override
  String get defaultQuality => "best";

  @override
  bool get isLossless => false;

  @override
  Future<SpotiFlacDownloadResolution?> resolve(
    SonolythFullTrackObject track,
    String quality,
  ) async {
    final engine = this.engine;
    if (engine == null) return null;

    final query =
        "${track.name} ${track.artists.map((a) => a.name).join(" ")}".trim();
    if (query.isEmpty) return null;

    final results = await engine.searchVideos(query);
    final video = _bestMatch(track, results);
    if (video == null) return null;

    final manifest = await engine.getStreamManifest(video.id.value);
    final stream = _bestAudioStream(manifest.audioOnly.toList());
    if (stream == null) return null;

    // m4a (AAC in an mp4 container) tags cleanly; anything else keeps its own
    // container extension so the file isn't mislabelled.
    final container = stream.container.name.toLowerCase();
    final fileExtension = container == "mp4" ? "m4a" : container;

    return SpotiFlacDownloadResolution(
      url: stream.url.toString(),
      fileExtension: fileExtension,
    );
  }

  Video? _bestMatch(SonolythFullTrackObject track, List<Video> candidates) {
    Video? best;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final score = TrackMatching.score(
        expectedTitle: track.name,
        candidateTitle: candidate.title,
        expectedArtists: track.artists.map((a) => a.name).toList(),
        candidateArtists: [candidate.author],
        expectedDurationMs: track.durationMs,
        candidateDurationMs: candidate.duration?.inMilliseconds ?? 0,
      );
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    // YouTube titles carry a lot of noise, so accept a looser match than the
    // lossless providers, but still guard against picking an unrelated video.
    return bestScore >= 0.35 ? best : null;
  }

  AudioOnlyStreamInfo? _bestAudioStream(List<AudioOnlyStreamInfo> streams) {
    if (streams.isEmpty) return null;
    // Prefer the mp4/AAC pool (m4a) for tagging + broad compatibility; pick the
    // highest bitrate within whichever pool we use.
    final mp4 =
        streams.where((s) => s.container.name.toLowerCase() == "mp4").toList();
    final pool = mp4.isNotEmpty ? mp4 : streams;
    return pool
        .sorted(
          (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
        )
        .first;
  }
}
