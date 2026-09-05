import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// **Proxima Dark Zenith** — the app's visual identity, ported from the
/// Proxima skin for Poweramp (`@style/proxima` + its `zenith_layout` player
/// layout).
///
/// The defining trait is that Proxima is **achromatic**: there is no hue
/// anywhere. Every accent, control, indicator and highlight is pure white (or
/// pure black in light mode) at a graded alpha over a near-black ground, and
/// the layout carries zero elevation — no shadows, no tinted surfaces. Depth
/// comes only from alpha and spacing.
///
/// Raw values below are the exact tokens read out of the decompiled skin, so
/// they can be checked against it:
///
/// The skin's store screenshots — the reference the user pointed at — run its
/// **"Black"** background option (`dark_background_black` /
/// `light_background_white` in Proxima's `styles.xml`), and that option is what
/// these tokens follow: the *page* is `colorAABgColor`, pure black, and
/// `colorBgPrimary` `#0E0E0F` is the raised surface the navbar panel, the
/// search pill, the filter chips and the header buttons are cut from. (With
/// the "Dark" option both step up: page `#121212`, surfaces `#1A1A1A`.)
///
/// | Proxima token            | dark        | light       |
/// | ------------------------ | ----------- | ----------- |
/// | `colorAABgColor` (page)  | `#000000`   | `#FFFFFF`   |
/// | `colorBgPrimary`         | `#0E0E0F`   | `#EDEDED`   |
/// | `colorKnobBg` (recessed) | `#09090A`   | `#F2F2F2`   |
/// | `textColorPrimary`       | white 90%   | black 90%   |
/// | `textColorSecondary`     | white 60%   | black 60%   |
/// | `colorTrackMeta`         | white 50%   | black 50%   |
/// | `colorTextDisabled`      | white 40%   | black 40%   |
/// | `colorStrokeHelp`        | white 13%   | black 7%    |
/// | `colorItemPlayingMark`   | white 8%    | black 8%    |
/// | `colorBgPositive`        | white 5%    | black 5%    |
/// | `colorIconPrimary`       | `#FFFFFF`   | `#000000`   |
///
/// The scheme colours are those tokens pre-flattened against the ground, so
/// widgets that need an opaque fill get the same result as the skin's alpha
/// compositing.
abstract final class ZenithPalette {
  // ---- Ground -----------------------------------------------------------
  /// `colorAABgColor` under the Black option — the page. Pure black: the
  /// skin's screenshots are shot on it, and every lighter surface reads
  /// against it.
  static const darkBackground = Color(0xFF000000);

  /// `colorBgPrimary` — the raised surface: the navbar panel, the search pill
  /// and its close button, the filter chips, `alpha_popup_button_layout_*`.
  /// One step above the page and the only step most controls take.
  static const darkSurfacePrimary = Color(0xFF0E0E0F);

  /// `colorKnobBg` — the recessed surface (sidebar/rails). Between the page
  /// and `colorBgPrimary`; Zenith recesses instead of raising; nothing floats.
  static const darkRecessed = Color(0xFF09090A);

  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurfacePrimary = Color(0xFFEDEDED);
  static const lightRecessed = Color(0xFFF2F2F2);

  /// `colorAABgColor` — the well behind artwork, and (under the Black option)
  /// the page itself. See [zenithArtWell].
  static const darkArtWell = Color(0xFF000000);
  static const lightArtWell = Color(0xFFFFFFFF);

  // ---- Dark surfaces -----------------------------------------------------
  /// `@drawable/popup_bg` is a flat `#ff1a1a1a` — menus, dialogs, cards.
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkSurfaceHigh = Color(0xFF141414); // white 8%  over the page
  static const darkSurfaceHover = Color(0xFF1A1A1A); // white 10% over the page
  static const darkBorder = Color(0xFF222222); // `colorStrokeHelp` 13%

  // ---- Dark text (white alpha flattened over the page) ------------------
  static const darkText = Color(0xFFE6E6E6); // 90%
  static const darkTextMuted = Color(0xFF999999); // 60% — `ColorTrackLine`
  static const darkTextMeta = Color(0xFF808080); // 50% — `colorTrackMeta`
  static const darkTextDisabled = Color(0xFF666666); // 40%

  // ---- Light surfaces (black alpha flattened over #FFFFFF) --------------
  static const lightSurface = Color(0xFFE9E9E9);
  static const lightSurfaceHigh = Color(0xFFFFFFFF);
  static const lightSurfaceHover = Color(0xFFE0E0E0);
  static const lightBorder = Color(0xFFDCDCDC);

  static const lightText = Color(0xFF1A1A1A);
  static const lightTextMuted = Color(0xFF626262);
  static const lightTextMeta = Color(0xFF7A7A7A);

  /// The only chromatic colour in the system, reserved for destructive intent
  /// — Proxima itself has none, so it must read as an exception, not an
  /// accent.
  static const destructive = Color(0xFFE5484D);
}

/// The Proxima Dark Zenith [ColorScheme].
///
/// Charts use a white-to-grey ramp rather than a categorical hue palette,
/// because introducing hues would break the achromatic rule that makes the
/// skin recognisable.
ColorScheme zenithColorScheme(ThemeMode mode) {
  final isLight = mode == ThemeMode.light;
  return isLight ? _zenithLight : _zenithDark;
}

/// `colorBgPrimary` — the raised surface (`#0E0E0F` dark, `#EDEDED` light)
/// that the navbar panel, the search pill and the filter chips are cut from.
///
/// Not a [ColorScheme] slot either: `card`/`popover` are `popup_bg`
/// (`#1A1A1A`), a full step above this, and `background` is the page below
/// it. Under the skin's Black option this is the *only* surface between the
/// two, and it is what makes the navbar read as a panel on the page rather
/// than as a stripe of it.
Color zenithBgPrimary(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
        ? ZenithPalette.darkSurfacePrimary
        : ZenithPalette.lightSurfacePrimary;

/// `colorTrackMeta` — white/black **50%**, the small bold metadata on a track
/// row (duration, bitrate, format).
///
/// It is not a [ColorScheme] slot: the scheme jumps straight from
/// `mutedForeground` (60%, Proxima's `ColorTrackLine`) to `border` (13%), and
/// Zenith grades text in three distinct steps, so the middle one needs its own
/// accessor rather than an approximation.
Color zenithTrackMeta(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
        ? ZenithPalette.darkTextMeta
        : ZenithPalette.lightTextMeta;

/// `SubheadText` — the label above a list or a rail ("Recently Played", "Top
/// tracks", a settings group).
///
/// **It is smaller and dimmer than the content it labels**, which is the
/// opposite of what a Material section header does. Poweramp sets it to 12sp
/// bold at `textColorSecondary` (`#99ffffff`, 60% — `mutedForeground` here),
/// against a 15sp near-white track title. Headings in Zenith recede so the
/// artwork and titles carry the page; a bright `h4` heading above a rail is the
/// clearest sign a screen has not been converted yet.
///
/// It is **not** all-caps: `Capitalizer` is `false` in `@style/proxima`, even
/// though Poweramp's own default themes set it true.
TextStyle zenithSubhead(ColorScheme scheme) => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: scheme.mutedForeground,
    );

/// The title of a screen or a collection header — `ItemTextTitle_Text` (18dp)
/// scaled by `ItemTextTitle_scene_header` (**1.6**), so 29sp.
///
/// **It is normal weight, not bold.** That is the part that is easy to get
/// wrong and the part that carries the look: Poweramp reserves weight for track
/// titles and small labels, and sets its display type in `normal`. A heavy
/// heading is a Material habit — an `h1`/`w800` page title reads as stock
/// Spotube immediately.
///
/// 29sp is also as large as anything in Proxima gets. Nothing in the skin
/// exceeds it except the 80dp letter that pops out of the scroll indexer, so a
/// bigger heading anywhere in the app has no source.
TextStyle zenithPageTitle(ColorScheme scheme) => TextStyle(
      fontSize: 29,
      fontWeight: FontWeight.w400,
      color: scheme.foreground,
    );

/// `@drawable/searchbar_bg` — the shape of every search and filter input.
///
/// Two tokens say the same thing and they are worth stating together, because
/// the result looks like a mistake until you know both:
///
///  * `searchbar_bg` is a `<solid>` at `SearchBgColor` with a **60dp** radius,
///    and `@style/proxima` points `SearchBgColor` at `colorBgPrimary` — the
///    page colour. So the pill is fully round and the same colour as what is
///    behind it.
///  * `@style/TopListSearchEditText` sets `android:background` to `@null`
///    outright, and there is no stroke on either.
///
/// A search field in Proxima is therefore a magnifier and a placeholder sitting
/// on the page, with no visible container at all — the same idiom as a
/// selected filter chip. This is passed as a whole `decoration` rather than as
/// `border`/`filled`/`borderRadius`, because shadcn only skips its default
/// outline and its `input.scaleAlpha(0.3)` wash when `decoration` is non-null.
///
/// `SearchBgColor` is `colorBgPrimary`. Under the Black option the page is
/// `colorAABgColor` (#000000) and the pill is `#0E0E0F` — exactly what the
/// skin's screenshots measure — so the pill is [zenithBgPrimary], solid.
BoxDecoration zenithSearchField(ColorScheme scheme) => BoxDecoration(
      color: zenithBgPrimary(scheme),
      borderRadius: BorderRadius.circular(60),
    );

/// A secondary header — the same `ItemTextTitle_Text` at
/// `ItemTextTitle_scene_subheader` scale (0.925), so 17sp, still normal weight.
TextStyle zenithSubheaderTitle(ColorScheme scheme) => TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      color: scheme.foreground,
    );

/// Album-art corners.
///
/// `corners_aa_*` is **0dp** in `@style/proxima`'s defaults, but every
/// screenshot the skin is sold on — and the ones the user pointed at as the
/// reference — runs its "Album Art Corners" option, and the radius read off
/// those pictures is about 12dp on the player's art and the same on list
/// thumbnails. One token so the whole app flips together; set it to 0 to go
/// back to the literal default.
abstract final class ZenithArt {
  static const radius = 12.0;
}

/// `colorKnobIndicatorDisabled` — the 1dp ring Proxima draws around its small
/// pill buttons (`meta_info_button`): `#22ffffff` in `@style/proxima`, a
/// translucent 13% rather than a flat grey, so it reads the same on the page
/// and on a `popup_bg` card.
Color zenithRingColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
        ? const Color(0x22FFFFFF)
        : const Color(0x22000000);

/// `@drawable/meta_info_button` — a transparent pill with a 1dp
/// [zenithRingColor] stroke at radius 20. The codec chip under the player's
/// seekbar and the two small buttons beside its title both wear it.
BoxDecoration zenithRingDecoration(ColorScheme scheme, {double radius = 20}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: zenithRingColor(scheme), width: 1),
    );

/// The same ring as a round button style, for the glyph buttons on the
/// player's title line (`Zenith_ItemTrackMenu_scene_aa`,
/// `Zenith_ItemTrackLyrics_scene_aa`).
AbstractButtonStyle zenithRingButtonStyle(ColorScheme scheme) =>
    ButtonVariance.ghost.copyWith(
      decoration: (context, states, value) => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: zenithRingColor(scheme), width: 1),
        color: states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)
            ? scheme.primary.withValues(alpha: 0.05)
            : const Color(0x00000000),
      ),
    );

/// `colorAABgColor` — the well behind artwork: what a thumbnail sits on before
/// its image arrives, and the fill of a placeholder that never gets one (a
/// folder with no scanned tracks).
///
/// Pure black in the dark theme (pure white in light) — *darker* than the
/// `#0E0E0F` ground, the only colour in the skin that sits below the page. The
/// unselected filter chip is the same token, which is why it reads as a well.
Color zenithArtWell(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? ZenithPalette.darkArtWell
    : ZenithPalette.lightArtWell;

/// `ItemTextLine2` — the second line of a *text* item (a settings row, a folder
/// header), 11dp at `textColorPrimary`.
///
/// Primary, not muted: Poweramp dims a *track* row's line 2 (`ColorTrackLine`,
/// 60%) but not a text item's. Only size separates a text item's two lines.
TextStyle zenithTextLine2(ColorScheme scheme) => TextStyle(
      fontSize: 11,
      color: scheme.foreground,
    );

/// `DialogTitle_Text` — 19sp **bold**. The heading of a dialog, or of a card
/// that stands in for one (a getting-started step, the Last.fm login form).
TextStyle zenithDialogTitle(ColorScheme scheme) => TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: scheme.foreground,
    );

/// `DialogPositiveButtonStyle` — the affirmative button of a dialog, or of a
/// card standing in for one: `ripple_bg_dialog_positive`, a `colorBgPositive`
/// fill at `corners_large` with the label at `textColorPrimary`.
///
/// `colorBgPositive` is **`#0dffffff`** — a translucent 5% white, not a
/// pre-flattened grey. That distinction is the whole reason this exists:
/// `Button.secondary` paints `colorScheme.secondary`, which is 5% white already
/// composited over the *page*, so on a `popup_bg` card of that same colour the
/// button disappears and the positive action reads exactly like the ghost
/// negative one beside it. A translucent fill lands one step above whatever it
/// sits on — `#1A1A1B` on the page, `#262627` on a card — which is what the
/// skin does. Never `Button.primary`: a white-filled pill has no source in
/// Proxima.
AbstractButtonStyle zenithPositiveButton(ColorScheme scheme) =>
    ButtonVariance.secondary.copyWith(
      decoration: (context, states, value) {
        final base = ButtonVariance.secondary.decoration(context, states);
        final box = base is BoxDecoration ? base : const BoxDecoration();
        final pressed = states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        return box.copyWith(
          // `colorItemPlayingMark` (8%) is the skin's next step up; it doubles
          // as the hover/press response, since Zenith has no ripple colour.
          color: scheme.primary.withValues(alpha: pressed ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(30),
        );
      },
    );

/// A ghost button that shows selection the way Proxima's
/// `alpha_popup_button_layout_activated_bg` does: a `colorBgPrimary` fill at
/// `corners_popup` (20dp) behind the glyph while activated, nothing at rest.
///
/// This is the skin's one "on" state for a small control — the header buttons,
/// the view-mode switch, the sidebar rail all wear it. The 2dp ring that stood
/// here before came from `nav_buttons_active`, whose stroke turned out to be
/// the ripple *mask* (never painted); the screenshots show no ring anywhere.
/// The fill is transparent rather than absent when unselected so the button's
/// geometry is identical in both states.
AbstractButtonStyle zenithSelectableGhost(
  ColorScheme scheme, {
  required bool selected,
}) =>
    ButtonVariance.ghost.copyWith(
      decoration: (context, states, value) {
        final base = ButtonVariance.ghost.decoration(context, states);
        final box = base is BoxDecoration ? base : const BoxDecoration();
        return box.copyWith(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? zenithBgPrimary(scheme)
              : zenithBgPrimary(scheme).withValues(alpha: 0),
        );
      },
    );

const _zenithDark = ColorScheme(
  brightness: Brightness.dark,
  background: ZenithPalette.darkBackground,
  foreground: ZenithPalette.darkText,
  card: ZenithPalette.darkSurface,
  cardForeground: ZenithPalette.darkText,
  // Proxima's `@drawable/popup_bg` is a flat `#ff1a1a1a` at radius 20 — the
  // same fill as a card, not a raised one. Menus and dialogs do not sit on a
  // lighter surface than the content behind them.
  popover: ZenithPalette.darkSurface,
  popoverForeground: ZenithPalette.darkText,
  // Proxima's accent IS white — `colorIconPrimary` / `ProButtonsStartColor`.
  primary: Color(0xFFFFFFFF),
  primaryForeground: ZenithPalette.darkBackground,
  secondary: ZenithPalette.darkSurface,
  secondaryForeground: ZenithPalette.darkText,
  muted: ZenithPalette.darkSurfaceHigh,
  mutedForeground: ZenithPalette.darkTextMuted,
  accent: ZenithPalette.darkSurfaceHover,
  accentForeground: Color(0xFFFFFFFF),
  destructive: ZenithPalette.destructive,
  destructiveForeground: Color(0xFFFFFFFF),
  border: ZenithPalette.darkBorder,
  input: ZenithPalette.darkBorder,
  ring: Color(0xFF8A8A8C),
  chart1: Color(0xFFFFFFFF),
  chart2: Color(0xFFC9C9CB),
  chart3: Color(0xFF9C9C9E),
  chart4: Color(0xFF6E6E70),
  chart5: Color(0xFF454547),
  sidebar: ZenithPalette.darkRecessed,
  sidebarForeground: ZenithPalette.darkText,
  sidebarPrimary: Color(0xFFFFFFFF),
  sidebarPrimaryForeground: ZenithPalette.darkBackground,
  sidebarAccent: ZenithPalette.darkSurface,
  sidebarAccentForeground: Color(0xFFFFFFFF),
  sidebarBorder: ZenithPalette.darkBorder,
  sidebarRing: Color(0xFF8A8A8C),
);

const _zenithLight = ColorScheme(
  brightness: Brightness.light,
  background: ZenithPalette.lightBackground,
  foreground: ZenithPalette.lightText,
  card: ZenithPalette.lightSurfaceHigh,
  cardForeground: ZenithPalette.lightText,
  popover: ZenithPalette.lightSurfaceHigh,
  popoverForeground: ZenithPalette.lightText,
  primary: Color(0xFF000000),
  primaryForeground: ZenithPalette.lightBackground,
  secondary: ZenithPalette.lightSurface,
  secondaryForeground: ZenithPalette.lightText,
  muted: ZenithPalette.lightSurface,
  mutedForeground: ZenithPalette.lightTextMuted,
  accent: ZenithPalette.lightSurfaceHover,
  accentForeground: Color(0xFF000000),
  destructive: Color(0xFFDC3E42),
  destructiveForeground: Color(0xFFFFFFFF),
  border: ZenithPalette.lightBorder,
  input: ZenithPalette.lightBorder,
  ring: Color(0xFF8A8A8A),
  chart1: Color(0xFF000000),
  chart2: Color(0xFF3D3D3D),
  chart3: Color(0xFF626262),
  chart4: Color(0xFF8A8A8A),
  chart5: Color(0xFFB5B5B5),
  sidebar: ZenithPalette.lightRecessed,
  sidebarForeground: ZenithPalette.lightText,
  sidebarPrimary: Color(0xFF000000),
  sidebarPrimaryForeground: ZenithPalette.lightBackground,
  sidebarAccent: ZenithPalette.lightSurface,
  sidebarAccentForeground: Color(0xFF000000),
  sidebarBorder: ZenithPalette.lightBorder,
  sidebarRing: Color(0xFF8A8A8A),
);

/// How much taller one line of [style] is at the viewer's system font size
/// than it is at the default — the number a fixed row or cell height has to
/// grow by to still hold its text when Android's font size has been turned up.
///
/// **Why this exists rather than a scaled height.** Every row and cell height
/// in this app is measured geometry: 225dp for a grid cell, 55dp for the
/// navbar's mini row, 96dp for a track row, all read off the skin and the Play
/// Store screenshots (§27/§28/§31). Multiplying them by the font scale would
/// throw those measurements away for everybody. Adding *only the growth* keeps
/// them exact — this returns **0** at the default scale, by construction — and
/// still honours a viewer who needs 200% text, which otherwise gets clipped
/// (the whole of §37).
///
/// Measured rather than approximated with a line-height constant: the theme is
/// free to set `height` on a style, and a wrong constant shows up as either a
/// clipped descender or a visible gap.
double zenithLineGrowth(BuildContext context, TextStyle style) {
  final scaled = _lineHeight(style, MediaQuery.textScalerOf(context));
  final unscaled = _lineHeight(style, TextScaler.noScaling);
  return math.max(0, scaled - unscaled);
}

/// The full height one line of [style] occupies at the viewer's font size.
///
/// [zenithLineGrowth] answers "how much taller did this get", which is what a
/// box that already has room for a line needs. This answers "how tall is a
/// line I am about to add", which is what a box that gains one needs — a
/// summary card's unit moving under its figure past
/// [zenithStackedRowTextScale], for instance.
double zenithScaledLineHeight(BuildContext context, TextStyle style) =>
    _lineHeight(style, MediaQuery.textScalerOf(context));

double _lineHeight(TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    // Any single glyph lays out to exactly one line box; the glyph itself does
    // not affect the height, only the style and the scaler do.
    text: TextSpan(text: 'x', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Above this system font scale a control that shares a row with a label stops
/// sharing it: the two stack instead.
///
/// A settings row pairs a label with a [ZenithValueChip], and the chip takes
/// its natural width — so "United States (US)" at 200% left the label
/// "Marketplace Region" wrapping one word per line down the left edge of the
/// screen. Reflowing is what Android's own settings do; the threshold is high
/// enough that no default-scale layout is affected and low enough to catch the
/// point where a two-column row stops working at this width.
const zenithStackedRowTextScale = 1.3;

/// Whether label-plus-value rows should stack at the viewer's font size.
///
/// Probed at **body-text size**, deliberately. Android 14's font scaling is
/// non-linear — it grows small text much more than large text, so the same
/// system setting that doubles a 14sp label barely moves a 100sp heading. The
/// first version of this asked `scale(100) / 100`, got 1.3 at a system setting
/// of 200%, and never crossed its own threshold: the rows stayed squeezed on a
/// device while the check said they were fine.
bool zenithStacksRows(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(_stackProbeSize) / _stackProbeSize >
    zenithStackedRowTextScale;

/// A settings row's label size — what the threshold has to be measured at.
const _stackProbeSize = 14.0;

/// Android's minimum touch target, and the app's rule for reaching it.
///
/// **The rule is: keep the drawn control, grow the box.** Almost every small
/// control in this app is Proxima's measured geometry — the nav glyphs, the
/// mini play button, the transport's dots — and growing what is *drawn* would
/// undo the 1:1 replica §27/§28/§31 measured off the Play Store shots. What
/// Android actually asks for is 48dp of *target*, which is a different number:
/// a 14dp dot centred in a 48dp box is still a 14dp dot (CONTEXT item 42).
///
/// Where a control has no slack around it — the navbar's 40dp button row with
/// the 22dp seek band stacked on top of it — the shortfall is recorded rather
/// than fixed. Two adjacent controls cannot both be 48dp inside 62.
const kMinTapTarget = 48.0;
