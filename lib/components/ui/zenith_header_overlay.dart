import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';

/// Poweramp's list header, `scene_header` of `item_track` + `merge_item_header`
/// under Proxima — the skin's "Header Overlay".
///
/// The album art is the header itself: `ItemTrackAAImage_scene_header` fills
/// the header and `overlay_header` sits on it — a vertical gradient of
/// `colorAABgColor` (black) from opaque at the bottom through 60% to 20% at the
/// top, which is why the screenshots' header art is dim and darkest where the
/// text sits. Above it all, `item_top_text_back_decor`: "‹ Albums".
///
/// **The header's type is the track row's type, not a page title.** The text
/// stack at the bottom edge is `ItemTrackTitle_scene_header` — the row title's
/// `ItemTrackTitle_Text` (16.5dp **bold**) at `ItemTrackTitle_scene_header_scale`
/// 0.9, so 15sp — then `ItemTrackLine2_scene_header` (14.5 × 0.9 = 13sp, at
/// `textColorPrimaryInverse`, which Proxima makes the same white as primary)
/// and `ItemTrackMeta_scene_header` (11dp bold at `colorTrackMeta`, 50%):
/// "♪ 2 | 6:45 | 2022". The skin's screenshot measures exactly that — a 15sp
/// "Chasing Dreams" the same size as the row title under it. The 29sp
/// normal-weight title that stood here was `ItemTextTitle_scene_header`, the
/// *Library* header's style, and it made every collection page read as a
/// different screen.
///
/// Then the header buttons (`ItemHeader*Button_scene_header`, Proxima's own
/// `header_shuffle` / `header_play` / `header_search` vectors at 0.9), the
/// **"Select"** text button that toggles selection mode, and the `header_menu`
/// two-dot glyph at the right. Saving the collection lives in that menu:
/// Poweramp's header has no heart, and the pictures show none.
abstract final class ZenithHeaderMetrics {
  /// The header's height on a phone, status bar included (the art runs under
  /// it). The first row starts ~295dp down in the screenshot.
  static const phoneHeight = 300.0;
  static const wideHeight = 320.0;

  /// `ItemTrackTitle_scene_header` 12dp margin + `ItemTrackTitle_paddingLR`.
  static const textInset = 24.0;

  /// `ItemTrackTitle_Text` 16.5 × `ItemTrackTitle_scene_header_scale` 0.9.
  static const titleSize = 15.0;

  /// `ItemTrackLine2_Text` 14.5 × `ItemTrackLine2_scene_header_scale` 0.9.
  static const line2Size = 13.0;

  /// `ItemTrackMeta_Text` 11dp bold, `scene_header` scale 1.0.
  static const metaSize = 11.0;
  static const metaGlyphSize = 12.0;
  static const metaGlyphGap = 5.0;

  static const titleToLine2 = 6.0;
  static const line2ToMeta = 6.0;
  static const metaToButtons = 4.0;
}

/// The Header Overlay itself, without any opinion about what it is a header
/// *for*. A collection page fills it from `TrackPresentationOptions`; the
/// artist page fills it from the artist. Keeping one widget is the only way
/// the two stay measurably identical.
class ZenithHeaderOverlay extends StatelessWidget {
  const ZenithHeaderOverlay({
    super.key,
    required this.image,
    required this.parentLabel,
    required this.title,
    required this.buttons,
    this.line2,
    this.metaParts = const [],
    this.menu,
    this.height,
    this.onBack,
  });

  /// The art that *is* the header.
  final String image;

  /// `item_top_text_back_decor`: "‹ Albums" / "‹ Playlists" / "‹ Artists".
  final String parentLabel;
  final VoidCallback? onBack;

  final String title;
  final String? line2;

  /// The `ItemTrackMeta` parts, joined with the skin's "  |  ".
  final List<String> metaParts;

  /// `ItemHeader*Button_scene_header`s, left to right. Gaps are inserted here
  /// so callers pass the buttons alone.
  final List<Widget> buttons;

  /// The `header_menu` glyph at the right edge.
  final Widget? menu;

  final double? height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    final metaColor = zenithTrackMeta(colorScheme);

    final texts = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZenithHeaderMetrics.textInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ZenithHeaderMetrics.titleSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: colorScheme.foreground,
            ),
          ),
          if (line2 != null && line2!.isNotEmpty) ...[
            const SizedBox(height: ZenithHeaderMetrics.titleToLine2),
            Text(
              line2!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ZenithHeaderMetrics.line2Size,
                fontWeight: FontWeight.w400,
                color: colorScheme.foreground,
              ),
            ),
          ],
          if (metaParts.isNotEmpty) ...[
            const SizedBox(height: ZenithHeaderMetrics.line2ToMeta),
            Row(
              children: [
                ZenithMetaNoteIcon(
                  size: ZenithHeaderMetrics.metaGlyphSize,
                  color: metaColor,
                ),
                const SizedBox(width: ZenithHeaderMetrics.metaGlyphGap),
                Flexible(
                  child: Text(
                    metaParts.join("  |  "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ZenithHeaderMetrics.metaSize,
                      fontWeight: FontWeight.w700,
                      color: metaColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final buttonRow = Padding(
      padding: const EdgeInsets.fromLTRB(
        ZenithListHeaderMetrics.buttonsLeft,
        0,
        ZenithListHeaderMetrics.menuRight,
        ZenithListHeaderMetrics.buttonsBottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: ZenithListHeaderMetrics.buttonGap),
            buttons[i],
          ],
          const Spacer(),
          if (menu != null) menu!,
        ],
      ),
    );

    return SizedBox(
      height: height ?? ZenithHeaderMetrics.phoneHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The art *is* the header.
          Image(
            image: UniversalImage.imageProvider(image),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // `ItemTrackAAImage_scene_header_drawableTintColor` is
          // `colorAABgColor_30`: the whole header art sits under 30% black
          // before the gradient, which is why the picture's header is dim
          // even at the top.
          const ColoredBox(color: Color(0x4D000000)),
          // `overlay_header`: colorAABgColor 100% → 60% → 20%, bottom-up.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFF000000),
                  Color(0x99000000),
                  Color(0x33000000),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            top: topPadding,
            left: 0,
            child: ZenithBackDecor(
              label: parentLabel,
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                texts,
                const SizedBox(height: ZenithHeaderMetrics.metaToButtons),
                buttonRow,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
