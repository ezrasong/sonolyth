import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The empty-state slot — **which draws nothing**.
///
/// Poweramp's empty list is `@style/ItemEmptyList`: a single line of centred
/// text at `textColorTertiary` (60%) with 16/4 padding, optionally followed by
/// `ItemEmptyListSettingsButton`. There is no artwork in it, and there is no
/// illustration anywhere else in Poweramp or Proxima either — not in the
/// library, not in search, not in the equaliser. A full-colour unDraw scene is
/// the single most off-skin thing the app could put on a screen.
///
/// This is kept as a widget rather than deleted from its ~17 call sites for two
/// reasons: the call sites stay readable as "an empty state goes here", and
/// turning the artwork back on is a one-line change in this file rather than a
/// seventeen-file revert. The [illustration], [height] and [width] arguments are
/// still accepted and still typed, so nothing has to be rewritten either way.
///
/// If it ever comes back, it needs the greyscale filter that used to live here —
/// unDraw's palette (a pink sun, navy foliage, skin tones) survives passing a
/// white `color`, because that argument only recolours the artwork's single
/// accent slot:
///
/// ```dart
/// const greyscale = ColorFilter.matrix(<double>[
///   0.2126, 0.7152, 0.0722, 0, 0,
///   0.2126, 0.7152, 0.0722, 0, 0,
///   0.2126, 0.7152, 0.0722, 0, 0,
///   0, 0, 0, 1, 0,
/// ]);
/// ```
class ZenithIllustration extends StatelessWidget {
  const ZenithIllustration({
    super.key,
    required this.illustration,
    this.height,
    this.width,
  });

  final UndrawIllustration illustration;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The text of an empty state — `@style/ItemEmptyListText`.
///
/// `textColorTertiary` (60%), centred, 16dp horizontal and 4dp vertical padding.
/// Since the artwork above is gone, this line *is* the empty state, so it is
/// worth using rather than leaving each call site to pick its own `.muted()`.
class ZenithEmptyListText extends StatelessWidget {
  const ZenithEmptyListText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.mutedForeground,
        ),
      ),
    );
  }
}
