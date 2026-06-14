import 'dart:async';

import 'package:dio/dio.dart';

/// Thrown when the gateway keeps rate-limiting after exhausting retries, so
/// callers can surface "rate limited" instead of a generic no-match failure.
class ZarzRateLimitedException implements Exception {
  @override
  String toString() => "Gateway rate limited (429), retries exhausted";
}

/// The zarz gateway backs every SpotiFLAC download provider. It gates requests
/// on a `SpotiFLAC-Mobile/<version>` User-Agent and rate-limits to roughly
/// 5 requests / 10s, so all provider traffic funnels through this one client.
///
/// Bulk playlist downloads burn 2-3 gateway calls per track; without pacing,
/// long runs (hundreds of tracks) trip the limiter and every subsequent track
/// fails. All requests are therefore serialized with a minimum gap, and 429
/// responses are retried with backoff (honoring `Retry-After` when present).
class ZarzClient {
  static const userAgent = "SpotiFLAC-Mobile/4.5.6";

  /// 5 requests / 10s allowed; stay just under it on the serialized lane.
  static const _defaultMinRequestGap = Duration(milliseconds: 2100);
  static const _defaultMaxAttempts = 4;

  /// How many times a 429 is retried before giving up. Bulk downloads want the
  /// patient default; the interactive playback path overrides this so a
  /// rate-limited gateway falls back to YouTube quickly instead of stalling
  /// playback through the (up to ~35s) backoff chain.
  final int _maxAttempts;

  /// Minimum spacing between requests on the serialized lane.
  final Duration _minRequestGap;

  /// Max simultaneous in-flight requests. The default (1) serializes all
  /// traffic — correct for bulk downloads, which trip the limiter otherwise.
  /// The interactive playback lane raises this so prefetching several upcoming
  /// tracks resolves in parallel instead of stacking behind the serial
  /// throttle (which is what made lossless skips lag).
  final int _maxConcurrent;

  /// Caps the 429 backoff so an interactive resolve doesn't stall for the full
  /// exponential delay. Null = no cap (downloads).
  final Duration? _maxRetryBackoff;

  final Dio _dio;

  /// Tail of the request chain; serializes and paces the default lane.
  Future<void> _lastRequest = Future.value();
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Counting-semaphore state for the concurrent lane.
  int _inFlight = 0;
  final List<Completer<void>> _waiters = [];

  ZarzClient({
    Dio? dio,
    int maxAttempts = _defaultMaxAttempts,
    Duration minRequestGap = _defaultMinRequestGap,
    int maxConcurrent = 1,
    Duration? maxRetryBackoff,
  })  : _dio = dio ?? Dio(),
        _maxAttempts = maxAttempts,
        _minRequestGap = minRequestGap,
        _maxConcurrent = maxConcurrent,
        _maxRetryBackoff = maxRetryBackoff {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers["User-Agent"] = userAgent;
  }

  Future<T> _throttled<T>(Future<T> Function() request) {
    if (_maxConcurrent > 1) return _concurrent(request);

    final completer = Completer<T>();
    _lastRequest = _lastRequest.then((_) async {
      final sinceLast = DateTime.now().difference(_lastRequestTime);
      if (sinceLast < _minRequestGap) {
        await Future.delayed(_minRequestGap - sinceLast);
      }
      try {
        completer.complete(await _withRetry(request));
      } catch (e, stack) {
        completer.completeError(e, stack);
      } finally {
        _lastRequestTime = DateTime.now();
      }
    });
    return completer.future;
  }

  /// Concurrency-limited lane: up to [_maxConcurrent] requests run at once with
  /// no forced inter-request gap, so prefetching several upcoming tracks
  /// overlaps instead of serializing behind a 2.1s throttle.
  Future<T> _concurrent<T>(Future<T> Function() request) async {
    await _acquire();
    try {
      return await _withRetry(request);
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    while (_inFlight >= _maxConcurrent) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
    _inFlight++;
  }

  void _release() {
    _inFlight--;
    if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
  }

  Future<T> _withRetry<T>(Future<T> Function() request) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await request();
      } on DioException catch (e) {
        if (e.response?.statusCode != 429) rethrow;
        if (attempt >= _maxAttempts - 1) throw ZarzRateLimitedException();
        var delay = _retryAfter(e) ?? Duration(seconds: 5 << attempt);
        if (_maxRetryBackoff != null && delay > _maxRetryBackoff!) {
          delay = _maxRetryBackoff!;
        }
        await Future.delayed(delay);
      }
    }
  }

  Duration? _retryAfter(DioException e) {
    final header = e.response?.headers.value("retry-after");
    final seconds = header == null ? null : int.tryParse(header.trim());
    if (seconds == null) return null;
    return Duration(seconds: seconds.clamp(1, 60));
  }

  Future<dynamic> getJson(String url, {Map<String, dynamic>? query}) {
    return _throttled(() async {
      final response = await _dio.get(
        url,
        queryParameters: query,
        options: Options(responseType: ResponseType.json),
      );
      return response.data;
    });
  }

  Future<dynamic> postJson(String url, Map<String, dynamic> body) {
    return _throttled(() async {
      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          responseType: ResponseType.json,
          contentType: Headers.jsonContentType,
        ),
      );
      return response.data;
    });
  }
}

final zarzClient = ZarzClient();
