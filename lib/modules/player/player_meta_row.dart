import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

/// `PlainSeekbar_TopTrackElapsedMoreButtons_scene_playing` scale 0.856 of the
/// 14dp `TopTrackElapsedDuration_Text` — the counters under the seek line, and
/// the track counter in the `sub_aa_buttons` row below them.
///
/// Lives here rather than in `ZenithPlayerMetrics` because this file is the one
/// that lays the counters out; `ZenithPlayerMetrics.counterSize` re-exports it
/// so the rest of the player keeps reading its geometry from one place.
const zenithPlayerCounterSize = 12.0;

/// The narrowest gap allowed between a counter and the chip between them.
///
/// The chip is centred in the slack the counters leave, so at the default font
/// size it floats well clear of both and this never binds — the row is
/// pixel-identical to the measured picture. It exists for the scales in
/// between, where the counters have grown but the row has not yet stacked and
/// the ring would otherwise sit flush against the digits.
const _chipGutter = 8.0;

/// Counter row → the chip on its own line, once the row stacks.
const _stackedChipGap = 6.0;

/// The elapsed / codec-chip / total row that hangs under the seek line —
/// `Zenith_TopCounterLayoutCustom` with `Zenith_TopMetaInfoLayout` between its
/// two counters.
///
/// At Android's 200% font size the three no longer share a line: the counters
/// take roughly twice the width they were measured at, the chip is squeezed
/// into what is left, and `flac • 16bit • 44.1kHz` ellipsised to
/// `flac • 16bit • 44.1…` while touching the digits at both ends (§43g). §42c
/// measured this slot and found it fitted, which it did — with the shorter
/// "Verify lossless" in it; the codec string is the long case and nothing had
/// measured that.
///
/// The answer is §37b's rule, the same one the settings rows and `SummaryCard`
/// already follow: past [zenithStackedRowTextScale] a row that has stopped
/// working stops being a row. The counters keep the line they were measured on
/// and the chip drops below them with the full width to itself. Below the
/// threshold nothing moves — [PlayerMetaRow.stacks] is `false` and the layout
/// is the picture's, to the pixel.
class PlayerMetaRow extends StatelessWidget {
  const PlayerMetaRow({
    super.key,
    required this.elapsed,
    required this.total,
    required this.chip,
    required this.seeking,
  });

  /// Left counter. While the bar is held this reads the spot under the finger.
  final String elapsed;

  /// Right counter — the track's duration.
  final String total;

  /// The `meta_info_button` pill: the codec line, or the verify action when the
  /// stream is blocked and there is no codec to name.
  final Widget chip;

  /// Dims and shrinks the chip while the seek bar is dragged
  /// (`PlainSeekbar_anim_seeking`), as the counters below do not — they are
  /// the thing being read during a scrub.
  final bool seeking;

  /// Whether the chip takes its own line at the viewer's font size.
  ///
  /// Exposed so the layout that decides whether the player is pinned or
  /// scrolled can budget for the extra line ([extraHeight] below).
  static bool stacks(BuildContext context) => zenithStacksRows(context);

  /// How much taller the row is than the single line the player's height
  /// estimate already allows for — **0 below the threshold, by construction**.
  ///
  /// Deliberately not "how tall is this row": re-measuring it from scratch
  /// would replace a generous estimate that has been right at the default scale
  /// since §31 with a tighter one, and a screen that is a few pixels short
  /// anchors and then overflows. §41f paid for that lesson inside `SummaryCard`
  /// — carry the measured box's overhead across and add only what was gained.
  static double extraHeight(BuildContext context) {
    if (!stacks(context)) return 0;
    const style = TextStyle(fontSize: zenithPlayerCounterSize);
    // The chip's text is the same size as a counter; what its line costs beyond
    // that is its own vertical padding and the 1dp `meta_info_button` ring on
    // each edge.
    return _stackedChipGap +
        zenithScaledLineHeight(context, style) +
        _chipPadding.vertical +
        2 * _chipRingWidth;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final counterStyle = TextStyle(
      fontSize: zenithPlayerCounterSize,
      color: colorScheme.mutedForeground,
    );
    final left = Text(elapsed, style: counterStyle);
    final right = Text(total, style: counterStyle);
    final seekingChip = ZenithSeeking(seeking: seeking, child: chip);

    if (stacks(context)) {
      return Column(
        // The player stacks this into a `Column` that hands its children loose
        // constraints, so the default `MainAxisSize.max` does not shrink-wrap —
        // it takes every pixel left below the seek line and pushes the
        // transport off the screen.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [left, right],
          ),
          const SizedBox(height: _stackedChipGap),
          // Centred, as it is between the counters — the chip is the row's
          // middle element wherever the row puts it.
          Align(child: seekingChip),
        ],
      );
    }

    return Row(
      children: [
        left,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _chipGutter),
            child: Center(child: seekingChip),
          ),
        ),
        right,
      ],
    );
  }
}

const _chipPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 3);

/// `@drawable/meta_info_button`'s 1dp stroke, on each edge of the pill.
const _chipRingWidth = 1.0;

/// `Zenith_TopMetaInfoLayout` / `TopMetaInfoLabel`: the codec line as a
/// `meta_info_button` pill between the counters, text at `ColorTrackLine`.
/// Poweramp opens its audio-info popup from it; here it opens the track
/// details.
class PlayerMetaChip extends StatelessWidget {
  const PlayerMetaChip({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.actionable = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// A glyph before the label. The codec line has none — Poweramp's is text
  /// only — so this is for the states where the chip stops reporting and
  /// starts asking.
  final IconData? icon;

  /// Fills the ring with `colorBgPositive` and lifts the text to `foreground`.
  ///
  /// The pill at rest is metadata: a 13% ring and 60% text, deliberately quiet
  /// because it names something that is already true. When it carries an
  /// *action* it has to read as one, and the skin's idiom for that is the same
  /// translucent 5% white [zenithPositiveButton] uses — never a fill with a
  /// hue, which `@style/proxima` has nowhere.
  final bool actionable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        actionable ? colorScheme.foreground : colorScheme.mutedForeground;
    final chip = Container(
      padding: _chipPadding,
      decoration: zenithRingDecoration(colorScheme).copyWith(
        color: actionable ? colorScheme.primary.withValues(alpha: 0.05) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: foreground),
            ),
          ),
        ],
      ),
    );
    if (onPressed == null) return chip;
    // `ZenithPressable` is a bare `GestureDetector` — it annotates the node the
    // label contributes to but claims no role, the §36 shape of defect that
    // `ZenithValueChip` already answers this way. The label names it, so no
    // `label:` here or it reads twice (§36b).
    return Semantics(
      button: true,
      child: ZenithPressable(onPressed: onPressed, child: chip),
    );
  }
}
