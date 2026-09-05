import 'package:flutter/gestures.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Poweramp's `PlainSeekbar`, as Proxima draws it.
///
/// | source | value |
/// | --- | --- |
/// | `seekbar_background` | 7dp bar, radius 30, `colorKnobHole` (#11ffffff) |
/// | `seekbar` progress | same 7dp bar, `SeekbarStartColor..EndColor` = `colorIconPrimary` |
/// | `seekbar_thumb` | an 18×10 pill, `colorSeekbarThumb` at rest, `colorKnobPressed` (white) pressed |
/// | `PlainSeekbar` | 35dp tall hit area, 12dp padding |
///
/// The thumb is only drawn while the bar is being dragged: at rest the
/// screenshots show a bare progress line, and a 47% thumb on a 7dp bar reads as
/// a smudge rather than a handle. Pressed it is the skin's white pill.
class ZenithSeekbar extends StatefulWidget {
  const ZenithSeekbar({
    super.key,
    required this.value,
    this.buffer = 0,
    this.enabled = true,
    this.onChangeStart,
    this.onChanged,
    this.onChangeEnd,
    this.trackHeight = defaultTrackHeight,
    this.hitHeight = defaultHitHeight,
    required this.semanticLabel,
    this.semanticValueFor,
    this.semanticStep = defaultSemanticStep,
  });

  /// 0..1.
  final double value;

  /// 0..1, drawn as a faint second fill behind the progress.
  final double buffer;
  final bool enabled;
  final VoidCallback? onChangeStart;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// The drawn bar and the touch target. The player uses the defaults; the
  /// navbar's `navbar_seekbar` is a thinner line in a shorter band.
  final double trackHeight;
  final double hitHeight;

  /// What a screen reader calls the bar.
  final String semanticLabel;

  /// Renders a 0..1 position as something worth hearing ("1:40 / 3:20"); the
  /// percentage is the fallback.
  ///
  /// It is a function, not a string, because a node offering "increase" must
  /// also say what the value *would become* — Flutter asserts on a node that
  /// has one without the other — and only the caller knows the duration behind
  /// the fraction.
  final String Function(double fraction)? semanticValueFor;

  /// How far one "increase" / "decrease" gesture moves the bar. A screen
  /// reader cannot drag, so without these the bar could be read but never
  /// moved.
  final double semanticStep;

  static const defaultSemanticStep = 0.05;
  static const defaultTrackHeight = 7.0;
  static const defaultHitHeight = 35.0;
  static const padding = 12.0;
  static const thumbSize = Size(18, 10);

  @override
  State<ZenithSeekbar> createState() => _ZenithSeekbarState();
}

/// A horizontal drag that claims the pointer the moment it goes down.
///
/// The bar lives inside a scrollable player and, in the nav bar, under the
/// panel's own drag handler. Left to the gesture arena, a scrub that began
/// even slightly off-axis was won by one of those and the bar never moved —
/// the "can't scrub" symptom. Android's SeekBar does exactly this with
/// `requestDisallowInterceptTouchEvent`; the band is 35dp of dedicated
/// target, so claiming everything inside it is right.
class _EagerHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _ZenithSeekbarState extends State<ZenithSeekbar> {
  bool _dragging = false;
  double _width = 0;

  /// The value the finger is actually on. `DragEndDetails` carries no
  /// position, and reading it back from `widget.value` meant the drop point
  /// was whatever the parent had last rebuilt with — one update stale, so a
  /// quick scrub landed slightly behind where it was released.
  double _value = 0;

  double _valueAt(double dx) {
    final usable = _width - ZenithSeekbar.padding * 2;
    if (usable <= 0) return 0;
    return ((dx - ZenithSeekbar.padding) / usable).clamp(0.0, 1.0);
  }

  void _start(double dx) {
    if (!widget.enabled) return;
    _value = _valueAt(dx);
    setState(() => _dragging = true);
    widget.onChangeStart?.call();
    widget.onChanged?.call(_value);
  }

  void _update(double dx) {
    if (!widget.enabled) return;
    _value = _valueAt(dx);
    widget.onChanged?.call(_value);
  }

  void _end() {
    if (!widget.enabled) return;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(_value);
  }

  /// One screen-reader step. There is no drag to follow, so this commits the
  /// new position straight away, the same call a released drag makes.
  double _stepped(double delta) => (widget.value + delta).clamp(0.0, 1.0);

  String _readOut(double fraction) =>
      widget.semanticValueFor?.call(fraction) ?? '${(fraction * 100).round()}%';

  void _nudge(double delta) {
    final next = _stepped(delta);
    widget.onChanged?.call(next);
    widget.onChangeEnd?.call(next);
  }

  void _cancel() {
    if (!mounted) return;
    setState(() => _dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final seekable = widget.enabled && widget.onChangeEnd != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return Semantics(
          slider: true,
          enabled: widget.enabled,
          label: widget.semanticLabel,
          value: _readOut(widget.value),
          increasedValue: _readOut(_stepped(widget.semanticStep)),
          decreasedValue: _readOut(_stepped(-widget.semanticStep)),
          onIncrease: seekable ? () => _nudge(widget.semanticStep) : null,
          onDecrease: seekable ? () => _nudge(-widget.semanticStep) : null,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              // `DragStartBehavior.down` reports the touch-down point, so a
              // plain tap is a start + end on the same spot and still seeks
              // there — no separate tap recognizer competing for the pointer.
              _EagerHorizontalDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _EagerHorizontalDragRecognizer>(
                _EagerHorizontalDragRecognizer.new,
                (recognizer) {
                  recognizer.dragStartBehavior = DragStartBehavior.down;
                  recognizer.onStart = (d) => _start(d.localPosition.dx);
                  recognizer.onUpdate = (d) => _update(d.localPosition.dx);
                  recognizer.onEnd = (_) => _end();
                  recognizer.onCancel = _cancel;
                },
              ),
            },
            child: SizedBox(
              height: widget.hitHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _SeekbarPainter(
                  value: widget.value.clamp(0.0, 1.0),
                  buffer: widget.buffer.clamp(0.0, 1.0),
                  dragging: _dragging,
                  trackHeight: widget.trackHeight,
                  hole: isDark
                      ? const Color(0x11FFFFFF)
                      : const Color(0x11000000),
                  fill: scheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeekbarPainter extends CustomPainter {
  _SeekbarPainter({
    required this.value,
    required this.buffer,
    required this.dragging,
    required this.hole,
    required this.fill,
    required this.trackHeight,
  });

  final double value;
  final double buffer;
  final bool dragging;
  final Color hole;
  final Color fill;
  final double trackHeight;

  @override
  void paint(Canvas canvas, Size size) {
    const left = ZenithSeekbar.padding;
    final right = size.width - ZenithSeekbar.padding;
    final cy = size.height / 2;
    final h = trackHeight;
    const radius = Radius.circular(30);

    canvas.drawRRect(
      RRect.fromLTRBR(left, cy - h / 2, right, cy + h / 2, radius),
      Paint()..color = hole,
    );
    final usable = right - left;
    if (buffer > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          cy - h / 2,
          left + usable * buffer,
          cy + h / 2,
          radius,
        ),
        Paint()..color = fill.withValues(alpha: 0.12),
      );
    }
    final x = left + usable * value;
    if (value > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, cy - h / 2, x, cy + h / 2, radius),
        Paint()..color = fill,
      );
    }
    if (dragging) {
      const t = ZenithSeekbar.thumbSize;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, cy), width: t.width, height: t.height),
          const Radius.circular(10),
        ),
        Paint()..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeekbarPainter old) =>
      old.value != value ||
      old.buffer != buffer ||
      old.dragging != dragging ||
      old.hole != hole ||
      old.fill != fill ||
      old.trackHeight != trackHeight;
}
