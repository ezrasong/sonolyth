import 'package:shadcn_flutter/shadcn_flutter.dart';

/// `@drawable/popup_bg` as a card: one flat fill at `corners_popup`, no stroke.
///
/// In `@style/proxima`, `popup_bg` is a solid `#ff1a1a1a` at 20dp — the same
/// value the scheme's `popover` and `card` carry — and nothing in the skin puts
/// a stroke on a dialog frame (`colorStroke` is transparent). So a card that
/// stands in for a dialog — a getting-started step, the Last.fm login form — is
/// a rounded slab of `popover` and nothing more. The stock `Card` paints a 1px
/// `border` around the very same fill, and that hairline is the tell.
///
/// Content padding defaults to `dialogContentPaddingLR` (24dp).
class ZenithPopupCard extends StatelessWidget {
  const ZenithPopupCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.all(16),
    this.padding = const EdgeInsets.all(24),
    this.maxWidth = 400,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  /// `corners_popup` in `@style/proxima`.
  static const radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: margin,
      constraints: BoxConstraints(maxWidth: maxWidth),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.popover,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
