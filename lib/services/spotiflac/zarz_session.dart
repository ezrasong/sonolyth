import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';

/// Thrown when a signed v2 request needs a (re)verified session — i.e. there is
/// no stored session, it expired, or the gateway rejected it (401/428). Playback
/// resolution treats this like a transient miss (plays YouTube UNCACHED) so a
/// track upgrades to lossless once the user completes verification, rather than
/// hard-failing. [challengeUrl] carries the Turnstile URL when one is available.
class ZarzVerificationRequiredException implements Exception {
  final String? challengeUrl;
  const ZarzVerificationRequiredException([this.challengeUrl]);

  @override
  String toString() =>
      "Zarz lossless access needs verification (Turnstile)"
      "${challengeUrl == null ? "" : ": $challengeUrl"}";
}

/// Result of a bootstrap attempt: either the session was established directly
/// (no human check needed) or a Turnstile [challengeUrl] must be opened.
class ZarzBootstrapResult {
  /// True when bootstrap returned a usable session straight away.
  final bool authenticated;

  /// The Turnstile challenge URL to open in a WebView, when verification is
  /// required (null when [authenticated]).
  final String? challengeUrl;

  const ZarzBootstrapResult({required this.authenticated, this.challengeUrl});
}

/// A single persisted signed-session record.
class _SessionRecord {
  String installId;
  String sessionId;
  String sessionSecret;
  String expiresAt;

  _SessionRecord({
    required this.installId,
    this.sessionId = "",
    this.sessionSecret = "",
    this.expiresAt = "",
  });

  bool get hasSession => sessionId.isNotEmpty && sessionSecret.isNotEmpty;

  DateTime? get expiry => DateTime.tryParse(expiresAt);

  Map<String, dynamic> toJson() => {
        "install_id": installId,
        "session_id": sessionId,
        "session_secret": sessionSecret,
        "expires_at": expiresAt,
      };

  factory _SessionRecord.fromJson(Map<String, dynamic> json) => _SessionRecord(
        installId: (json["install_id"] ?? "").toString(),
        sessionId: (json["session_id"] ?? "").toString(),
        sessionSecret: (json["session_secret"] ?? "").toString(),
        expiresAt: (json["expires_at"] ?? "").toString(),
      );
}

/// Client for the zarz **v2** gateway's signed-session protocol, a faithful
/// port of SpotiFLAC-Mobile 4.7's `signedSession` runtime.
///
/// Since ~July 2026 the old UA-gated `/v1/dl/*` endpoints are **retired**
/// (HTTP 410 `V1_RETIRED`). The v2 API instead requires, per install:
///  1. a **Cloudflare Turnstile** human check to bootstrap a session
///     (persisted, auto-refreshed — a one-time step, not per play);
///  2. **HMAC-signed** requests (a rolling key derived from the session secret);
///  3. a per-download **ticket** (`POST /tickets` → `X-Zarz-Ticket`).
///
/// One instance exists per provider "app version" ([_appVersion]) because the
/// gateway scopes sessions by it; [qobuz] and [tidal] are the shared singletons.
class ZarzSession {
  // Shared config across providers (from the extensions' `signedSession`).
  static const _baseUrl = "https://api.zarz.moe/v2";
  static const _platform = "extension";
  static const _schemeLabel = "ZARZ-HMAC-V1";
  static const _headerPrefix = "X-Zarz-";
  static const _timeWindowSeconds = 300;
  static const _callbackUrl = "spotiflac://session-grant";

  static const _bootstrapEndpoint = "/bootstrap";
  static const _challengeEndpoint = "/challenge";
  static const _exchangeEndpoint = "/session/exchange";
  static const _refreshEndpoint = "/session/refresh";

  /// Refresh when the session has this little life left.
  static const _refreshSkew = Duration(hours: 1);

  /// Max simultaneous signed requests. Prefetch fans out several upcoming-track
  /// resolves at once (each = a ticket + a dl call); capping in-flight requests
  /// keeps that burst from tripping the gateway's rate limiter (which would drop
  /// those tracks to the YouTube fallback), mirroring the old playback lane.
  static const _maxConcurrent = 4;

  /// One quick 429 retry so a momentary rate-limit is absorbed instead of
  /// instantly abandoning lossless, without stalling on a long backoff.
  static const _maxAttempts = 2;
  static const _maxRetryBackoff = Duration(seconds: 2);

  /// Per-provider gateway app version (e.g. `qobuz-web@1.1.0`). Sessions are
  /// scoped by it, so each provider verifies independently.
  final String _appVersion;

  /// A stable id used as both the persistence key and the challenge `state`.
  final String _stateId;

  final Dio _dio;

  _SessionRecord? _record;
  Future<void>? _refreshInFlight;

  /// Gateway-vs-device clock offset learned from response `Date` headers.
  /// Signatures embed a timestamp the gateway checks against a ±300s window;
  /// a skewed device clock (chronic on the emulator, seen on phones too) made
  /// every signed request 401 — which then *cleared the session* and forced a
  /// fresh Turnstile. Signing with server-corrected time removes that failure
  /// mode entirely.
  Duration _serverTimeOffset = Duration.zero;

  /// Whether we've already opportunistically refreshed this process run.
  /// Refreshing once per app session (not only inside the last-hour skew
  /// window) means every listening session extends the session's life, so it
  /// only ever expires after a long stretch of not using the app at all.
  bool _refreshedThisRun = false;

  /// Server-corrected wall clock.
  DateTime _now() => DateTime.now().toUtc().add(_serverTimeOffset);

  /// Learns the gateway clock from a response's `Date` header.
  void _syncClock(Response res) {
    try {
      final header = res.headers.value("date");
      if (header == null || header.isEmpty) return;
      final serverTime = HttpDate.parse(header);
      _serverTimeOffset = serverTime.difference(DateTime.now().toUtc());
    } catch (_) {
      // An unparsable Date header just means no correction.
    }
  }

  // Counting-semaphore state for the concurrency cap.
  int _inFlight = 0;
  final List<Completer<void>> _waiters = [];

  ZarzSession({
    required String appVersion,
    required String stateId,
    Dio? dio,
  })  : _appVersion = appVersion,
        _stateId = stateId,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));

  /// Qobuz provider session (gateway app version `qobuz-web@1.1.0`).
  static final ZarzSession qobuz = ZarzSession(
    appVersion: "qobuz-web@1.1.0",
    stateId: "qobuz-web",
  );

  /// Tidal provider session (gateway app version `tidal-web@1.1.0`).
  static final ZarzSession tidal = ZarzSession(
    appVersion: "tidal-web@1.1.0",
    stateId: "tidal-web",
  );

  String get _prefsKey => "zarz_session_$_appVersion";

  Uri _url(String endpoint) => Uri.parse("$_baseUrl$endpoint");

  // ---- Persistence -------------------------------------------------------

  Future<_SessionRecord> _load() async {
    if (_record != null) return _record!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _SessionRecord record;
    if (raw != null && raw.isNotEmpty) {
      try {
        record = _SessionRecord.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        record = _SessionRecord(installId: _randomHex(16));
      }
    } else {
      record = _SessionRecord(installId: _randomHex(16));
    }
    if (record.installId.isEmpty) record.installId = _randomHex(16);
    _record = record;
    await _save(record);
    return record;
  }

  Future<void> _save(_SessionRecord record) async {
    _record = record;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(record.toJson()));
  }

  /// Whether a non-expired session is stored.
  Future<bool> isAuthenticated() async {
    final record = await _load();
    if (!record.hasSession) return false;
    final expiry = record.expiry;
    if (expiry != null && _now().isAfter(expiry)) return false;
    return true;
  }

  /// Forgets the stored session (keeps the install id).
  Future<void> clear() async {
    final record = await _load();
    record
      ..sessionId = ""
      ..sessionSecret = ""
      ..expiresAt = "";
    await _save(record);
  }

  // ---- Verification (Turnstile) flow ------------------------------------

  /// Starts verification: GET `/bootstrap`. If the gateway hands back a session
  /// directly it is saved and [ZarzBootstrapResult.authenticated] is true;
  /// otherwise a Turnstile [ZarzBootstrapResult.challengeUrl] is returned for
  /// the caller to open in a WebView, capturing the `spotiflac://session-grant`
  /// redirect's `grant` and passing it to [completeGrant].
  Future<ZarzBootstrapResult> bootstrap() async {
    final record = await _load();
    final uri = _url(_bootstrapEndpoint).replace(queryParameters: {
      "app_version": _appVersion,
      "install_id": record.installId,
    });

    final res = await _dio.getUri(
      uri,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          "Accept": "application/json",
          "User-Agent": "SpotiFLAC-Mobile/$_appVersion",
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    _syncClock(res);

    final data = res.data is Map ? res.data as Map : {};

    // Bootstrap issued a session directly — no human check needed.
    final sessionId = (data["session_id"] ?? "").toString();
    final sessionSecret = (data["session_secret"] ?? "").toString();
    final expiresAt = (data["expires_at"] ?? "").toString();
    if (sessionId.isNotEmpty &&
        sessionSecret.isNotEmpty &&
        expiresAt.isNotEmpty) {
      record
        ..sessionId = sessionId
        ..sessionSecret = sessionSecret
        ..expiresAt = expiresAt;
      await _save(record);
      return const ZarzBootstrapResult(authenticated: true);
    }

    // Otherwise a Turnstile challenge must be solved.
    var authUrl = (data["auth_url"] ?? data["challenge_url"] ?? "").toString();
    if (authUrl.isEmpty) {
      final challengeId = (data["challenge_id"] ?? "").toString();
      if (challengeId.isNotEmpty) {
        authUrl = _buildChallengeUrl(challengeId);
      }
    }
    if (authUrl.isEmpty) {
      throw const ZarzVerificationRequiredException();
    }
    return ZarzBootstrapResult(authenticated: false, challengeUrl: authUrl);
  }

  String _buildChallengeUrl(String challengeId) {
    final callback = Uri.parse(_callbackUrl).replace(queryParameters: {
      "cb_version": "v2grant",
      "state": _stateId,
    });
    return _url(_challengeEndpoint).replace(queryParameters: {
      "id": challengeId,
      "cb": callback.toString(),
    }).toString();
  }

  /// Completes verification: exchanges the [grant] captured from the
  /// `spotiflac://session-grant` redirect for a session at `/session/exchange`.
  Future<void> completeGrant(String grant) async {
    final record = await _load();
    final body = jsonEncode({
      "grant": grant,
      "install_id": record.installId,
      "app_version": _appVersion,
      "platform": _platform,
    });
    final res = await _dio.postUri(
      _url(_exchangeEndpoint),
      data: body,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "User-Agent": "SpotiFLAC-Mobile/$_appVersion",
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (res.statusCode == null || res.statusCode! >= 300) {
      throw const ZarzVerificationRequiredException();
    }
    final data = res.data is Map ? res.data as Map : {};
    final sessionId = (data["session_id"] ?? "").toString();
    final sessionSecret = (data["session_secret"] ?? "").toString();
    final expiresAt = (data["expires_at"] ?? "").toString();
    if (sessionId.isEmpty || sessionSecret.isEmpty || expiresAt.isEmpty) {
      throw const ZarzVerificationRequiredException();
    }
    record
      ..sessionId = sessionId
      ..sessionSecret = sessionSecret
      ..expiresAt = expiresAt;
    await _save(record);
  }

  // ---- Signed requests --------------------------------------------------

  /// Mints a single-use download ticket for [id] and returns its id, to be sent
  /// as `X-Zarz-Ticket` on the matching `/dl/*` call. [id] must be the exact
  /// value the gateway hashes at consume time (the track URL for Qobuz, the bare
  /// track id for Tidal).
  Future<String> mintTicket(String provider, String type, String id) async {
    final resourceHash =
        sha256.convert(utf8.encode("$provider:$type:${id.toLowerCase()}")).toString();
    final payload = await signedPostJson("/tickets", {
      "capability": "download_ticket",
      "provider": provider,
      "resource_hash": resourceHash,
    });
    final ticket = (payload["ticket_id"] ?? payload["ticket"] ?? "").toString();
    if (ticket.isEmpty) {
      throw StateError("signed ticket response missing ticket_id");
    }
    return ticket;
  }

  /// Signed `POST` of a JSON [body] to [path] (relative to the v2 base). Returns
  /// the decoded JSON on success. Throws [ZarzRateLimitedException] on 429,
  /// [ZarzVerificationRequiredException] when the session is missing/expired or
  /// rejected (401/428), and a generic error on other failures.
  Future<Map<String, dynamic>> signedPostJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? extraHeaders,
  }) async {
    final record = await _ensureSession();
    final bodyText = jsonEncode(body);

    await _acquire();
    try {
      var authRetried = false;
      for (var attempt = 0;; attempt++) {
        final res = await _signedRequest(
          record: record,
          method: "POST",
          path: path,
          bodyText: bodyText,
          extraHeaders: extraHeaders,
        );

        final status = res.statusCode ?? 0;
        if (status == 429) {
          if (attempt >= _maxAttempts - 1) throw ZarzRateLimitedException();
          await Future.delayed(_retryAfter(res) ?? const Duration(seconds: 1));
          continue;
        }
        if (status == 401 || status == 428) {
          // Don't nuke the session on the first rejection — that's what made
          // every transient failure (clock skew before the offset was learned,
          // a gateway blip, a refresh racing an in-flight request) cost the
          // user a full Turnstile. Re-sync the clock (done above via the
          // response's Date header), try one refresh, and retry once; only a
          // second rejection means the session is genuinely dead.
          if (!authRetried) {
            authRetried = true;
            await _maybeRefresh(record);
            continue;
          }
          await clear();
          throw const ZarzVerificationRequiredException();
        }
        if (status < 200 || status >= 300) {
          throw StateError("Zarz v2 $path failed: HTTP $status");
        }
        if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
        if (res.data is String && (res.data as String).isNotEmpty) {
          return Map<String, dynamic>.from(
              jsonDecode(res.data as String) as Map);
        }
        return {};
      }
    } finally {
      _release();
    }
  }

  Duration? _retryAfter(Response res) {
    final header = res.headers.value("retry-after");
    final seconds = header == null ? null : int.tryParse(header.trim());
    if (seconds == null) return null;
    var d = Duration(seconds: seconds.clamp(1, 60));
    if (d > _maxRetryBackoff) d = _maxRetryBackoff;
    return d;
  }

  Future<void> _acquire() async {
    if (_inFlight < _maxConcurrent) {
      _inFlight++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _inFlight--;
    }
  }

  Future<_SessionRecord> _ensureSession() async {
    final record = await _load();
    if (!record.hasSession) {
      throw const ZarzVerificationRequiredException();
    }
    final expiry = record.expiry;
    if (expiry != null) {
      if (_now().isAfter(expiry)) {
        // Grace attempt: the gateway may still honor a refresh from a
        // just-expired session (and "expired" may itself be device-clock
        // error). Only give up — and cost the user a Turnstile — if the
        // refresh leaves us without a live expiry.
        await _maybeRefresh(record);
        final refreshed = record.expiry;
        if (refreshed == null || _now().isAfter(refreshed)) {
          await clear();
          throw const ZarzVerificationRequiredException();
        }
      } else if (expiry.difference(_now()) <= _refreshSkew ||
          !_refreshedThisRun) {
        // Refresh near expiry, and also once per app run regardless — every
        // listening session then pushes the expiry out, so re-verification
        // only ever happens after a long stretch of not using the app.
        await _maybeRefresh(record);
      }
    }
    return record;
  }

  Future<void> _maybeRefresh(_SessionRecord record) {
    // Coalesce concurrent refreshes (prefetch fans out several resolves at once).
    return _refreshInFlight ??= _refresh(record).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> _refresh(_SessionRecord record) async {
    try {
      final res = await _signedRequest(
        record: record,
        method: "POST",
        path: _refreshEndpoint,
        bodyText: jsonEncode({"install_id": record.installId}),
      );
      // The gateway answered (whatever the verdict) — the once-per-run
      // opportunistic refresh has done its job for this process.
      _refreshedThisRun = true;
      if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300) return;
      final data = res.data is Map ? res.data as Map : {};
      final sessionId = (data["session_id"] ?? "").toString();
      final sessionSecret = (data["session_secret"] ?? "").toString();
      final expiresAt = (data["expires_at"] ?? "").toString();
      var changed = false;
      if (sessionId.isNotEmpty) {
        record.sessionId = sessionId;
        changed = true;
      }
      if (sessionSecret.isNotEmpty) {
        record.sessionSecret = sessionSecret;
        changed = true;
      }
      if (expiresAt.isNotEmpty && expiresAt != record.expiresAt) {
        record.expiresAt = expiresAt;
        changed = true;
      }
      if (changed) await _save(record);
    } catch (e, stack) {
      // A failed refresh isn't fatal — the current session may still be valid.
      AppLogger.reportError(e, stack);
    }
  }

  Future<Response> _signedRequest({
    required _SessionRecord record,
    required String method,
    required String path,
    required String bodyText,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _url(path);
    // Dio sends a String body as its verbatim UTF-8 bytes, so hashing those
    // same bytes keeps the Body-SHA256 header consistent with what's sent.
    final bodyBytes = utf8.encode(bodyText);
    // Server-corrected time: the gateway checks the signed timestamp against
    // a ±300s window, and a skewed device clock would 401 every request.
    final now = DateTime.fromMillisecondsSinceEpoch(
      _now().millisecondsSinceEpoch,
      isUtc: true,
    );
    final ts = now.toIso8601String(); // e.g. 2026-07-13T14:30:00.123Z
    final nonce = _randomHex(12);
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;

    final signed = computeSignature(
      method: method,
      escapedPath: uri.path, // incl. /v2 prefix, e.g. /v2/dl/qbz
      bodyBytes: bodyBytes,
      ts: ts,
      nonce: nonce,
      epochSeconds: epochSeconds,
      sessionId: record.sessionId,
      sessionSecret: record.sessionSecret,
      appVersion: _appVersion,
    );
    final bodyHash = signed.bodyHash;
    final sig = signed.signature;

    final res = await _dio.requestUri(
      uri,
      data: bodyText,
      options: Options(
        method: method,
        responseType: ResponseType.json,
        contentType: "application/json",
        headers: {
          "Accept": "application/json",
          "User-Agent": "SpotiFLAC-Mobile/$_appVersion",
          "${_headerPrefix}Session": record.sessionId,
          "${_headerPrefix}Timestamp": ts,
          "${_headerPrefix}Nonce": nonce,
          "${_headerPrefix}Body-SHA256": bodyHash,
          "${_headerPrefix}Signature": sig,
          "${_headerPrefix}App-Version": _appVersion,
          "${_headerPrefix}Platform": _platform,
          ...?extraHeaders,
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    // Every response teaches us the gateway clock, so even the first 401 of a
    // skewed device self-corrects before the retry.
    _syncClock(res);
    return res;
  }

  // ---- Signing -----------------------------------------------------------

  /// Computes the v2 HMAC signature for a request — a direct port of the
  /// gateway's `SPOTIFLAC/ZARZ-HMAC-V1` scheme. Pure and deterministic given
  /// its inputs, so it can be verified against a known vector in tests.
  ///
  /// The scheme: a per-time-window rolling key `rk = b64url(HMAC(secret,
  /// "<window>:<sessionId>"))`, then `sig = b64url(HMAC(rk, signingInput))`
  /// where the second HMAC keys on the ASCII bytes of the `rk` string. All
  /// base64 is URL-safe WITHOUT padding.
  @visibleForTesting
  static ({String signature, String rollingKey, String bodyHash})
      computeSignature({
    required String method,
    required String escapedPath,
    required List<int> bodyBytes,
    required String ts,
    required String nonce,
    required int epochSeconds,
    required String sessionId,
    required String sessionSecret,
    required String appVersion,
    String schemeLabel = _schemeLabel,
    String platform = _platform,
    int timeWindowSeconds = _timeWindowSeconds,
  }) {
    final bodyHash = sha256.convert(bodyBytes).toString();
    final window = epochSeconds ~/ timeWindowSeconds;
    final rk = _b64UrlNoPad(_hmac(sessionSecret, "$window:$sessionId"));
    final signingInput = [
      schemeLabel,
      method,
      escapedPath,
      "", // escaped query (none on these POSTs)
      bodyHash,
      ts,
      nonce,
      sessionId,
      appVersion,
      platform,
    ].join("\n");
    final sig = _b64UrlNoPad(_hmac(rk, signingInput));
    return (signature: sig, rollingKey: rk, bodyHash: bodyHash);
  }

  // ---- Crypto helpers ----------------------------------------------------

  static List<int> _hmac(String key, String message) =>
      Hmac(sha256, utf8.encode(key)).convert(utf8.encode(message)).bytes;

  /// base64url WITHOUT padding, matching Go's `base64.RawURLEncoding`.
  static String _b64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll("=", "");

  static final _rng = Random.secure();

  static String _randomHex(int byteLength) {
    final buf = StringBuffer();
    for (var i = 0; i < byteLength; i++) {
      buf.write(_rng.nextInt(256).toRadixString(16).padLeft(2, "0"));
    }
    return buf.toString();
  }
}
