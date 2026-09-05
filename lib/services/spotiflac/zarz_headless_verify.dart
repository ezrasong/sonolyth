import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

/// **Solving the zarz Turnstile without showing anybody a Turnstile.**
///
/// Cloudflare Turnstile in *managed* mode decides interactively-or-not from
/// browser signals, and for a real WebView on a real device it usually passes
/// with no click at all. The visible dialog
/// (`modules/settings/playback/zarz_verify_dialog.dart`) therefore spends most
/// of its life showing a spinner and then a checkbox that ticks itself.
///
/// So run exactly the same page in a [HeadlessInAppWebView] first and capture
/// exactly the same `spotiflac://session-grant?grant=…` redirect. The visible
/// dialog stays as the fallback for the case where Turnstile genuinely wants a
/// human — which is the only case it was ever needed for.
///
/// Nothing here is a bypass: it is the same challenge, solved by the same
/// Cloudflare widget, in the same app. The only thing removed is the window.

/// How long to let the challenge page run before giving up and asking a human.
/// Generous, because this happens once per install in the background and the
/// user is not waiting on it; a Turnstile that needs interaction will simply
/// sit there until this fires.
const _kHeadlessTimeout = Duration(seconds: 25);

/// Turnstile inspects the UA and rejects an obvious WebView string. Same value
/// the visible dialog uses — keep them identical.
const _kChallengeUserAgent =
    "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36";

/// `HeadlessInAppWebView` is implemented on Android, which since §40 is the
/// only platform this app builds for. Kept as a named predicate because the
/// callers read better for it and a future platform may not have one.
bool get _headlessSupported => true;

/// Extracts the grant out of the challenge page's callback redirect, or null
/// when [uri] is not that redirect.
String? _grantFrom(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != "spotiflac") return null;
  if (uri.host.toLowerCase() != "session-grant") return null;
  final grant =
      (uri.queryParameters["grant"] ?? uri.queryParameters["code"] ?? "").trim();
  return grant.isEmpty ? null : grant;
}

/// Runs [challengeUrl] in a headless WebView and returns the captured grant,
/// or null if the page never redirected within [timeout] (i.e. Turnstile is
/// waiting for a human, or the page failed).
///
/// Always disposes the WebView, including on the timeout path — a leaked
/// headless WebView keeps a live renderer process around for the life of the
/// app.
Future<String?> solveZarzChallengeHeadless(
  String challengeUrl, {
  Duration timeout = _kHeadlessTimeout,
  String stateId = "zarz",
}) async {
  if (!_headlessSupported) return null;

  final completer = Completer<String?>();
  void finish(String? grant) {
    if (!completer.isCompleted) completer.complete(grant);
  }

  final headless = HeadlessInAppWebView(
    initialUrlRequest: URLRequest(url: WebUri(challengeUrl)),
    // Turnstile lays its widget out in a real viewport and skips rendering in
    // a zero-sized one, which would leave the challenge permanently unsolved
    // and look exactly like a timeout. Give it a phone-shaped viewport.
    initialSize: const Size(412, 892),
    initialSettings: InAppWebViewSettings(
      useShouldOverrideUrlLoading: true,
      javaScriptEnabled: true,
      userAgent: _kChallengeUserAgent,
      transparentBackground: true,
    ),
    shouldOverrideUrlLoading: (controller, navigationAction) async {
      final grant = _grantFrom(navigationAction.request.url);
      if (grant != null) {
        finish(grant);
        return NavigationActionPolicy.CANCEL;
      }
      return NavigationActionPolicy.ALLOW;
    },
    // ONLY finish here when the URL *is* the callback. Completing
    // unconditionally on load-stop ends the attempt the moment the challenge
    // page itself finishes loading — i.e. before Turnstile has run at all —
    // and reports as an instant "timeout".
    onLoadStop: (controller, url) {
      final grant = _grantFrom(url);
      if (grant != null) finish(grant);
    },
    // A custom-scheme redirect fails to *load* but still carries the grant in
    // the URL that failed — the visible dialog relies on this too.
    onReceivedError: (controller, request, error) {
      final grant = _grantFrom(request.url);
      if (grant != null) finish(grant);
    },
    // Debug only: a challenge that never redirects is otherwise completely
    // opaque — you cannot see the page, so you cannot tell "Turnstile wants a
    // click" apart from "the page threw".
    onConsoleMessage: (controller, message) {
      if (kDebugMode) {
        AppLogger.diag("[zarz:$stateId] challenge console: ${message.message}");
      }
    },
  );

  try {
    await headless.run();
  } catch (e, stack) {
    AppLogger.reportError(e, stack);
    try {
      await headless.dispose();
    } catch (_) {}
    return null;
  }

  AppLogger.diag("[zarz:$stateId] headless challenge running");
  final started = DateTime.now();
  var timedOut = false;
  final deadline = Timer(timeout, () {
    timedOut = true;
    finish(null);
  });
  try {
    final grant = await completer.future;
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    AppLogger.diag(
      "[zarz:$stateId] headless challenge ${grant != null ? "captured a grant" : timedOut ? "timed out" : "gave up early"} after ${elapsed}ms",
    );
    if (grant == null && kDebugMode) await _dumpPage(headless, stateId);
    return grant;
  } finally {
    deadline.cancel();
    try {
      await headless.dispose();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
  }
}

/// Minimum gap between automatic headless attempts for one provider. Long
/// enough that a device needing a human check is not re-challenged all day,
/// short enough that a transient failure heals within a session or two.
const _kHeadlessBackoff = Duration(hours: 6);

String _attemptKey(String stateId) => "zarzHeadlessAttempt-$stateId";

bool _backoffElapsed(String stateId) {
  try {
    final last =
        KVStoreService.sharedPreferences.getInt(_attemptKey(stateId));
    if (last == null) return true;
    final since = DateTime.now().millisecondsSinceEpoch - last;
    // A negative gap means the clock moved backwards; treat it as elapsed
    // rather than locking the user out until the clock catches up.
    return since < 0 || since >= _kHeadlessBackoff.inMilliseconds;
  } catch (_) {
    // Preferences not initialized yet — never let bookkeeping block a verify.
    return true;
  }
}

void _markAttempt(String stateId) {
  try {
    KVStoreService.sharedPreferences.setInt(
      _attemptKey(stateId),
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (_) {}
}

/// Debug-only post-mortem for a challenge that never redirected. Without it
/// the failure is a black box: no window, no page, just a timeout.
Future<void> _dumpPage(HeadlessInAppWebView headless, String stateId) async {
  try {
    final controller = headless.webViewController;
    if (controller == null) return;
    final url = await controller.getUrl();
    final text = await controller.evaluateJavascript(
      source: "(document.body ? document.body.innerText : '')"
          ".replace(/\\s+/g, ' ').slice(0, 400)",
    );
    AppLogger.diag("[zarz:$stateId] challenge stalled at $url");
    AppLogger.diag("[zarz:$stateId] challenge text: $text");
  } catch (e) {
    AppLogger.diag("[zarz:$stateId] challenge dump failed: $e");
  }
}

/// Ensures [session] is verified, solving the Turnstile headlessly if one is
/// required. Returns true when lossless access is ready.
///
/// Callers that have UI should treat `false` as "now show the visible dialog".
/// Note the challenge minted here is **spent** on failure, so the dialog path
/// re-bootstraps rather than reusing this challenge's URL.
Future<bool> tryZarzHeadlessVerify(
  ZarzSession session, {
  Duration timeout = _kHeadlessTimeout,
  bool force = false,
}) async {
  if (await session.isAuthenticated()) return true;
  if (!_headlessSupported) return false;

  final tag = "[zarz:${session.stateId}]";

  // Back off. Every attempt mints a *fresh* challenge server-side, and this
  // runs at launch, so a device whose Turnstile genuinely wants a human would
  // otherwise ask the gateway for a new challenge every single time the app
  // opens — pointless load on a third-party service and a good way to look
  // like abuse. The user-initiated path passes `force: true`; only the
  // automatic launch warm-up backs off.
  if (!force && !_backoffElapsed(session.stateId)) {
    AppLogger.diag("$tag headless attempt skipped (backing off)");
    return false;
  }
  _markAttempt(session.stateId);

  ZarzBootstrapResult boot;
  try {
    boot = await session.bootstrap();
  } catch (e) {
    AppLogger.diag("$tag headless bootstrap failed: $e");
    return false;
  }
  if (boot.authenticated) return true;

  final challengeUrl = boot.challengeUrl;
  if (challengeUrl == null) return false;

  final grant = await solveZarzChallengeHeadless(
    challengeUrl,
    timeout: timeout,
    stateId: session.stateId,
  );
  if (grant == null) {
    AppLogger.diag("$tag headless Turnstile did not pass — needs a human");
    return false;
  }

  try {
    await session.completeGrant(grant);
  } catch (e) {
    AppLogger.diag("$tag headless grant exchange failed: $e");
    return false;
  }

  final ok = await session.isAuthenticated();
  AppLogger.diag(
    "$tag headless Turnstile ${ok ? "SUCCEEDED" : "produced no session"}",
  );
  return ok;
}
