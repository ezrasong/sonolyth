import 'dart:ui' show lerpDouble;

import 'package:audio_service/audio_service.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/modules/player/player_overlay_collapsed.dart';

import 'package:sonolyth/modules/root/sonolyth_navigation_bar.dart';
import 'package:sonolyth/modules/player/player.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';

/// How far the player panel has travelled: **0 closed, 1 fully open**.
///
/// A [ValueNotifier] rather than provider state on purpose. The panel
/// reports its position on every frame of the slide, and pushing that
/// through Riverpod would rebuild every listening widget 60 times a
/// second; a notifier lets each leaf rebuild only what it animates and
/// keep its (expensive) child subtree intact.
final playerPanelProgressProvider = Provider<ValueNotifier<double>>((ref) {
  final progress = ValueNotifier<double>(0);
  ref.onDispose(progress.dispose);
  return progress;
});

final playerOverlayControllerProvider = StateProvider<PanelController>((ref) {
  return PanelController();
});

/// Opening and closing the player as a **scene change**, not as a fling.
///
/// `PanelController.open()`/`close()` fling a spring: measured on the
/// emulator at 30fps the panel went from barely moved to fully open across
/// **two frames**, so however the arrival is animated there is nothing to
/// see — the player simply appeared. Poweramp changes scenes on a timed
/// ~300ms decelerating curve (`material_motion_duration_long_1`, and
/// `aa_fade_in`'s interpolator), which is what these give it.
///
/// Only the tap paths are timed. A drag that is released still flings, so
/// the panel keeps following the momentum of the finger that threw it.
extension PlayerPanelMotion on PanelController {
  Future<void> openScene() {
    if (!isAttached) return Future.value();
    // Decelerate on the way up (Poweramp's `aa_fade_in` interpolator):
    // an ease-in-out spends most of a 300ms slide parked at the two ends
    // and crosses the middle in one frame, which put the whole fade back
    // into a single frame. Measured both ways on the emulator at 30fps.
    return animatePanelToPosition(
      1,
      duration: ZenithMotion.scene,
      curve: ZenithMotion.artCurve,
    );
  }

  Future<void> closeScene() {
    if (!isAttached) return Future.value();
    return animatePanelToPosition(
      0,
      duration: ZenithMotion.scene,
      curve: ZenithMotion.slideCurve,
    );
  }
}

class PlayerOverlay extends HookConsumerWidget {
  final String albumArt;

  const PlayerOverlay({
    required this.albumArt,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final activeTrack =
        ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
    final canShow = activeTrack != null;

    final screenSize = MediaQuery.sizeOf(context);
    final mediaQuery = MediaQuery.of(context);

    // The panel lives in the root Scaffold's `footers`, and that Scaffold sits
    // inside a `SafeArea(top: false)` — so the footer slot is the screen minus
    // the bottom system inset (24dp of gesture bar on a stock phone), not the
    // whole screen. Opening the panel to `screenSize.height` therefore made the
    // footer Column exactly that inset too tall: "BOTTOM OVERFLOWED BY 24
    // PIXELS", with the quality badge and part of the volume slider clipped.
    //
    // Measured against the raw view rather than against `padding`, because
    // `SafeArea` consumes an inset with `MediaQuery.removePadding`, which zeroes
    // `padding` *and* `viewPadding` — so from in here both are already 0 and the
    // 24 is invisible. The window's own viewPadding still reports it, and the
    // difference is exactly what ancestors took. If the SafeArea ever goes away
    // this reads 0 and the panel goes back to full height by itself.
    final consumedBottomInset =
        (MediaQueryData.fromView(View.of(context)).viewPadding.bottom -
                mediaQuery.viewPadding.bottom)
            .clamp(0.0, double.infinity);

    final panelController = ref.watch(playerOverlayControllerProvider);
    final panelProgress = ref.watch(playerPanelProgressProvider);

    // Tapping the media notification expands the full player. The stream is a
    // BehaviorSubject, so a cold start from the notification replays `true`
    // once this overlay mounts; the post-frame hop waits for the panel to be
    // attached before opening it.
    useEffect(() {
      final subscription = AudioService.notificationClicked.listen((clicked) {
        if (!clicked) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (panelController.isAttached && !panelController.isPanelOpen) {
            panelController.openScene();
          }
        });
      });
      return subscription.cancel;
    }, [panelController]);

    return SlidingUpPanel(
      // The navbar keeps its one-line scene under the open player (Poweramp
      // draws `scene_navbar_1line_sheet` there), so the panel stops above it.
      maxHeight: screenSize.height -
          consumedBottomInset -
          ZenithNavBarMetrics.playerSceneHeight,
      minHeight: canShow ? ZenithMiniPlayerMetrics.heightOf(context) : 0,
      onPanelSlide: (position) {
        final invertedPosition = 1 - position;
        ref.read(navigationPanelHeight.notifier).state = 50 * invertedPosition;
        panelProgress.value = position;
      },
      controller: panelController,
      color: Colors.transparent,
      parallaxEnabled: true,
      renderPanelSheet: false,
      // `collapsed`, not `header`: the package cross-fades the collapsed
      // slot out across the whole travel (and stops it taking taps once the
      // panel is open). As the header it was drawn at full opacity the whole
      // way and then vanished when the widget hid itself at a threshold —
      // the mini row popped out of existence mid-slide.
      collapsed: SizedBox(
        height: ZenithMiniPlayerMetrics.heightOf(context),
        width: screenSize.width,
        child: PlayerOverlayCollapsedSection(panelController: panelController),
      ),
      panelBuilder: (scrollController) => PlayerSceneEnter(
        progress: panelProgress,
        child: PlayerView(
          panelController: panelController,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// Brings the player in as a **scene**, not as a sheet.
///
/// The panel itself can only translate: at half travel you saw the top half
/// of a fully-drawn player floating over the list, which is what made the
/// transition read as "two screens moving". Poweramp changes scenes in
/// place — the album art arrives with `aa_fade_in` (alpha 0→1, scale
/// 0.96→1, decelerating) while the list goes. Riding that same fade and
/// scale on the panel's own position turns the translate into an arrival:
/// the player materialises over the second half of the slide instead of
/// being carried up whole.
///
/// Costs nothing at rest — at both ends of the travel the child is returned
/// untouched, so no `saveLayer` and no transform outside the transition.
class PlayerSceneEnter extends StatelessWidget {
  const PlayerSceneEnter({
    super.key,
    required this.progress,
    required this.child,
  });

  /// The panel's travel, 0 closed → 1 open.
  final ValueNotifier<double> progress;
  final Widget child;

  /// Where in the travel the scene starts to arrive, and where it is fully
  /// there. Late and quick: the mini row owns the first third (it is still
  /// fading out over it), and a player that is 40% visible at 40% travel
  /// just looks like a translucent sheet.
  static const _enterStart = 0.1;
  static const _enterEnd = 0.8;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      // Passed as `child` so the player subtree is built once and only the
      // opacity/scale wrapper rebuilds per frame.
      child: child,
      builder: (context, position, child) {
        // Linear, like every other fade in the skin (`in_animation` sets
        // `linear_interpolator` explicitly — §15). The easing belongs to the
        // panel's own curve; easing the alpha on top of it compressed the
        // whole fade into two frames in the middle of the travel.
        final eased = ((position - _enterStart) / (_enterEnd - _enterStart))
            .clamp(0.0, 1.0);
        // The SAME two wrappers on every frame, including both ends of the
        // travel. Returning the bare child at rest changes the player's
        // depth in the tree, and Flutter cannot reuse an element across a
        // depth change: the player was rebuilt from scratch the instant the
        // panel reached the top, its `shouldHide` hook reset to its `true`
        // default, and the open panel rendered an empty box over a dimmed
        // page. `Opacity` at 1.0 and an identity scale both short-circuit,
        // so this costs nothing at rest.
        return Opacity(
          opacity: eased,
          child: Transform.scale(
            scale: lerpDouble(ZenithMotion.artScaleFrom, 1.0, eased)!,
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }
}

/// Dims the page while the player panel rises.
///
/// Poweramp swaps the list for the album-art scene outright. A sheet
/// sliding over a fully lit list reads as two unrelated screens moving —
/// and the rows kept showing through the 35dp margins beside the panel all
/// the way up. This is the fade that replaces them.
///
/// It goes **behind the page**, not inside the panel:
/// `SlidingUpPanel.backdropEnabled` paints a `MediaQuery.size.height` box
/// inside the panel's own Stack, and the panel lives in the root
/// `Scaffold`'s footer slot — so the footer `Column` grew past the screen
/// ("BOTTOM OVERFLOWED BY 68 PIXELS", the navbar's whole height) and the
/// panel was squeezed out of it. Painting over the router's child instead
/// costs the layout nothing.
class PlayerPageScrim extends ConsumerWidget {
  const PlayerPageScrim({super.key, required this.child});

  final Widget child;

  /// Matches the dimming of Poweramp's list under the open player.
  static const _maxOpacity = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerPanelProgressProvider);
    return Stack(
      // `passthrough`, so the page is laid out under exactly the
      // constraints it had before this wrapper existed.
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, position, _) {
                if (position <= 0) return const SizedBox.shrink();
                return ColoredBox(
                  color: Colors.black.withValues(
                    alpha: _maxOpacity * position.clamp(0.0, 1.0),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
