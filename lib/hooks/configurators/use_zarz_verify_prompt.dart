import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/settings/playback/zarz_verify_dialog.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/sourced_track/sourced_track.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';
import 'package:sonolyth/utils/outside_build.dart';

/// Tells the user *why* nothing plays when lossless access is unverified, and
/// gives them the one button that fixes it.
///
/// Until now a blocked stream was invisible: the resolve threw
/// `ZarzVerificationRequiredException`, mpv never got a URL, and the player
/// simply sat at 00:00 with a spinner — "non-responsive" — while the only way
/// out was buried in Settings → Playback. This watches the active track's
/// resolution and, the moment it fails for that reason, shows a toast with a
/// **Verify** action that runs the same dialog and then re-opens the track.
/// One prompt at a time, and at most one every couple of minutes, so a skip
/// burst through blocked tracks does not stack banners.
void useZarzVerifyPrompt(WidgetRef ref) {
  final rootContext = useContext();
  final activeTrack =
      ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
  final toast = useRef<ToastOverlay?>(null);
  final lastShown = useRef<DateTime?>(null);

  useEffect(() {
    final track = activeTrack;
    if (track is! SonolythFullTrackObject) return null;

    void onResolution(
      AsyncValue<SourcedTrack>? previous,
      AsyncValue<SourcedTrack> next,
    ) {
      if (!next.hasError || next.error is! ZarzVerificationRequiredException) {
        return;
      }
      AppLogger.diag(
        "[verify-prompt] '${track.name}' blocked — offering a verify",
      );
      if (toast.value?.isShowing == true) return;
      final last = lastShown.value;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(minutes: 2)) {
        return;
      }
      if (!rootContext.mounted) return;
      // Claim the rate-limit window *before* deferring: two resolutions can
      // fail inside one frame and `toast.value` has not been assigned yet.
      lastShown.value = DateTime.now();
      // `fireImmediately` below runs this from `useEffect`, which flutter_hooks
      // executes inside the build phase — so a resolve that had *already*
      // failed raised the toast mid-build and Flutter logged the ToastLayer
      // "already in the process of building widgets" warning (§43g).
      runOutsideBuild(() {
        if (!rootContext.mounted) return;
        toast.value = showToast(
          context: rootContext,
          // Top, not bottom: the mini player and the nav bar float over the
          // bottom of every screen, and a banner tall enough to hold an action
          // button covered the whole nav row for as long as it was up.
          location: ToastLocation.topCenter,
          showDuration: const Duration(seconds: 12),
          builder: (context, overlay) => _VerifyPrompt(
            onVerify: () async {
              overlay.close();
              if (!rootContext.mounted) return;
              await verifyLosslessAccess(rootContext, ref);
            },
          ),
        );
      });
    }

    final subscription = ref.listenManual<AsyncValue<SourcedTrack>>(
      sourcedTrackProvider(track),
      onResolution,
      fireImmediately: true,
    );
    return subscription.close;
  }, [activeTrack?.id]);
}

class _VerifyPrompt extends StatelessWidget {
  const _VerifyPrompt({required this.onVerify});

  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // `DialogPositiveButtonStyle` — the theme's translucent positive.
    final verify = Button(
      style: zenithPositiveButton(scheme),
      onPressed: onVerify,
      child: const Text("Verify"),
    );
    // At a large system font size the button's natural width left the title
    // wrapping one word per line down a narrow column (§37); the toast is only
    // as wide as a phone. Past the threshold the button takes its own line.
    final stacked = zenithStacksRows(context);
    return SurfaceCard(
      child: Basic(
        leading: const Icon(SonolythIcons.audioQuality),
        title: const Text("Lossless access needs a check"),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Qobuz and Tidal streams stay blocked until it's done.",
            ),
            if (stacked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: verify,
              ),
          ],
        ),
        trailing: stacked ? null : verify,
      ),
    );
  }
}
