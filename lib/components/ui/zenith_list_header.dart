import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';

/// Poweramp's list chrome, the parts every list shares: the back decor above
/// a list ("‹ Library", "‹ Albums"), the big title row of a top-level list
/// ("Library", "Playlists"), and the small header buttons under a header.
///
/// Read out of `item_top_text_back_decor.xml`, `item_text.xml`'s
/// `scene_top_header` and `merge_item_header.xml`, with the `_scene_header`
/// styles Proxima overrides — and checked against the skin's screenshots,
/// which is where two numbers that look wrong come from (the back decor's
/// label is *small*, and the title has a wide left margin).
abstract final class ZenithListHeaderMetrics {
  // ---- item_top_text_back_decor ------------------------------------------
  /// `ItemTopTextBackDecorTitle` is `ItemTextTitle_scene_top_header` (18dp ×
  /// 1.6) re-scaled by `scene_header_back_decor`'s `scale` **0.8** — and that
  /// scale is absolute, not compounded: 18 × 0.8 = 14.4sp, normal weight. The
  /// screenshot's "‹ Albums" measures exactly that, a caption beside a ring,
  /// not a second title.
  static const backLabelSize = 14.4;

  /// `drawableWidth` 32dp × 0.8, `drawablePaddingStart` 8 × 0.8, and the
  /// button's 6dp top/bottom padding × 0.8.
  static const backGlyphSize = 25.6;
  static const backGap = 6.4;
  static const backPaddingV = 4.8;
  static const backPaddingRight = 12.8;

  /// `ItemBackDecorTitle_scene_header_back_decor_marginLeft` 9dp on top of the
  /// list header's own 12dp inset — the ring sits ~21dp in, which is where the
  /// picture has it. `layout_marginTop` 8, Proxima's `layout_marginBottom` 5.
  static const backLeft = 21.0;
  static const backTop = 8.0;
  static const backBottom = 5.0;

  // ---- ItemTextTitle_scene_top_header --------------------------------------
  /// The header row is `textItemSize` (64dp) tall with the title centred in
  /// it, at `layout_marginLeft` 8 + the 12dp text padding scaled 1.6 ≈ 28dp;
  /// the picture's "Library" starts 32dp in, glyph bearing included.
  static const titleRowHeight = 64.0;
  static const titleLeft = 28.0;

  /// `ItemTextMenu_scene_top_header`: `layout_marginRight` 16dp, the
  /// `header_menu` glyph (`ListMenu_drawableSize` 20dp) at Proxima's 0.9. Its
  /// centre measures 42dp from the right edge in every list shot (Library,
  /// Header Overlay, search), so the `BlackListMenu` slot is 52dp wide
  /// (16 + 26) and 40dp tall — a 40dp square put it 6dp too far right.
  static const menuRight = 16.0;
  static const menuGlyphSize = 18.0;
  static const menuButtonSize = 40.0;
  static const menuButtonWidth = 52.0;

  // ---- ItemHeader*Button_scene_header --------------------------------------
  /// `BlackListHeaderButton_scene_header`: 36dp tall, the `BlackButtonBase`
  /// 15 + 24 + 15 wide. Proxima's 0.9 is `android:scaleX/Y` — a *visual*
  /// transform — so the layout keeps the 54dp slot while the glyph (21.6dp)
  /// and the height (32dp) draw at 0.9. Measured in both the Header Overlay
  /// and the search shots: glyph centres 60dp apart, the first ≈ 40dp in
  /// (12 + 27). The 49dp slot this used to be drifted 15dp by "Select".
  static const buttonWidth = 54.0;
  static const buttonHeight = 32.0;
  static const buttonGlyphSize = 21.6;

  /// `ItemHeaderSelectButton_maxWidth` 64dp — the "Select" text button is
  /// wider than a glyph slot; its centre measures 165dp in after two glyph
  /// buttons (12 + 60 + 60 + 32 + the 6dp gap), 225dp after three.
  static const selectButtonWidth = 64.0;

  /// `ListHeaderButton_scene_header_marginLeft` 12. The measured 60dp pitch
  /// leaves 6dp between 54dp slots; the default theme's −4.5 `marginRight`
  /// would say 7.5, the pictures say 6.
  static const buttonsLeft = 12.0;
  static const buttonGap = 6.0;

  /// `ListHeaderButton_scene_header_marginBottom` / `ListMenu_scene_header_marginBottom`.
  static const buttonsBottom = 7.0;
  static const menuBottom = 5.0;

  /// `BlackButton_Text` 14dp × 0.9 — the "Select" label.
  static const buttonTextSize = 12.6;

  /// `merge_item_text_header` in `scene_search_header` — the same row under
  /// the search chips. The glyph centres measure 26dp under the chip row: 6dp
  /// above the 40dp row box (the menu slot's height, glyphs centred in it);
  /// `WhiteStroked*_scene_search_header` keeps the 7dp `marginBottom`.
  static const searchHeaderTop = 6.0;

  /// `alpha_popup_button_layout_activated_bg`: the activated state is a
  /// `colorBgPrimary` fill at `corners_popup` 20dp behind the glyph.
  static const activeRadius = 20.0;
}

/// `item_top_text_back_decor` — "‹ Parent": the `header_library_back` ring
/// glyph and the parent list's name, small, at the top-left of a list.
class ZenithBackDecor extends StatelessWidget {
  const ZenithBackDecor({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZenithListHeaderMetrics.backLeft,
        ZenithListHeaderMetrics.backTop,
        0,
        ZenithListHeaderMetrics.backBottom,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        // The row's own `Text(label)` names this node — see the note in
        // `library.dart`; a `label:` here would say it twice.
        child: Semantics(
          button: true,
          child: ZenithPressable(
            onPressed: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                ZenithListHeaderMetrics.backPaddingV,
                ZenithListHeaderMetrics.backPaddingRight,
                ZenithListHeaderMetrics.backPaddingV,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZenithHeaderBackIcon(
                    size: ZenithListHeaderMetrics.backGlyphSize,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: ZenithListHeaderMetrics.backGap),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: ZenithListHeaderMetrics.backLabelSize,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ItemTextTitle_scene_top_header` — a top-level list's title row: 64dp, the
/// 29sp normal-weight title 28dp in, and whatever the list puts at the right
/// (Poweramp: the `header_menu` glyph, 16dp from the edge).
class ZenithListTitle extends StatelessWidget {
  const ZenithListTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return SizedBox(
      height: ZenithListHeaderMetrics.titleRowHeight,
      child: Row(
        children: [
          const SizedBox(width: ZenithListHeaderMetrics.titleLeft),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: zenithPageTitle(colorScheme),
            ),
          ),
          if (trailing != null) ...[
            // The `BlackListMenu` slot: 52 × 40, glyph centred, so the menu
            // lands 42dp from the edge like every other list's.
            SizedBox(
              width: ZenithListHeaderMetrics.menuButtonWidth,
              height: ZenithListHeaderMetrics.menuButtonSize,
              child: trailing,
            ),
            const SizedBox(width: ZenithListHeaderMetrics.menuRight),
          ] else
            const SizedBox(width: ZenithListHeaderMetrics.titleLeft),
        ],
      ),
    );
  }
}

/// One `ItemHeader*Button_scene_header`: a bare glyph (or a short label) on a
/// 49 × 32 target. `alpha_popup_button_layout_activated_bg` is transparent at
/// rest and a `colorBgPrimary` pill at `corners_popup` when activated — the
/// state a toggle (the list filter, shuffle) wears while it is on.
class ZenithHeaderButton extends StatelessWidget {
  const ZenithHeaderButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.glyph,
    this.icon,
    this.label,
    this.color,
    this.loading = false,
    this.enabled = true,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback onPressed;

  /// One of Proxima's own header vectors.
  final ZenithHeaderGlyph? glyph;

  /// An app icon, for a button Proxima has no vector for.
  final IconData? icon;

  /// A text button (`ItemHeaderSelectButton`: "Select").
  final String? label;
  final Color? color;
  final bool loading;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final fg = color ?? colorScheme.primary;

    final Widget content;
    if (label != null) {
      content = Text(
        label!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ZenithListHeaderMetrics.buttonTextSize,
          fontWeight: FontWeight.w400,
          color:
              selected ? colorScheme.foreground : colorScheme.mutedForeground,
        ),
      );
    } else if (glyph != null) {
      content = ZenithHeaderIcon(
        glyph!,
        size: ZenithListHeaderMetrics.buttonGlyphSize,
        color: fg,
      );
    } else {
      content = Icon(
        icon,
        size: ZenithListHeaderMetrics.buttonGlyphSize,
        color: fg,
      );
    }

    // A text button ("Select") already says its own name, so the tooltip must
    // not repeat it — the accessibility tree read "Select, Select". A glyph
    // button has nothing but the tooltip, so there it *is* the name.
    final tip = label != null ? ZenithTooltip.selfNamed : ZenithTooltip.new;

    return tip(
      message: tooltip,
      child: ZenithPressable(
        onPressed: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: ZenithMotion.fade,
          curve: ZenithMotion.fadeCurve,
          height: ZenithListHeaderMetrics.buttonHeight,
          // A glyph sits in the 54dp `BlackButtonBase` slot; a label
          // ("Select") in `ItemHeaderSelectButton_maxWidth` 64 — a longer
          // translation grows past it rather than clipping.
          constraints: BoxConstraints(
            minWidth: label == null
                ? ZenithListHeaderMetrics.buttonWidth
                : ZenithListHeaderMetrics.selectButtonWidth,
          ),
          padding: label == null
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? zenithBgPrimary(colorScheme)
                : zenithBgPrimary(colorScheme).withValues(alpha: 0),
            borderRadius: BorderRadius.circular(
              ZenithListHeaderMetrics.activeRadius,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                // `disabledAlpha` 0.275.
                opacity: loading ? 0 : (enabled ? 1 : 0.275),
                child: content,
              ),
              if (loading)
                const CircularProgressIndicator(onSurface: false, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// `merge_item_text_header` under Proxima — the header-button row of a text
/// list (Playlists, Albums, Artists, Folders). Poweramp's search glyph
/// **reveals** the list filter (`TopListSearchEditText` on `searchbar_bg`) and
/// closes it again; the row's other buttons follow it; the `header_menu` glyph
/// at the right holds the list options — here the grid/list view mode. The
/// filter is not on screen until asked for, which is the whole difference from
/// the permanent pill these pages used to carry, and the reason the pictures'
/// lists start right under their title.
class ZenithListToolbar extends StatefulWidget {
  const ZenithListToolbar({
    super.key,
    required this.filterPlaceholder,
    required this.onFilterChanged,
    this.buttons = const [],
    this.menuItems,
    this.onMenuSelected,
  });

  final String filterPlaceholder;
  final ValueChanged<String> onFilterChanged;

  /// Further [ZenithHeaderButton]s after the search glyph.
  final List<Widget> buttons;

  /// The `header_menu` items; no glyph is drawn when null.
  final List<AdaptiveMenuButton<String>> Function(BuildContext)? menuItems;
  final ValueChanged<String>? onMenuSelected;

  @override
  State<ZenithListToolbar> createState() => _ZenithListToolbarState();
}

class _ZenithListToolbarState extends State<ZenithListToolbar> {
  bool _open = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      // Focus once the field has laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else {
      // Closing drops the filter, the way Poweramp's close does.
      _controller.clear();
      _focusNode.unfocus();
      widget.onFilterChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZenithListHeaderMetrics.buttonsLeft,
            0,
            ZenithListHeaderMetrics.menuRight,
            ZenithListHeaderMetrics.buttonsBottom,
          ),
          child: Row(
            children: [
              ZenithHeaderButton(
                tooltip: context.l10n.search,
                glyph: ZenithHeaderGlyph.search,
                selected: _open,
                onPressed: _toggle,
              ),
              for (final button in widget.buttons) ...[
                const SizedBox(width: ZenithListHeaderMetrics.buttonGap),
                button,
              ],
              const Spacer(),
              if (widget.menuItems != null)
                SizedBox(
                  width: ZenithListHeaderMetrics.menuButtonWidth,
                  height: ZenithListHeaderMetrics.menuButtonSize,
                  child: AdaptivePopSheetList<String>(
                    tooltip: context.l10n.more_actions,
                    items: widget.menuItems!,
                    icon: ZenithHeaderMenuIcon(
                      size: ZenithListHeaderMetrics.menuGlyphSize,
                      color: colorScheme.primary,
                    ),
                    onSelected: widget.onMenuSelected ?? (_) {},
                  ),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: ZenithMotion.scene,
          curve: ZenithMotion.slideCurve,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: zenithSearchField(colorScheme),
                      features: const [
                        InputFeature.leading(Icon(SonolythIcons.filter)),
                      ],
                      placeholder: Text(widget.filterPlaceholder),
                      onChanged: widget.onFilterChanged,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}
