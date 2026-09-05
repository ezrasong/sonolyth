import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The app's one tooltip: shadcn's [Tooltip] plus the semantics node the
/// package never emits.
///
/// shadcn's `Clickable` builds a plain `GestureDetector`, and its `Tooltip` is
/// a `Hover` + overlay with no `Semantics` at all — so every glyph-only control
/// in the app was announced by TalkBack as an unnamed "double-tap to activate"
/// rectangle. The tooltip string is already the control's name at every one of
/// those call sites, which makes it the [Semantics.label] for free.
///
/// It also takes the name as a plain [String] rather than a widget, so the
/// `TooltipContainer(child: Text(...)).call` boilerplate lives in one place.
///
/// Which constructor to use comes down to what the child already says for
/// itself. A label added on top of a child that carries the same text is not
/// harmless: the two merge into one node and a screen reader reads it twice
/// ("Select, Select" — how the `.selfNamed` case was found).
class ZenithTooltip extends StatelessWidget {
  /// The common case: a glyph you can press, with nothing but the tooltip to
  /// name it.
  const ZenithTooltip({
    super.key,
    required this.message,
    required this.child,
  })  : _button = true,
        _label = true;

  /// Names something that is *not* pressable — a status glyph that would
  /// otherwise be an unnamed image.
  const ZenithTooltip.status({
    super.key,
    required this.message,
    required this.child,
  })  : _button = false,
        _label = true;

  /// A control whose own text already names it (a "Select" button). It is
  /// still announced as a button; the tooltip just isn't repeated as a label.
  const ZenithTooltip.selfNamed({
    super.key,
    required this.message,
    required this.child,
  })  : _button = true,
        _label = false;

  /// The tooltip only spells out text the layout truncated, inside something
  /// that is already one semantics node (a card title under its cell's label).
  /// This adds nothing at all.
  const ZenithTooltip.plain({
    super.key,
    required this.message,
    required this.child,
  })  : _button = false,
        _label = false;

  /// Shown on hover / long-press, and read aloud as the control's name unless
  /// the child names itself.
  final String message;

  final Widget child;

  final bool _button;
  final bool _label;

  @override
  Widget build(BuildContext context) {
    final tooltip = Tooltip(
      tooltip: TooltipContainer(child: Text(message)).call,
      child: child,
    );
    if (!_button && !_label) return tooltip;
    return Semantics(
      label: _label ? message : null,
      button: _button,
      child: tooltip,
    );
  }
}
