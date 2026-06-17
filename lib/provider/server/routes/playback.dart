import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio_lib;
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
import 'package:sonolyth/services/sourced_track/tidal_dash.dart';
import 'package:sonolyth/utils/service_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final _deviceClients = Set.unmodifiable({
  YoutubeApiClient.ios,
  YoutubeApiClient.android,
  YoutubeApiClient.mweb,
  YoutubeApiClient.safari,
});

/// Stable per-track client user-agent. The stream URL was resolved for one
/// client; rolling a fresh random UA on every request to the same URL invites
/// 403s whose only recovery is a multi-second refreshStreamingUrl round trip
/// — which is exactly the "previous track takes forever" stall, since only
/// the next track's open is masked by mpv's prefetch.
String? streamUserAgentFor(SourcedTrack track) => _deviceClients
    .elementAt(track.info.id.hashCode.abs() % _deviceClients.length)
    .payload["context"]["client"]["userAgent"];

/// A pre-fetched leading slice of a track held in memory: enough to start
/// playback instantly on a skip while the remainder streams from [upstreamUrl].
/// Keeps the speculative data cost to a few seconds of audio — unlike caching a
/// whole track ahead — and those bytes are the start of a track about to play.
typedef _HeadBuffer = ({
  Uint8List bytes,
  int total,
  String contentType,
  String upstreamUrl,
});

class ServerPlaybackRoutes {
  final Ref ref;
  UserPreferences get userPreferences => ref.read(userPreferencesProvider);
  AudioPlayerState get playlist => ref.read(audioPlayerProvider);
  final Dio dio;

  ServerPlaybackRoutes(this.ref) : dio = Dio();

  /// Cache files with a write already in progress (keyed by cache path) —
  /// a second concurrent writer would interleave bytes and corrupt the file.
  static final Set<String> _cacheWritesInFlight = {};

  /// Pre-fetched track heads (keyed by track id) for instant skips. Bounded to
  /// the most-recent few to keep memory small.
  static final Map<String, _HeadBuffer> _headBuffers = {};

  /// ~9s of CD-FLAC (much more for a lossy stream) — enough for mpv to start
  /// instantly and for the proxied remainder to catch up, while keeping the
  /// speculative data per track tiny.
  static const _headPrefixBytes = 1 * 1024 * 1024;

  /// Max heads held in memory at once (~8MB worst case).
  static const _headBufferMax = 4;

  Future<String> _getTrackCacheFilePath(SourcedTrack track) async {
    return join(
      await UserPreferencesNotifier.getMusicCacheDir(),
      ServiceUtils.sanitizeFilename(
        '${track.query.name} - ${track.query.artists.map((d) => d.name).join(",")} (${track.info.id}).${track.playbackFileExtension}',
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
      "audio/${track.playbackContainer}",
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
        "user-agent": streamUserAgentFor(track),
        "Cache-Control": "max-age=3600",
        "Connection": "keep-alive",
        "host": Uri.parse(url).host,
      },
      validateStatus: (status) => status! < 400,
    );

    dio_lib.Response res;
    try {
      res = await dio.head(url, options: options);
    } catch (e, stack) {
      // Stale/expired URL (e.g. a lapsed Qobuz signature): re-mint and retry,
      // mirroring the GET path, instead of 500ing the HEAD.
      AppLogger.reportError(e, stack);
      final sourcedTrack = await ref
          .read(sourcedTrackProvider(track.query).notifier)
          .refreshStreamingUrl();
      url = sourcedTrack.url!;
      options.headers!["host"] = Uri.parse(url).host;
      res = await dio.head(url, options: options);
    }

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
        "user-agent": streamUserAgentFor(track),
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
      // The refreshed URL may be a different host (a Qobuz re-sign, or a
      // YouTube fallback if Qobuz is down) — update the Host header so the
      // retry isn't sent with the previous origin's host.
      options.headers!["host"] = Uri.parse(url).host;
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

    // Don't dump the full upstream header map — it can carry Set-Cookie / CDN
    // auth tokens and correlates with signed stream URLs, and release logs
    // persist to .spotube_logs. A redacted summary is enough to debug.
    AppLogger.log.i(
      "Response for track: ${track.query.name}\n"
      "Status Code: ${res.statusCode}\n"
      "Content-Type: ${res.headers.value("content-type")}\n"
      "Content-Length: ${res.headers.value("content-length")}",
    );

    final contentRangeValue = res.headers.value("content-range");
    final contentRange = contentRangeValue != null
        ? ContentRangeHeader.parse(contentRangeValue)
        : null;
    // A 200 (no range) carries the total in content-length instead.
    final expectedTotal = contentRange?.total ??
        int.tryParse(res.headers.value("content-length") ?? "") ??
        0;

    res.data!.stream = await _teeToCacheFile(
      cacheFile: trackCacheFile,
      source: res.data!.stream,
      expectedTotal: expectedTotal,
      startsAtZero: contentRange == null || contentRange.start == 0,
      track: track,
    );
    return res;
  }

  /// Tees [source] to the music cache file for [track] and returns a stream
  /// that yields the same bytes. Used by both the live stream path and the
  /// prefix-buffer path so they cache identically.
  ///
  /// Caches ONLY a linear, byte-0, single-writer response: the old code
  /// appended every response to the .part file, so an mpv tail probe or a seek
  /// mid-download interleaved bytes at the wrong offsets, the completeness check
  /// never passed, and the cache silently never finished (re-streaming on every
  /// replay). A mid-file range, an unknown total, caching-off, or a second
  /// concurrent writer returns [source] unchanged (served, not cached). The
  /// write is best-effort — a cache failure never interrupts playback.
  Future<Stream<T>> _teeToCacheFile<T extends List<int>>({
    required File cacheFile,
    required Stream<T> source,
    required int expectedTotal,
    required bool startsAtZero,
    required SourcedTrack track,
  }) async {
    if (!userPreferences.cacheMusic ||
        expectedTotal <= 0 ||
        !startsAtZero ||
        _cacheWritesInFlight.contains(cacheFile.path)) {
      return source;
    }
    _cacheWritesInFlight.add(cacheFile.path);

    final broadcast = source.asBroadcastStream();

    final partialCacheFile = File("${cacheFile.path}.part");
    // A leftover partial from an aborted/older write would corrupt this linear
    // write — start clean.
    if (await partialCacheFile.exists()) {
      await partialCacheFile.delete();
    }
    await partialCacheFile.create(recursive: true);

    final sink = partialCacheFile.openWrite(mode: FileMode.writeOnlyAppend);

    broadcast.listen(
      (data) {
        sink.add(data);
      },
      onError: (e, stack) {
        _cacheWritesInFlight.remove(cacheFile.path);
        sink.close();
      },
      onDone: () async {
        try {
          await sink.close();

          final fileLength = await partialCacheFile.length();
          if (fileLength != expectedTotal) return;

          await partialCacheFile.rename(cacheFile.path);

          if (track.playbackFileExtension == "weba") return;

          final imageBytes = await ServiceUtils.downloadImage(
            track.query.album.images.asUrlString(
              placeholder: ImagePlaceholder.albumArt,
              index: 1,
            ),
          );

          await MetadataGod.writeMetadata(
            file: cacheFile.path,
            metadata: track.query.toMetadata(
              imageBytes: imageBytes,
              fileLength: fileLength,
            ),
          ).catchError((e, stackTrace) {
            AppLogger.reportError(e, stackTrace);
          });
        } finally {
          _cacheWritesInFlight.remove(cacheFile.path);
        }
      },
      cancelOnError: true,
    );

    return broadcast;
  }

  /// Pre-fetches the first [_headPrefixBytes] of [track] into memory so a later
  /// skip to it starts instantly (served from RAM) while the remainder streams.
  /// Tiny data cost (a few seconds of audio that is the start of a track about
  /// to play). No-op for TIDAL DASH (played natively), already-buffered tracks,
  /// and upstreams that don't report a total size (can't serve correct lengths).
  Future<void> prebufferHead(SourcedTrack track, {CancelToken? cancelToken}) async {
    final id = track.info.id;
    if (_headBuffers.containsKey(id)) return;
    final url = track.url;
    if (url == null || isDashUrl(url)) return;

    try {
      final res = await dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            "range": "bytes=0-${_headPrefixBytes - 1}",
            "user-agent": streamUserAgentFor(track),
            "host": Uri.parse(url).host,
          },
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final contentRangeValue = res.headers.value("content-range");
      final total = (contentRangeValue != null
              ? ContentRangeHeader.parse(contentRangeValue).total
              : null) ??
          int.tryParse(res.headers.value("content-length") ?? "");

      final builder = BytesBuilder(copy: false);
      await for (final chunk in res.data!.stream) {
        builder.add(chunk);
        if (builder.length >= _headPrefixBytes) break;
      }
      if (builder.isEmpty) return;

      var bytes = builder.takeBytes();
      if (bytes.length > _headPrefixBytes) {
        bytes = Uint8List.sublistView(bytes, 0, _headPrefixBytes);
      }
      // A range response gives the real total; without one, fall back to the
      // bytes we got (only valid if the whole short track fit in the prefix).
      final effectiveTotal =
          (total == null || total < bytes.length) ? bytes.length : total;
      if (effectiveTotal <= 0) return;

      _headBuffers[id] = (
        bytes: bytes,
        total: effectiveTotal,
        contentType:
            res.headers.value("content-type") ?? "audio/${track.playbackContainer}",
        upstreamUrl: url,
      );
      while (_headBuffers.length > _headBufferMax) {
        _headBuffers.remove(_headBuffers.keys.first);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
    } catch (_) {
      // Best effort — a failed pre-buffer just means a normal cold open on skip.
    }
  }

  /// Serves [track] starting from its in-memory [head] (instant) and proxying
  /// the remainder from the upstream, so a skip plays immediately without a cold
  /// network open. Returns null to fall back to normal streaming when the head
  /// can't be used (odd range, or the stored URL no longer answers — checked by
  /// opening the remainder BEFORE any head bytes are committed, so a dead URL
  /// never corrupts the stream).
  Future<Response?> _serveWithHeadBuffer(
    Request request,
    SourcedTrack track,
    _HeadBuffer head, {
    required bool headOnly,
  }) async {
    final total = head.total;
    final headLen = head.bytes.length;

    final rangeHeader = request.headers["range"];
    final match = rangeHeader == null
        ? null
        : RegExp(r"^bytes=(\d*)-(\d*)$").firstMatch(rangeHeader.trim());
    final isRange = match != null &&
        (match.group(1)!.isNotEmpty || match.group(2)!.isNotEmpty);

    int start = 0;
    int end = total - 1;
    if (isRange) {
      if (match.group(1)!.isEmpty) {
        start = max(0, total - int.parse(match.group(2)!));
      } else {
        start = int.parse(match.group(1)!);
        end = match.group(2)!.isEmpty
            ? total - 1
            : min(int.parse(match.group(2)!), total - 1);
      }
    }
    // Anything odd → let the normal path handle it.
    if (start < 0 || start > end || start >= total) return null;

    // Open the upstream for the proxied remainder FIRST. If it fails (the stored
    // URL expired), drop the head and fall back cleanly — before sending bytes.
    Stream<Uint8List>? proxyStream;
    if (end >= headLen) {
      final proxyStart = max(start, headLen);
      try {
        final res = await dio.get<ResponseBody>(
          head.upstreamUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              "range": "bytes=$proxyStart-$end",
              "user-agent": streamUserAgentFor(track),
              "host": Uri.parse(head.upstreamUrl).host,
            },
            validateStatus: (status) => status != null && status < 400,
          ),
        );
        proxyStream = res.data!.stream;
      } catch (_) {
        _headBuffers.remove(track.info.id);
        return null;
      }
    }

    final responseHeaders = <String, String>{
      "content-type": head.contentType,
      "content-length": "${end - start + 1}",
      "accept-ranges": "bytes",
      if (isRange) "content-range": "bytes $start-$end/$total",
    };
    final status = isRange ? 206 : 200;
    if (headOnly) return Response(status, headers: responseHeaders);

    Stream<Uint8List> body() async* {
      if (start < headLen) {
        yield Uint8List.sublistView(head.bytes, start, min(end + 1, headLen));
      }
      if (proxyStream != null) yield* proxyStream;
    }

    // A full byte-0 response caches just like the live path.
    final stream = (start == 0 && end == total - 1)
        ? await _teeToCacheFile(
            cacheFile: File(await _getTrackCacheFilePath(track)),
            source: body(),
            expectedTotal: total,
            startsAtZero: true,
            track: track,
          )
        : body();

    return Response(status, body: stream, headers: responseHeaders);
  }

  /// In-flight DASH stitch jobs keyed by track id so mpv's HEAD + GET + range
  /// requests share ONE stitch instead of each re-downloading the track.
  static final Map<String, Future<File>> _dashStitchJobs = {};

  /// Serves a TIDAL DASH track by stitching its FLAC segments into one COMPLETE
  /// fMP4 file, then serving that with Range support.
  ///
  /// TIDAL lossless is FLAC split across dozens of fMP4 segments. media_kit's
  /// mpv canNOT play a DASH manifest or a non-seekable progressive concat — both
  /// give "Error decoding audio" on-device (verified in `.spotube_logs`). It
  /// only reliably plays a complete, seekable file, exactly like a download. So
  /// we assemble the whole track once (cached + reused for the session) and
  /// [_serveLocalFile] serves it with content-length + ranges. The first play of
  /// a track buffers while it assembles; replays/seeks are instant.
  Future<Response> _serveDashTrack(
    Request request,
    SourcedTrack track, {
    required bool headOnly,
  }) async {
    final File file;
    try {
      file = await _stitchedDashFile(track);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Response.internalServerError(
        body: "Could not resolve Tidal DASH track",
      );
    }
    final length = await file.length();
    return _serveLocalFile(request, file, length, "audio/mp4",
        headOnly: headOnly);
  }

  /// The complete stitched fMP4 file for [track], built once and shared across
  /// concurrent requests; re-stitches if a prior file was pruned away.
  Future<File> _stitchedDashFile(SourcedTrack track) async {
    final existing = _dashStitchJobs[track.info.id];
    if (existing != null) {
      try {
        final f = await existing;
        if (await f.exists() && await f.length() > 0) return f;
      } catch (_) {/* fall through to a fresh stitch */}
      _dashStitchJobs.remove(track.info.id);
    }
    final job = _stitchDashToFile(track).catchError((Object e) {
      _dashStitchJobs.remove(track.info.id);
      throw e;
    });
    _dashStitchJobs[track.info.id] = job;
    return job;
  }

  Future<File> _stitchDashToFile(SourcedTrack track) async {
    final dir = await UserPreferencesNotifier.getMusicCacheDir();
    final file = File(join(dir, "tidal-dash-${track.info.id}.mp4"));
    if (await file.exists() && await file.length() > 0) return file;

    final mpdUrl = stripDashUrl(track.url!);
    final stitcher = TidalDashStitcher(dio);
    final manifest = await stitcher.fetchManifest(mpdUrl);
    if (manifest.isEmpty) {
      throw StateError(
        "Tidal DASH manifest yielded no segments for "
        "'${track.query.name}' ($mpdUrl)",
      );
    }

    await _pruneStitchedDashFiles(dir, keep: 4);

    final part = File("${file.path}.part");
    if (await part.exists()) await part.delete();
    await part.create(recursive: true);
    final sink = part.openWrite();
    var ok = false;
    try {
      await for (final chunk in stitcher.streamSegments(manifest)) {
        sink.add(chunk);
      }
      await sink.flush();
      ok = true;
    } finally {
      await sink.close();
      if (!ok && await part.exists()) {
        try {
          await part.delete();
        } catch (_) {/* best effort */}
      }
    }
    await part.rename(file.path);
    return file;
  }

  /// Keeps only the [keep] most-recent stitched DASH files so a session doesn't
  /// accumulate ~20MB per played TIDAL track in the cache dir.
  Future<void> _pruneStitchedDashFiles(String dir, {required int keep}) async {
    try {
      final files = <File>[];
      await for (final entity in Directory(dir).list()) {
        if (entity is File &&
            basename(entity.path).startsWith("tidal-dash-") &&
            entity.path.endsWith(".mp4")) {
          files.add(entity);
        }
      }
      if (files.length <= keep) return;
      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      for (final stale in files.skip(keep)) {
        try {
          await stale.delete();
        } catch (_) {/* best effort */}
      }
    } catch (_) {/* never block playback on cleanup */}
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

      // TIDAL DASH: stitch into a complete file and report its real length so
      // mpv knows the duration and can seek (the stitch is shared with the GET).
      if (isDashUrl(sourcedTrack.url)) {
        return await _serveDashTrack(request, sourcedTrack, headOnly: true);
      }

      // Prefix buffer present: report its sizing so HEAD and the follow-up GET
      // agree (the GET serves head-from-memory + proxied remainder).
      final head = _headBuffers[trackId];
      if (head != null) {
        final headResponse = await _serveWithHeadBuffer(
          request,
          sourcedTrack,
          head,
          headOnly: true,
        );
        if (headResponse != null) return headResponse;
      }

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

      // TIDAL DASH: stitch the FLAC segments into one complete seekable file
      // (the only thing media_kit reliably plays) and serve it with ranges.
      if (isDashUrl(sourcedTrack.url)) {
        return await _serveDashTrack(request, sourcedTrack, headOnly: false);
      }

      // Prefix buffer: a skip starts instantly from the in-memory head while the
      // remainder streams. Falls through to live streaming when there's no head.
      final head = _headBuffers[trackId];
      if (head != null) {
        final headResponse = await _serveWithHeadBuffer(
          request,
          sourcedTrack,
          head,
          headOnly: false,
        );
        if (headResponse != null) return headResponse;
      }

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
