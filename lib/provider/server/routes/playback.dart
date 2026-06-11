import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart';
import 'package:shelf/shelf.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/models/parser/range_headers.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/state.dart';

import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/provider/server/active_track_sources.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/sourced_track/sourced_track.dart';
import 'package:sonolyth/utils/service_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final _deviceClients = Set.unmodifiable({
  YoutubeApiClient.ios,
  YoutubeApiClient.android,
  YoutubeApiClient.mweb,
  YoutubeApiClient.safari,
});

String? get _randomUserAgent => _deviceClients
    .elementAt(
      Random().nextInt(_deviceClients.length),
    )
    .payload["context"]["client"]["userAgent"];

class ServerPlaybackRoutes {
  final Ref ref;
  UserPreferences get userPreferences => ref.read(userPreferencesProvider);
  AudioPlayerState get playlist => ref.read(audioPlayerProvider);
  final Dio dio;

  ServerPlaybackRoutes(this.ref) : dio = Dio();

  Future<String> _getTrackCacheFilePath(SourcedTrack track) async {
    return join(
      await UserPreferencesNotifier.getMusicCacheDir(),
      ServiceUtils.sanitizeFilename(
        '${track.query.name} - ${track.query.artists.map((d) => d.name).join(",")} (${track.info.id}).${track.qualityPreset!.getFileExtension()}',
      ),
    );
  }

  Future<SourcedTrack?> _getSourcedTrack(
    Request request,
    String trackId,
  ) async {
    // Requests can race queue mutations (track skipped/removed while a
    // stream request is in flight) — treat a missing track/media as a 404
    // rather than letting firstWhere throw.
    final track =
        playlist.tracks.firstWhereOrNull((element) => element.id == trackId);
    if (track == null) return null;

    final activeSourcedTrack =
        await ref.read(activeTrackSourcesProvider.future);

    if (activeSourcedTrack?.track.id == track.id) {
      return activeSourcedTrack?.source;
    }

    final media = audioPlayer.playlist.medias
        .firstWhereOrNull((e) => e.uri == request.requestedUri.toString());
    if (media == null) return null;

    final spotubeMedia =
        media is SonolythMedia ? media : SonolythMedia.media(media);
    final mediaTrack = spotubeMedia.track;
    if (mediaTrack is! SonolythFullTrackObject) return null;

    return await ref.read(sourcedTrackProvider(mediaTrack).future);
  }

  /// Serves a local file (downloaded or cached) honoring single-range Range
  /// requests, with correct content-length/content-range semantics. The
  /// previous header math was off by one and ranges were advertised but
  /// ignored, which could make mpv truncate or mis-seek.
  Response _serveLocalFile(
    Request request,
    File file,
    int length,
    String contentType, {
    required bool headOnly,
  }) {
    final rangeHeader = request.headers["range"];
    final match = rangeHeader == null
        ? null
        : RegExp(r"^bytes=(\d*)-(\d*)$").firstMatch(rangeHeader.trim());

    if (match != null &&
        (match.group(1)!.isNotEmpty || match.group(2)!.isNotEmpty)) {
      int start;
      int end;
      if (match.group(1)!.isEmpty) {
        // Suffix range: the last N bytes.
        final suffix = int.parse(match.group(2)!);
        start = max(0, length - suffix);
        end = length - 1;
      } else {
        start = int.parse(match.group(1)!);
        end = match.group(2)!.isEmpty
            ? length - 1
            : min(int.parse(match.group(2)!), length - 1);
      }
      if (start <= end && start < length) {
        final headers = {
          "content-type": contentType,
          "content-length": "${end - start + 1}",
          "accept-ranges": "bytes",
          "content-range": "bytes $start-$end/$length",
        };
        if (headOnly) return Response(206, headers: headers);
        return Response(
          206,
          body: file.openRead(start, end + 1),
          headers: headers,
        );
      }
    }

    final headers = {
      "content-type": contentType,
      "content-length": "$length",
      "accept-ranges": "bytes",
    };
    if (headOnly) return Response(200, headers: headers);
    return Response(200, body: file.openRead(), headers: headers);
  }

  /// Serves the music-cache file for [track] when caching is on and the file
  /// is complete, or null to fall through to online streaming.
  Future<Response?> _serveCachedFile(
    Request request,
    SourcedTrack track, {
    required bool headOnly,
  }) async {
    if (!userPreferences.cacheMusic) return null;
    final trackCacheFile = File(await _getTrackCacheFilePath(track));
    if (!await trackCacheFile.exists()) return null;
    return _serveLocalFile(
      request,
      trackCacheFile,
      await trackCacheFile.length(),
      "audio/${track.qualityPreset!.name}",
      headOnly: headOnly,
    );
  }

  Future<dio_lib.Response> streamTrackInformation(
    Request request,
    SourcedTrack track,
  ) async {
    AppLogger.log.i(
      "HEAD request for track: ${track.query.name}\n"
      "Range: ${request.headers['range']}",
    );

    String url = track.url ??
        await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling()
            .then((track) => track.url!);

    final options = Options(
      headers: {
        "user-agent": _randomUserAgent,
        "Cache-Control": "max-age=3600",
        "Connection": "keep-alive",
        "host": Uri.parse(url).host,
      },
      validateStatus: (status) => status! < 400,
    );

    final res = await dio.head(url, options: options);

    return res;
  }

  Future<dio_lib.Response> streamTrack(
    Request request,
    SourcedTrack track,
    Map<String, dynamic> headers,
  ) async {
    AppLogger.log.i(
      "GET request for track: ${track.query.name}\n"
      "Range: ${request.headers['range']}",
    );

    final trackCacheFile = File(await _getTrackCacheFilePath(track));

    String url = track.url ??
        await ref
            .read(sourcedTrackProvider(track.query).notifier)
            .swapWithNextSibling()
            .then((track) => track.url!);

    final options = Options(
      headers: {
        // Forward only the range header — spreading all client headers would
        // leak whatever a LAN client sends (cookies, auth) to the upstream
        // content server.
        if (headers["range"] != null) "range": headers["range"],
        "user-agent": _randomUserAgent,
        "Cache-Control": "max-age=3600",
        "Connection": "keep-alive",
        "host": Uri.parse(url).host,
      },
      responseType: ResponseType.stream,
      validateStatus: (status) => status! < 400,
    );

    // GET directly (no probing HEAD first — that cost a full roundtrip at
    // every track start); if the cached URL has expired, refresh and retry.
    dio_lib.Response<ResponseBody> res;
    try {
      res = await dio.get<ResponseBody>(url, options: options);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);

      final sourcedTrack = await ref
          .read(sourcedTrackProvider(track.query).notifier)
          .refreshStreamingUrl();

      url = sourcedTrack.url!;
      res = await dio.get<ResponseBody>(url, options: options);
    }

    // Redirect to m3u8 link directly as it handles range requests internally
    if (res.headers.value("content-type") ==
        "application/vnd.apple.mpegurl") {
      return dio_lib.Response<Uint8List>(
        statusCode: 301,
        statusMessage: "M3U8 Redirect",
        headers: Headers.fromMap({
          "location": [url],
          "content-type": ["application/vnd.apple.mpegurl"],
        }),
        requestOptions: RequestOptions(path: request.requestedUri.toString()),
        isRedirect: true,
      );
    }

    AppLogger.log.i(
      "Response for track: ${track.query.name}\n"
      "Status Code: ${res.statusCode}\n"
      "Headers: ${res.headers.map}",
    );

    if (!userPreferences.cacheMusic) {
      return res;
    }

    final resStream = res.data!.stream.asBroadcastStream();

    final trackPartialCacheFile = File("${trackCacheFile.path}.part");
    if (!await trackPartialCacheFile.exists()) {
      await trackPartialCacheFile.create(recursive: true);
    }

    // Write the stream to the file based on the range
    final partialCacheFileSink =
        trackPartialCacheFile.openWrite(mode: FileMode.writeOnlyAppend);
    final contentRange = res.headers.value("content-range") != null
        ? ContentRangeHeader.parse(res.headers.value("content-range") ?? "")
        : ContentRangeHeader(0, 0, 0);

    resStream.listen(
      (data) {
        partialCacheFileSink.add(data);
      },
      onError: (e, stack) {
        partialCacheFileSink.close();
      },
      onDone: () async {
        await partialCacheFileSink.close();

        final fileLength = await trackPartialCacheFile.length();
        if (fileLength != contentRange.total) return;

        await trackPartialCacheFile.rename(trackCacheFile.path);

        if (track.qualityPreset!.getFileExtension() == "weba") return;

        final imageBytes = await ServiceUtils.downloadImage(
          track.query.album.images.asUrlString(
            placeholder: ImagePlaceholder.albumArt,
            index: 1,
          ),
        );

        await MetadataGod.writeMetadata(
          file: trackCacheFile.path,
          metadata: track.query.toMetadata(
            imageBytes: imageBytes,
            fileLength: fileLength,
          ),
        ).catchError((e, stackTrace) {
          AppLogger.reportError(e, stackTrace);
        });
      },
      cancelOnError: true,
    );

    res.data?.stream =
        resStream; // To avoid Stream has been already listened to exception
    return res;
  }

  /// Serves a natively downloaded file for tracks whose media was enqueued
  /// (pointing at the server) before the download finished, so playback still
  /// uses the local file instead of an online stream.
  Future<Response?> _serveDownloadedFile(
    Request request,
    String trackId, {
    required bool headOnly,
  }) async {
    final path =
        ref.read(downloadedTracksProvider.notifier).pathFor(trackId);
    if (path == null) return null;

    final file = File(path);
    final length = await file.length();
    final extension =
        path.split('.').last.toLowerCase().replaceAll("m4a", "mp4");
    return _serveLocalFile(
      request,
      file,
      length,
      "audio/$extension",
      headOnly: headOnly,
    );
  }

  /// @head('/stream/<trackId>')
  Future<Response> headStreamTrackId(Request request, String trackId) async {
    try {
      final downloaded =
          await _serveDownloadedFile(request, trackId, headOnly: true);
      if (downloaded != null) return downloaded;

      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final cached =
          await _serveCachedFile(request, sourcedTrack, headOnly: true);
      if (cached != null) return cached;

      final res = await streamTrackInformation(
        request,
        sourcedTrack,
      );

      return Response(
        res.statusCode!,
        headers: res.headers.map,
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Response.internalServerError();
    }
  }

  /// @get('/stream/<trackId>')
  Future<Response> getStreamTrackId(Request request, String trackId) async {
    try {
      final downloaded =
          await _serveDownloadedFile(request, trackId, headOnly: false);
      if (downloaded != null) return downloaded;

      final sourcedTrack = await _getSourcedTrack(request, trackId);

      if (sourcedTrack == null) {
        return Response.notFound("Track not found in the current queue");
      }

      final cached =
          await _serveCachedFile(request, sourcedTrack, headOnly: false);
      if (cached != null) return cached;

      final res = await streamTrack(
        request,
        sourcedTrack,
        request.headers,
      );

      if (res.data is ResponseBody) {
        return Response(
          res.statusCode!,
          body: (res.data as ResponseBody).stream,
          headers: res.headers.map,
        );
      }

      return Response(
        res.statusCode!,
        body: res.data,
        headers: res.headers.map,
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Response.internalServerError();
    }
  }

  /// @get('/playback/toggle-playback')
  Future<Response> togglePlayback(Request request) async {
    audioPlayer.isPlaying
        ? await audioPlayer.pause()
        : await audioPlayer.resume();

    return Response.ok("Playback toggled");
  }

  /// @get('/playback/previous')
  Future<Response> previousTrack(Request request) async {
    await audioPlayer.skipToPrevious();
    return Response.ok("Previous track");
  }

  /// @get('/playback/next')
  Future<Response> nextTrack(Request request) async {
    await audioPlayer.skipToNext();
    return Response.ok("Next track");
  }
}

final serverPlaybackRoutesProvider =
    Provider((ref) => ServerPlaybackRoutes(ref));
