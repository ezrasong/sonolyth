import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

/// Runs the zarz v2 "verify you're human" (Cloudflare Turnstile) flow for
/// [session] and returns true once a session is established.
///
/// If a valid session already exists it returns immediately. Otherwise it
/// bootstraps a challenge and opens it in an in-app WebView, capturing the
/// `spotiflac://session-grant?grant=…` redirect the challenge page performs on
/// success and exchanging that grant for a session. One-time per install (the
/// session persists and auto-refreshes), so playback then resolves silently.
Future<bool> showZarzVerifyDialog(
  BuildContext context,
  ZarzSession session, {
  required String sourceLabel,
}) async {
  if (await session.isAuthenticated()) return true;

  ZarzBootstrapResult boot;
  try {
    boot = await session.bootstrap();
  } catch (e, stack) {
    AppLogger.reportError(e, stack);
    if (context.mounted) {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Text("Couldn't reach the $sourceLabel verification service."),
        ),
      );
    }
    return false;
  }

  if (boot.authenticated) return true;
  final challengeUrl = boot.challengeUrl;
  if (challengeUrl == null || !context.mounted) return false;

  final grant = await showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (context) => _ZarzVerifyDialog(
      challengeUrl: challengeUrl,
      sourceLabel: sourceLabel,
    ),
  );

  if (grant == null || grant.isEmpty) return false;

  try {
    await session.completeGrant(grant);
    return await session.isAuthenticated();
  } catch (e, stack) {
    AppLogger.reportError(e, stack);
    return false;
  }
}

class _ZarzVerifyDialog extends StatefulWidget {
  final String challengeUrl;
  final String sourceLabel;

  const _ZarzVerifyDialog({
    required this.challengeUrl,
    required this.sourceLabel,
  });

  @override
  State<_ZarzVerifyDialog> createState() => _ZarzVerifyDialogState();
}

class _ZarzVerifyDialogState extends State<_ZarzVerifyDialog> {
  bool _loading = true;

  /// Intercepts the challenge page's redirect to the callback scheme and pops
  /// the captured grant. Returns true when it consumed [uri].
  bool _tryCaptureGrant(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != "spotiflac") return false;
    if (uri.host.toLowerCase() != "session-grant") return false;
    final grant = (uri.queryParameters["grant"] ??
            uri.queryParameters["code"] ??
            "")
        .trim();
    if (mounted) Navigator.of(context).pop(grant.isEmpty ? null : grant);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Alert(
        title: Text("Verify ${widget.sourceLabel} access").h4(),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(4),
            Text(
              "${widget.sourceLabel} now requires a one-time human check to "
              "stream lossless. Complete it below — it's remembered so you "
              "won't be asked every time.",
            ).small.muted,
            const Gap(12),
            SizedBox(
              height: 460,
              child: ClipRRect(
                borderRadius: theme.borderRadiusMd,
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest:
                          URLRequest(url: WebUri(widget.challengeUrl)),
                      initialSettings: InAppWebViewSettings(
                        useShouldOverrideUrlLoading: true,
                        javaScriptEnabled: true,
                        // Turnstile inspects the UA; a normal mobile browser UA
                        // avoids a "unsupported browser" rejection.
                        userAgent:
                            "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 "
                            "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36",
                        transparentBackground: true,
                      ),
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        final uri = navigationAction.request.url;
                        if (_tryCaptureGrant(uri)) {
                          return NavigationActionPolicy.CANCEL;
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                      onLoadStop: (controller, url) {
                        _tryCaptureGrant(url);
                        if (mounted) setState(() => _loading = false);
                      },
                      onReceivedError: (controller, request, error) {
                        // A failed load of the custom-scheme redirect still
                        // carries the grant in the URL — capture it.
                        _tryCaptureGrant(request.url);
                      },
                    ),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
            const Gap(16),
            Button.secondary(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }
}
