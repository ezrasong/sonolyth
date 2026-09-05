import 'package:shadcn_flutter/shadcn_flutter.dart';

/// **Proxima Zenith motion.**
///
/// Ported from the skin's `res/anim/*.xml` and its `*_anim_*` styles, so the
/// app moves the way Proxima does rather than on Flutter's defaults. The whole
/// vocabulary is four values:
///
/// | Proxima source                    | value                         |
/// | --------------------------------- | ----------------------------- |
/// | `in_animation` / `out_animation`  | 175ms **linear** alpha fade   |
/// | ...its alpha range                | `0.1 <-> 1.0`, never to zero  |
/// | `slide_in_*` / `slide_out_*`      | 550ms full-extent translate   |
/// | scene change (`android:duration`) | 300ms                         |
/// | `*_anim_seeking`, rating pressed  | scale + alpha **0.95**        |
///
/// Two details are what make it read as Proxima rather than as generic
/// Material, and both are easy to lose:
///
/// 1. **Fades are linear, not eased.** Proxima explicitly sets
///    `@android:anim/linear_interpolator` on the alpha sets.
/// 2. **Content fades to 0.1, not to 0.** Elements dim rather than vanish, so
///    a cross-fade never leaves an empty frame.
abstract final class ZenithMotion {
  // ---- Durations --------------------------------------------------------

  /// `in_animation.xml` / `out_animation.xml` — cross-fades, state swaps,
  /// anything that changes in place.
  static const fade = Duration(milliseconds: 175);

  /// The skin's scene-change duration — expand/collapse, list reflow.
  static const scene = Duration(milliseconds: 300);

  /// `slide_in_*.xml` / `slide_out_*.xml` — panels and pages entering or
  /// leaving across the full extent of their axis.
  static const slide = Duration(milliseconds: 550);

  /// Press feedback. Not in the skin as a duration (it's a state, not an
  /// animation) — kept short so the 0.95 scale reads as a response, not a
  /// transition.
  static const press = Duration(milliseconds: 90);

  // ---- Curves -----------------------------------------------------------

  /// Alpha transitions are LINEAR in Proxima. Easing a fade is the single
  /// most common way to make this theme feel like stock Material instead.
  static const fadeCurve = Curves.linear;

  /// The slide/scene sets declare no interpolator, so they take Android's
  /// default — accelerate-decelerate.
  static const slideCurve = Curves.easeInOut;

  // ---- Magnitudes -------------------------------------------------------

  /// Alpha floor for a cross-fade. Proxima fades to 0.1, never to 0.
  static const fadeFloor = 0.1;

  /// The one scale value the skin uses, for both seek state and press
  /// feedback (`*_anim_seeking`, `ItemRatingBar_anim_ratingbar_pressed`).
  static const pressScale = 0.95;

  /// Alpha applied alongside [pressScale] while seeking.
  static const seekingAlpha = 0.95;

  /// `PlainSeekbar_anim_seeking` — the bar itself *thickens* while it is being
  /// dragged. Proxima does not override this one, so the Poweramp base value
  /// stands. It is the counterweight to [seekingAlpha]: everything around the
  /// bar recedes, the thing under your thumb grows.
  static const seekbarScaleY = 1.25;

  // ---- Poweramp's engine animations ----------------------------------------
  // These are not the skin's (a skin cannot change them) but they are what
  // every Poweramp user sees under Proxima, so a replica has them.

  /// `res/anim/aa_fade_in.xml` — album art arriving: alpha 0→1 over 600ms and
  /// scale 0.96→1 over 450ms, both on `decelerate_interpolator`.
  static const artFadeIn = Duration(milliseconds: 600);
  static const artScaleIn = Duration(milliseconds: 450);
  static const artScaleFrom = 0.96;
  static const artCurve = Curves.decelerate;

  /// `res/anim/anim_fade_in_move_up.xml` — a list item arriving: alpha 0→1 and
  /// a rise from 3% of its own height, over `translate_anim_duration_ms` 300.
  static const listEnter = Duration(milliseconds: 300);
  static const listRise = 0.03;
}

/// Wraps [child] in Proxima's press response: a 0.95 scale-down over
/// [ZenithMotion.press]. Zenith has no ripple splash — its ripple colour is
/// 3% white — so pressure is shown by the control shrinking, not by a wash.
class ZenithPressable extends StatefulWidget {
  const ZenithPressable({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// The item's context menu, on the gesture `TrackTile` already uses for its
  /// own. Proxima puts nothing on an item but the item — no overlay buttons —
  /// so secondary actions live here rather than on a badge over the artwork.
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  State<ZenithPressable> createState() => _ZenithPressableState();
}

class _ZenithPressableState extends State<ZenithPressable> {
  bool _down = false;

  void _set(bool value) {
    if (!widget.enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.enabled ? widget.onPressed : null,
      // Only wired when a handler exists, so items without a menu do not pay
      // for a long-press arena on every tap.
      onLongPress: widget.enabled && widget.onLongPress != null
          ? widget.onLongPress
          : null,
      child: AnimatedScale(
        scale: _down ? ZenithMotion.pressScale : 1.0,
        duration: ZenithMotion.press,
        curve: ZenithMotion.slideCurve,
        child: widget.child,
      ),
    );
  }
}

/// Proxima's **seeking** state, from `TopMetaInfoLayout_anim_seeking`: while
/// the seek bar is dragged, everything *around* the bar dims to
/// [ZenithMotion.seekingAlpha] and shrinks to [ZenithMotion.pressScale].
///
/// Note the base Poweramp values are alpha 0.45 / scale 0.85 — a much heavier
/// recession. Proxima deliberately softens both to 0.95, so read the skin's
/// override, not the app's default. (It also sets `TopCounterLayout` to
/// `gone` outright; the counter is kept here because Sonolyth's player has no
/// other position readout.)
class ZenithSeeking extends StatelessWidget {
  const ZenithSeeking({super.key, required this.seeking, required this.child});

  final bool seeking;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: seeking ? ZenithMotion.pressScale : 1.0,
      duration: ZenithMotion.fade,
      curve: ZenithMotion.fadeCurve,
      child: AnimatedOpacity(
        opacity: seeking ? ZenithMotion.seekingAlpha : 1.0,
        duration: ZenithMotion.fade,
        curve: ZenithMotion.fadeCurve,
        child: child,
      ),
    );
  }
}

/// The other half of the seeking state — `PlainSeekbar_anim_seeking` stretches
/// the bar vertically to [ZenithMotion.seekbarScaleY] while it is dragged.
/// `AnimatedScale` is uniform, so this drives the Y axis directly.
class ZenithSeekbarSwell extends StatelessWidget {
  const ZenithSeekbarSwell({
    super.key,
    required this.seeking,
    required this.child,
  });

  final bool seeking;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: seeking ? ZenithMotion.seekbarScaleY : 1.0),
      duration: ZenithMotion.fade,
      curve: ZenithMotion.fadeCurve,
      child: child,
      builder: (context, scaleY, child) => Transform(
        transform: Matrix4.diagonal3Values(1, scaleY, 1),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Proxima's cross-fade: linear, 175ms, and dimming to
/// [ZenithMotion.fadeFloor] rather than to nothing.
class ZenithFade extends StatelessWidget {
  const ZenithFade({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : ZenithMotion.fadeFloor,
      duration: ZenithMotion.fade,
      curve: ZenithMotion.fadeCurve,
      child: child,
    );
  }
}

/// A reveal on Proxima's terms: a 175ms **linear** fade with no scale bounce,
/// and no hit-testing while hidden — a hidden control must not swallow the tap
/// meant for the row or card beneath it.
///
/// Reveals go to 0 rather than to [ZenithMotion.fadeFloor], which is for
/// cross-fades: a button held at 10% over artwork still reads as a button and
/// is still hit-testable.
class ZenithReveal extends StatelessWidget {
  const ZenithReveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: ZenithMotion.fade,
        curve: ZenithMotion.fadeCurve,
        child: child,
      ),
    );
  }
}

/// `aa_fade_in` as an [AnimatedSwitcher.transitionBuilder]: the art fades in
/// over the whole [ZenithMotion.artFadeIn] and finishes its 0.96→1 scale at
/// 450/600 of it, both decelerating, as Poweramp's set does.
Widget zenithArtTransition(Widget child, Animation<double> animation) {
  final scaleEnd = ZenithMotion.artScaleIn.inMilliseconds /
      ZenithMotion.artFadeIn.inMilliseconds;
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: ZenithMotion.artCurve),
    child: ScaleTransition(
      scale: Tween<double>(begin: ZenithMotion.artScaleFrom, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Interval(0, scaleEnd, curve: ZenithMotion.artCurve),
        ),
      ),
      child: child,
    ),
  );
}

/// `anim_fade_in_move_up` — the item plays it once, when it first appears:
/// fades in and rises [ZenithMotion.listRise] of its own height over
/// [ZenithMotion.listEnter]. Poweramp runs it as the list's layout animation,
/// so rows arriving on screen for the first time settle into place rather than
/// popping. Items already on screen are untouched: the animation lives in the
/// item's own state.
class ZenithListEnter extends StatefulWidget {
  const ZenithListEnter({super.key, required this.child});

  final Widget child;

  @override
  State<ZenithListEnter> createState() => _ZenithListEnterState();
}

class _ZenithListEnterState extends State<ZenithListEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ZenithMotion.listEnter,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, ZenithMotion.listRise),
          end: Offset.zero,
        ).animate(_controller),
        child: widget.child,
      ),
    );
  }
}
