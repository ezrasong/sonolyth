import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart'
    show ZenithTrackRowMetrics;

/// `ItemTrackPlayingMark` — how a Zenith list row says "this one is playing".
///
/// An inset, rounded 1dp outline at `SelectedTrackColor` (white 50%) over a
/// wash to `colorItemPlayingMark` (8%) — **not** a recoloured title and not a
/// filled row. `track_tile.dart` draws exactly this inline for track rows and
/// records the judgement call about the wash; this is the same mark for the
/// other rows a list can hold (an album, a playlist, a folder in list mode), so
/// that a playing folder and a playing track are marked identically.
///
/// Lay it under the row content in a [Stack]; it fills the row.
class ZenithPlayingMark extends StatelessWidget {
  const ZenithPlayingMark({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Positioned.fill(
      child: Padding(
        padding: ZenithTrackRowMetrics.playingMarkInset,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              ZenithTrackRowMetrics.playingMarkRadius,
            ),
            border: Border.all(color: primary.withAlpha(128), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [primary.withAlpha(0), primary.withAlpha(21)],
            ),
          ),
        ),
      ),
    );
  }
}
