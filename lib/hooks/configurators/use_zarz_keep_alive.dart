import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/spotiflac/zarz_headless_verify.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

/// Keeps the lossless (zarz) sessions alive for as long as the app is used at
/// all, and puts them back on their own when the gateway takes one away.
///
/// Two separate problems, both of which ended with the user staring at a
/// Turnstile:
///
/// * **Sessions lapsed.** The gateway issues ten-hour sessions and only
///   refreshes one that asks. Asking only from inside a resolve meant a
///   session verified in the evening was dead by morning. Launch, resume and
///   a two-hour timer now check as well — but [ZarzSession.keepAlive] still
///   only sends a refresh when the session is inside its last hour, which is
///   exactly when the official host sends one. Refreshing more eagerly than
///   that preceded every revocation seen on 2026-09-03; see its doc comment.
/// * **Sessions were revoked.** One verified by hand at 12:27 answered
///   `428 VERIFY_REQUIRED` and then `401 SESSION_INVALID` an hour later, with
///   the app doing nothing but playing music. Nothing tried to recover until
///   the next launch, so playback silently stayed dead. Now a clear triggers
///   an immediate **headless** solve — the same Turnstile, no window — and
///   re-opens the current track if it succeeds. Only if that fails does
///   anybody get asked (`use_zarz_verify_prompt.dart`).
void useZarzSessionKeepAlive(WidgetRef ref) {
  useEffect(() {
    Future<void> refreshAll(String reason) async {
      for (final session in [ZarzSession.qobuz, ZarzSession.tidal]) {
        try {
          await session.keepAlive(reason: reason);
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }
    }

    // A revoked session is worth a headless attempt — but NOT one that
    // bypasses the solver's own 6-hour rationing.
    //
    // Every attempt mints a server-side challenge, and an install that keeps
    // minting challenges it never completes is exactly what §23 blamed for
    // being flagged. On a device where the headless solve cannot pass (the
    // emulator, §16e) a forced retry every 15 minutes is four abandoned
    // challenges an hour, for nothing. `tryZarzHeadlessVerify` without
    // `force` returns immediately unless its own backoff has elapsed, so a
    // clear costs at most one challenge per 6 hours per provider; when it
    // declines, the Verify banner is what the user gets.
    const healCooldown = Duration(minutes: 15);
    final lastHeal = <String, DateTime>{};
    var disposed = false;

    ZarzSession.onCleared = (session) {
      final last = lastHeal[session.stateId];
      if (last != null && DateTime.now().difference(last) < healCooldown) {
        AppLogger.diag(
          "[zarz:${session.stateId}] session cleared — self-heal backing off",
        );
        return;
      }
      lastHeal[session.stateId] = DateTime.now();
      unawaited(() async {
        AppLogger.diag(
          "[zarz:${session.stateId}] session cleared — headless re-verify",
        );
        try {
          final ok = await tryZarzHeadlessVerify(session);
          if (!ok || disposed) return;
          // The track that was playing failed to resolve while the session
          // was gone; without this the fix is inaudible until the next skip.
          await reloadPlaybackAfterVerification(ref);
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }());
    };

    final launch = Timer(const Duration(seconds: 2), () {
      refreshAll("launch");
    });
    final lifecycle = AppLifecycleListener(
      onResume: () => refreshAll("resume"),
    );
    final periodic = Timer.periodic(const Duration(hours: 2), (_) {
      refreshAll("timer");
    });
    return () {
      disposed = true;
      ZarzSession.onCleared = null;
      launch.cancel();
      lifecycle.dispose();
      periodic.cancel();
    };
  }, const []);
}
