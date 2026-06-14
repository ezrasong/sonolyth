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

  /// 5 requests / 10s allowed; stay just under it.
  static const _minRequestGap = Duration(milliseconds: 2100);
  static const _defaultMaxAttempts = 4;

  /// How many times a 429 is retried before giving up. Bulk downloads want the
  /// patient default; the interactive playback path overrides this to 1 so a
  /// rate-limited gateway falls back to YouTube immediately instead of stalling
  /// playback through the (up to ~35s) backoff chain.
  final int _maxAttempts;

  final Dio _dio;

  /// Tail of the request chain; serializes and paces all gateway traffic.
  Future<void> _lastRequest = Future.value();
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);

  ZarzClient({Dio? dio, int maxAttempts = _defaultMaxAttempts})
      : _dio = dio ?? Dio(),
        _maxAttempts = maxAttempts {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers["User-Agent"] = userAgent;
  }

  Future<T> _throttled<T>(Future<T> Function() request) {
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

  Future<T> _withRetry<T>(Future<T> Function() request) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await request();
      } on DioException catch (e) {
        if (e.response?.statusCode != 429) rethrow;
        if (attempt >= _maxAttempts - 1) throw ZarzRateLimitedException();
        await Future.delayed(_retryAfter(e) ?? Duration(seconds: 5 << attempt));
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
