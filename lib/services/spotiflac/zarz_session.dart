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
/// resolution treats this as a transient miss and does NOT cache the failure,
/// so a track resolves normally once the user completes verification rather
/// than staying poisoned. [challengeUrl] carries the Turnstile URL when one is
/// available.
class ZarzVerificationRequiredException implements Exception {
  final String? challengeUrl;
  const ZarzVerificationRequiredException([this.challengeUrl]);

  @override
  String toString() =>
      "Zarz lossless access needs verification (Turnstile)"
      "${challengeUrl == null ? "" : ": $challengeUrl"}";
}

/// The gateway's structured rejection body, e.g.
/// `{"error":"Unauthorized","code":"SESSION_INVALID","origin":"gateway",
///   "action":"bootstrap_session"}`.
///
/// Probed live against `api.zarz.moe/v2/tickets` (2026-08-30): every plain auth
/// failure — no signature headers at all, a bogus signature, a six-year-skewed
/// timestamp — answers **401 with exactly that code/action pair**. So a status
/// alone is not a verdict on the session, and a **428 is not an auth failure**:
/// it is `Precondition Required`, something about the *request*. Clearing on it
/// cost the user a full Turnstile for a session that was fine (CONTEXT §16g).
class _GatewayError {
  final String code;
  final String action;
  const _GatewayError({this.code = "", this.action = ""});

  factory _GatewayError.from(Response res) {
    try {
      final data = res.data is Map
          ? res.data as Map
          : res.data is String && (res.data as String).isNotEmpty
              ? jsonDecode(res.data as String) as Map
              : const {};
      return _GatewayError(
        code: (data["code"] ?? "").toString(),
        action: (data["action"] ?? "").toString(),
      );
    } catch (_) {
      return const _GatewayError();
    }
  }

  /// True only when the gateway itself says the stored session is finished and
  /// a new bootstrap is the remedy. Anything else — an unrecognised code, an
  /// empty body, a 428 — leaves the session alone.
  bool get sessionIsDead =>
      code == "SESSION_INVALID" || action == "bootstrap_session";

  String describe() {
    if (code.isEmpty && action.isEmpty) return "(no error body)";
    return "code=${code.isEmpty ? "-" : code} "
        "action=${action.isEmpty ? "-" : action}";
  }
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
/// port of SpotiFLAC-Mobile's `signedSession` runtime (first ported from 4.7;
/// re-diffed line by line against 4.9.5's `signedSession@3` —
/// `go_backend/extension_signed_session.go` in `zarzet/SpotiFLAC-Mobile` —
/// on 2026-09-02: bootstrap query, exchange body, signing input, every
/// header and the ticket body are identical).
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
  /// keeps that burst from tripping the gateway's rate limiter, which — now that
  /// there is no lossy fallback — would leave those tracks with no source at all.
  static const _maxConcurrent = 4;

  /// One quick 429 retry so a momentary rate-limit is absorbed instead of
  /// instantly abandoning lossless, without stalling on a long backoff.
  static const _maxAttempts = 2;
  static const _maxRetryBackoff = Duration(seconds: 2);

  /// Hard ceiling on trips round the [signedPostJson] loop. Each recovery step
  /// is already one-shot, but a bounded loop means no combination of 429s and
  /// mid-flight session rotations can spin forever.
  static const _maxTotalAttempts = 6;

  /// How many times a request will re-sign because the session rotated under
  /// it. One is the real case (a concurrent refresh landed); two is slack.
  static const _maxRotationRetries = 2;

  /// Per-provider gateway app version (e.g. `qobuz-web@1.1.0`). Sessions are
  /// scoped by it, so each provider verifies independently.
  final String _appVersion;

  /// A stable id used as both the persistence key and the challenge `state`.
  final String _stateId;

  /// The provider tag used in `[zarz:<id>]` diagnostics. Exposed so callers
  /// outside this file log against the same key you would grep for.
  String get stateId => _stateId;

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

  /// When this process last refreshed the session, for the keep-alive
  /// cadence. The gateway issues **ten-hour** sessions (observed on the
  /// emulator: verified 12:27, `expires_at` 22:27), so a session refreshed
  /// only when something happened to resolve a track died overnight. Launch,
  /// resume, a two-hour timer and each resolve now all *check* (rate-limited
  /// by [_keepAliveInterval]) — but a refresh still only goes out inside
  /// [_refreshSkew], as upstream does. See [keepAlive] for why that restraint
  /// matters.
  DateTime? _lastKeepAlive;

  /// Called (fire and forget) whenever a stored session is thrown away.
  ///
  /// Losing a session is the one event that costs the user a Turnstile, and
  /// the gateway revokes them on its own schedule: a session verified by
  /// hand at 12:27 answered `428 VERIFY_REQUIRED` and then
  /// `401 SESSION_INVALID` an hour later, with the app doing nothing but
  /// playing music. Nothing then tried to recover until the next launch,
  /// so playback simply stayed dead. The app layer hangs a headless
  /// re-verify off this (see `use_zarz_keep_alive.dart`) — a callback
  /// rather than a direct call because the headless solver imports this
  /// file, not the other way round.
  static void Function(ZarzSession session)? onCleared;

  /// When the gateway last told us this session needs verifying.
  ///
  /// Every signed call runs a ladder — refresh, retry, silent bootstrap —
  /// before it gives up, which is right for a one-off failure and wrong
  /// once for every track in a queue: a burst of blocked resolves each paid
  /// several gateway round trips, and the app looked hung rather than
  /// blocked. Inside this window the answer is already known, so give it
  /// immediately and let the UI ask for a verify.
  DateTime? _verificationRequiredAt;
  static const _verificationCooldown = Duration(seconds: 90);
  bool get _verificationKnownRequired {
    final at = _verificationRequiredAt;
    return at != null && _now().difference(at) < _verificationCooldown;
  }
  static const _keepAliveInterval = Duration(minutes: 30);
  bool get _keepAliveDue {
    final last = _lastKeepAlive;
    return last == null || _now().difference(last) >= _keepAliveInterval;
  }

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

  // The `app_version` strings below track the current versions in the
  // official extension registry
  // (`raw.githubusercontent.com/spotiflacapp/SpotiFLAC-Extension/main/registry.json`,
  // `qobuz-web` / `tidal-web` → `"<id>@<version>"`). The gateway scopes
  // sessions by this value, and the official app re-keys (and re-verifies)
  // its session whenever an extension updates, so keeping in step is plain
  // hygiene. It is NOT a proven fix for anything: on 2026-09-02 a session
  // minted under the stale `@1.1.0` answered `428 VERIFY_REQUIRED` for ~45
  // minutes and then minted tickets again unchanged (CONTEXT §23). Changing
  // the value changes [_prefsKey], which orphans the stored session — one
  // re-verify, and a fresh install id.

  /// Qobuz provider session (gateway app version `qobuz-web@1.2.10`,
  /// registry 2026-09-02).
  static final ZarzSession qobuz = ZarzSession(
    appVersion: "qobuz-web@1.2.10",
    stateId: "qobuz-web",
  );

  /// Tidal provider session (gateway app version `tidal-web@1.2.2`,
  /// registry 2026-08-29).
  static final ZarzSession tidal = ZarzSession(
    appVersion: "tidal-web@1.2.2",
    stateId: "tidal-web",
  );

  String get _prefsKey => "zarz_session_$_appVersion";

  Uri _url(String endpoint) => Uri.parse("$_baseUrl$endpoint");

  // ---- Persistence -------------------------------------------------------

  /// Single-flight guard for [_load]. Without it two concurrent first loads
  /// (e.g. `isAuthenticated()` racing the first track resolve at launch) each
  /// saw `_record == null`, each minted a DIFFERENT random install id, and both
  /// saved — so the session granted for one install id was later refreshed
  /// under another, the gateway rejected it, the session was cleared, and the
  /// user faced a fresh Turnstile on the next launch. Loading exactly once
  /// removes that whole failure mode.
  Future<_SessionRecord>? _loadInFlight;

  Future<_SessionRecord> _load() {
    final cached = _record;
    if (cached != null) return Future.value(cached);
    return _loadInFlight ??= _loadOnce().whenComplete(() {
      _loadInFlight = null;
    });
  }

  Future<_SessionRecord> _loadOnce() async {
    final cached = _record;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _SessionRecord record;
    var minted = false;
    if (raw != null && raw.isNotEmpty) {
      try {
        record = _SessionRecord.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        AppLogger.diag("[zarz:$_stateId] stored session unreadable ($e)");
        record = _SessionRecord(installId: _randomHex(16));
        minted = true;
      }
    } else {
      record = _SessionRecord(installId: _randomHex(16));
      minted = true;
    }
    if (record.installId.isEmpty) {
      record.installId = _randomHex(16);
      minted = true;
    }
    _record = record;
    // Only write when something actually changed — re-saving a healthy record
    // on every load is pure risk (a partial write loses the session).
    if (minted) {
      await _save(record);
    }
    AppLogger.diag(
      "[zarz:$_stateId] loaded install=${record.installId.substring(0, 6)}… "
      "session=${record.hasSession ? "yes" : "no"} "
      "expires=${record.expiresAt.isEmpty ? "-" : record.expiresAt}",
    );
    return record;
  }

  Future<void> _save(_SessionRecord record) async {
    _record = record;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(record.toJson()));
  }

  /// Whether **any** lossless source could serve a stream right now.
  ///
  /// A stored session that the gateway is answering `428` for is not usable —
  /// [isFlaggedDespiteSession] is what separates the two, and forgetting it is
  /// the loop §23 spent a session in. Both facts are local (shared preferences
  /// and an in-memory timestamp), so this is cheap enough to ask on the path
  /// that starts playback; it must stay that way, because the alternative is a
  /// gateway round trip in front of every play (the `playback-no-delays`
  /// requirement).
  ///
  /// Two callers, and they have to agree: the stream route holds a blocked
  /// request open until this turns true (§42), and `load()` refuses to hand
  /// mpv a queue while it is false (§43).
  static Future<bool> anyLosslessUsable() async {
    for (final session in [qobuz, tidal]) {
      if (await session.isAuthenticated() && !session.isFlaggedDespiteSession) {
        return true;
      }
    }
    return false;
  }

  /// Whether a non-expired session is stored.
  Future<bool> isAuthenticated() async {
    final record = await _load();
    if (!record.hasSession) {
      AppLogger.diag("[zarz:$_stateId] not authenticated: no stored session");
      return false;
    }
    final expiry = record.expiry;
    if (expiry != null && _now().isAfter(expiry)) {
      AppLogger.diag(
        "[zarz:$_stateId] not authenticated: expired at $expiry "
        "(now ${_now()})",
      );
      return false;
    }
    return true;
  }

  /// Forgets the stored session (keeps the install id). [reason] is logged —
  /// a cleared session is exactly what costs the user a fresh Turnstile, so
  /// every clear must be attributable in the device log.
  Future<void> clear([String reason = "explicit"]) async {
    final record = await _load();
    AppLogger.diag("[zarz:$_stateId] CLEARING session — $reason");
    record
      ..sessionId = ""
      ..sessionSecret = ""
      ..expiresAt = "";
    // Whatever else is in flight is about to fail the same way. Saying so
    // here stops each of them running its own refresh + silent-bootstrap
    // ladder: one revocation used to produce a burst of ten gateway calls
    // and four more CLEARING lines, which is precisely the churn §23 blamed
    // for the install being flagged in the first place.
    _verificationRequiredAt = _now();
    await _save(record);
    onCleared?.call(this);
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

  /// Last-ditch silent recovery: ask `/bootstrap` for a session without any
  /// UI. The gateway sometimes issues one straight away (no human check), in
  /// which case a rejected session costs the user nothing. Returns true when a
  /// usable session was established.
  Future<bool> _trySilentBootstrap() {
    // Coalesced like [_maybeRefresh]. Prefetch fans several resolves out at
    // once; without this each rejected request mints its own challenge, and
    // the loser of the race would then clear the session the winner had just
    // established.
    return _silentBootstrapInFlight ??=
        _trySilentBootstrapOnce().whenComplete(() {
      _silentBootstrapInFlight = null;
    });
  }

  Future<bool>? _silentBootstrapInFlight;

  /// Silent bootstraps are rationed to one per [_silentBootstrapBackoff] per
  /// provider. Every `GET /bootstrap` mints a challenge server-side, and a
  /// challenge nobody opens is simply abandoned. §17a established that the
  /// gateway has never once answered a silent bootstrap with a session, so
  /// every launch, every Settings visit and every failure ladder was minting
  /// a challenge for nothing: one install abandoned 42 of them between
  /// 2026-08-30 and 09-02 and then found every signed call answered
  /// `428 VERIFY_REQUIRED action=verify` for ~45 minutes — including calls
  /// signed with a session it had just Turnstile-verified (§23). The official
  /// host only bootstraps when it is about to show the challenge, and reuses
  /// the pending one. User-initiated verification calls [bootstrap] directly
  /// and is never rationed. Plain wall-clock, like the headless backoff — this
  /// is local bookkeeping, not a signed timestamp.
  static const _silentBootstrapBackoff = Duration(hours: 6);
  String get _silentBootstrapKey => "zarzSilentBootstrapAttempt-$_stateId";

  Future<bool> _trySilentBootstrapOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(_silentBootstrapKey);
      // A negative gap means the clock moved backwards; treat it as elapsed
      // rather than locking recovery out until the clock catches up.
      if (last != null &&
          nowMs - last >= 0 &&
          nowMs - last < _silentBootstrapBackoff.inMilliseconds) {
        AppLogger.diag(
          "[zarz:$_stateId] silent re-bootstrap skipped (backing off)",
        );
        return false;
      }
      await prefs.setInt(_silentBootstrapKey, nowMs);
      final result = await bootstrap();
      if (result.authenticated) {
        AppLogger.diag("[zarz:$_stateId] silent re-bootstrap succeeded");
        return true;
      }
      AppLogger.diag(
        "[zarz:$_stateId] silent re-bootstrap needs Turnstile",
      );
    } catch (e) {
      AppLogger.diag("[zarz:$_stateId] silent re-bootstrap failed: $e");
    }
    return false;
  }

  // ---- Signed requests --------------------------------------------------

  /// Mints a single-use download ticket for [id] and returns its id, to be sent
  /// as `X-Zarz-Ticket` on the matching `/dl/*` call. [id] must be the exact
  /// value the gateway hashes at consume time (the track URL for Qobuz, the bare
  /// track id for Tidal).
  /// Whether the gateway is refusing a session it has already accepted.
  ///
  /// `428 VERIFY_REQUIRED` with a **live, freshly-granted** session is not
  /// about the session at all — it is the install being flagged (§23), and
  /// it is the state that makes "Verify" look broken: the tile says
  /// Verified, nothing plays, and tapping Verify finds a valid session and
  /// returns immediately. Callers use this to tell the two apart.
  /// Remembered far longer than the fast-fail window: that one is about not
  /// re-walking the ladder for a few seconds, this one is what the Settings
  /// tile and the Verify action read, and a tile that flipped back to
  /// "Verified" 90 seconds later would put the user straight back in the loop.
  static const _flaggedMemory = Duration(minutes: 10);
  bool get isFlaggedDespiteSession {
    final at = _verificationRequiredAt;
    if (at == null || _now().difference(at) >= _flaggedMemory) return false;
    final record = _record;
    return record != null && record.hasSession;
  }

  /// Starts over as a brand-new install: forgets the session **and the
  /// install id**.
  ///
  /// The gateway's verify flag lives on the install, not on the session —
  /// a fresh install has never been seen carrying one (§23b), and no
  /// number of new sessions clears it. So when the user asks to verify an
  /// install the gateway has flagged, re-keying is the only thing that can
  /// actually work. Deliberately **only** reachable from a user-initiated
  /// verify: doing it automatically would mint challenges in a loop, which
  /// is how installs get flagged in the first place.
  Future<void> resetInstall(String reason) async {
    final record = await _load();
    AppLogger.diag("[zarz:$_stateId] RESETTING install — $reason");
    record
      ..sessionId = ""
      ..sessionSecret = ""
      ..expiresAt = ""
      ..installId = _randomHex(16);
    _verificationRequiredAt = null;
    _lastKeepAlive = null;
    await _save(record);
  }

  /// Forgets a "needs verifying" verdict — the session is good again.
  void _clearVerificationFlag() => _verificationRequiredAt = null;

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
    // The gateway said "verify" moments ago; it will say it again. Answer
    // from here instead of walking the whole ladder once per track — a
    // queue of blocked tracks used to spend several round trips each and
    // the app just looked hung. See [_verificationRequiredAt].
    if (_verificationKnownRequired) {
      throw const ZarzVerificationRequiredException();
    }
    final record = await _ensureSession();
    final bodyText = jsonEncode(body);

    await _acquire();
    try {
      var authRetried = false;
      var bootstrapRetried = false;
      var rotations = 0;
      for (var attempt = 0; attempt < _maxTotalAttempts; attempt++) {
        // The session this attempt is signed with. `record` is the single
        // shared mutable `_record`, so a refresh/bootstrap/grant on ANOTHER
        // in-flight request rotates it in place — comparing against this
        // afterwards is how we tell "my credentials went stale mid-flight"
        // apart from "the gateway rejects this session".
        final signedWith = record.sessionId;

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
          final err = _GatewayError.from(res);
          AppLogger.diag(
            "[zarz:$_stateId] $path HTTP $status ${err.describe()}",
          );
          if (status == 428) {
            // `code=VERIFY_REQUIRED action=verify` straight after a *passed*
            // Turnstile (§22) is not explained by the code/action pair alone;
            // the whole body and the headers are the only place the gateway
            // can say what "verify" actually wants. Debug-only, like every
            // other `diag`.
            final raw = res.data;
            final body = raw is String ? raw : jsonEncode(raw);
            AppLogger.diag(
              "[zarz:$_stateId] $path 428 body: "
              "${body.length > 600 ? body.substring(0, 600) : body} "
              "headers: ${res.headers.map}",
            );
          }

          // (1) Somebody else already rotated the session while this request
          // was on the wire, so this rejection says nothing about the NEW
          // session — it was signed with the old one. Retry, don't diagnose.
          // Two concurrent /tickets calls each running the full ladder is
          // exactly how a healthy session got cleared twice, 16ms apart.
          if (record.hasSession &&
              record.sessionId != signedWith &&
              rotations < _maxRotationRetries) {
            rotations++;
            AppLogger.diag(
              "[zarz:$_stateId] $path signed with a session that has since "
              "rotated — retrying ($rotations/$_maxRotationRetries)",
            );
            continue;
          }

          // (2) Don't nuke the session on the first rejection — that's what
          // made every transient failure (clock skew before the offset was
          // learned, a gateway blip, a refresh racing an in-flight request)
          // cost the user a full Turnstile. Re-sync the clock (done above via
          // the response's Date header), try one refresh, and retry once.
          if (!authRetried) {
            authRetried = true;
            AppLogger.diag(
              "[zarz:$_stateId] $path HTTP $status — refreshing + retrying",
            );
            await _maybeRefresh(record);
            continue;
          }

          // (3) The gateway did NOT say the session is finished. A 428 is
          // `Precondition Required` — a fact about this request, not a verdict
          // on the credentials (see [_GatewayError]). Surface it so the user
          // still gets a manual "verify" affordance, but leave a session that
          // may be perfectly good exactly where it is.
          if (!err.sessionIsDead) {
            AppLogger.diag(
              "[zarz:$_stateId] $path still HTTP $status — KEEPING session "
              "(gateway did not ask for a re-bootstrap)",
            );
            _verificationRequiredAt = _now();
            throw const ZarzVerificationRequiredException();
          }

          // (4) The gateway says bootstrap. Before costing the user a
          // Turnstile, try a silent bootstrap: it sometimes issues a fresh
          // session with no human check at all.
          if (!bootstrapRetried) {
            bootstrapRetried = true;
            if (await _trySilentBootstrap()) continue;
          }

          // (5) Last gate before the expensive thing. If the record no longer
          // holds the session that was rejected, some other path has already
          // replaced it and clearing would throw away a live one.
          if (record.sessionId != signedWith && record.hasSession) {
            AppLogger.diag(
              "[zarz:$_stateId] $path rejected, but the session was replaced "
              "meanwhile — NOT clearing",
            );
          } else {
            await clear("signed $path rejected with HTTP $status "
                "(${err.describe()}) after refresh + silent bootstrap");
          }
          _verificationRequiredAt = _now();
          throw const ZarzVerificationRequiredException();
        }
        if (status < 200 || status >= 300) {
          throw StateError("Zarz v2 $path failed: HTTP $status");
        }
        _clearVerificationFlag();
        if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
        if (res.data is String && (res.data as String).isNotEmpty) {
          return Map<String, dynamic>.from(
              jsonDecode(res.data as String) as Map);
        }
        return {};
      }
      // The bounded loop ran out of attempts without a verdict.
      throw StateError("Zarz v2 $path gave up after $_maxTotalAttempts attempts");
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

  /// Zone marker set by [runInteractive]: signed requests made while
  /// resolving the track the player is asking for RIGHT NOW jump ahead of
  /// queued prefetch traffic instead of waiting behind an 8-track warm
  /// fan-out for one of the [_maxConcurrent] slots.
  static const _interactiveZoneKey = #zarzInteractive;

  /// Runs [body] in a zone whose signed zarz requests get queue priority.
  /// Wrap the resolve that mpv/the user is actively blocked on.
  static T runInteractive<T>(T Function() body) =>
      runZoned(body, zoneValues: const {_interactiveZoneKey: true});

  Future<void> _acquire() async {
    if (_inFlight < _maxConcurrent) {
      _inFlight++;
      return;
    }
    final completer = Completer<void>();
    if (Zone.current[_interactiveZoneKey] == true) {
      _waiters.insert(0, completer);
    } else {
      _waiters.add(completer);
    }
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
          // A refresh couldn't revive it — try a silent bootstrap before
          // falling back to the (user-visible) Turnstile.
          if (!await _trySilentBootstrap()) {
            await clear("expired at $expiry and neither refresh nor silent "
                "bootstrap recovered it");
            _verificationRequiredAt = _now();
            throw const ZarzVerificationRequiredException();
          }
        }
      } else if (expiry.difference(_now()) <= _refreshSkew) {
        // Refresh near expiry — the session is about to lapse, so this one
        // has to block.
        await _maybeRefresh(record);
      } else if (_keepAliveDue) {
        // Opportunistic refresh on the keep-alive cadence — every resolve
        // during a listening session pushes the expiry out. The session is
        // comfortably valid here, so run it in the background instead of
        // making a cold resolve pay the extra gateway round trip.
        unawaited(keepAlive(reason: "resolve").catchError((Object e) {
          AppLogger.reportError(e, StackTrace.current);
        }));
      }
    }
    return record;
  }

  /// Background keep-alive: refreshes a stored session that is about to
  /// lapse. Called on launch, on resume, from a two-hour timer and on each
  /// resolve, so a session in its last hour is renewed whenever the app is
  /// open at all rather than only when something happens to resolve.
  ///
  /// **It only refreshes inside [_refreshSkew], and that restraint is the
  /// point.** The first version refreshed on every launch and every 30
  /// minutes, which pushed the ten-hour expiry forward far more often than
  /// the official host does (`signedSessionRefreshDue` there is exactly
  /// "within one hour of expiry"). On 2026-09-03 every single revocation —
  /// three of them — landed **0.6 to 2 seconds after a successful refresh**:
  /// `/tickets` answered `428 VERIFY_REQUIRED`, the next refresh answered
  /// `401 SESSION_INVALID`, and the session was gone. Correlation, not proof
  /// (tickets and keep-alives both cluster around a resolve), but the
  /// gateway is demonstrably stateful about verification and §23a's lesson
  /// was that our port should not deviate from upstream. So: same trigger
  /// as upstream, just checked more often.
  ///
  /// Never throws and never clears anything by itself — the gateway's
  /// verdict on the signed refresh decides. Does nothing without a stored
  /// session: minting a challenge from here would be the §23 churn again.
  Future<void> keepAlive({String reason = "launch"}) async {
    final record = await _load();
    if (!record.hasSession) return;
    if (!_keepAliveDue) return;
    final expiry = record.expiry;
    if (expiry != null && expiry.difference(_now()) > _refreshSkew) {
      // Comfortably alive. Leave it completely alone.
      return;
    }
    _lastKeepAlive = _now();
    final before = record.expiresAt;
    try {
      await _maybeRefresh(record);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
    AppLogger.diag(
      "[zarz:$_stateId] keep-alive ($reason): expires "
      "${before.isEmpty ? "-" : before} -> "
      "${record.expiresAt.isEmpty ? "-" : record.expiresAt}",
    );
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
      // The gateway answered (whatever the verdict) — that is one
      // keep-alive round trip spent for the cadence.
      _lastKeepAlive = _now();
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        // A silent `return` here is how a failing refresh stayed invisible in
        // the device log while the caller went on to clear the session.
        AppLogger.diag(
          "[zarz:$_stateId] refresh HTTP $status "
          "${_GatewayError.from(res).describe()}",
        );
        return;
      }
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
