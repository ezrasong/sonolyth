import 'dart:ui' show lerpDouble;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sonolyth/collections/nav_tiles.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/extensions/duration.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/modules/player/player_overlay.dart'
    show PlayerPanelMotion, playerOverlayControllerProvider;
import 'package:sonolyth/modules/player/use_progress.dart';
import 'package:sonolyth/modules/player/zenith_seekbar.dart';
import 'package:sonolyth/pages/library/library.dart'
    show libraryRootVisibleProvider;
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';

/// The navbar panel, read out of `merge_navbar.xml` and Proxima's `Navbar`
/// styles.
///
/// Poweramp's navbar is one panel with up to three rows — the mini player
/// (`navbar_list`), `navbar_seekbar`, and `navbar_nav_buttons` — and that is
/// exactly what the skin's screenshots show: the album-art mini row on top, a
/// thin seek line under it, the glyphs under that, all inside one rounded
/// shape. Here the mini row is the sliding panel's header
/// (`PlayerOverlayCollapsedSection`) and sits directly above this widget, which
/// draws the other two rows and rounds the bottom.
///
/// **The panel is `colorBgPrimary`, one step above the page.** `navbar_bg_player`
/// fills `PlayerNavStartColor` = `NavStartColor` = `colorBgPrimary`, and under
/// the skin's Black background option — the one its screenshots run — the page
/// is `colorAABgColor` `#000000` while `colorBgPrimary` is `#0E0E0F`. The
/// pictures measure the panel at exactly that: a `#0E0E0E` shape on black. On
/// the app's old `#0E0E0F` page the same fill vanished into a stripe, which is
/// why the bar never read as Proxima's.
///
/// **Under the open player the panel stays, as one line.** `scene_navbar_1line`
/// — the 40dp button row alone, all four corners rounded — is what the hero
/// screenshot shows beneath the transport. The player panel stops above it
/// (`PlayerOverlay` subtracts [ZenithNavBarMetrics.playerSceneHeight]), and a
/// tap on a tab closes the player before navigating.
///
/// Geometry is Proxima's: `Navbar` overrides `Base_Navbar`'s 17dp
/// `navbar_marginLR` with **`NavigationMargin` 35dp**, `Navbar_height` is 40dp,
/// `NavbarList` is 55dp with a −4dp bottom margin, `NavbarSeekbar` is a 32dp
/// band (`paddingTop` 10, `marginBottom` −6) carrying `seekbar_nav`'s 4dp line,
/// so 22dp separate the mini row from the buttons.
///
/// **Selection is the glyph's colour, nothing else.** `nv_nav_*_selector` swaps
/// the `colorIconDisabled` (#55ffffff) glyph for its `GradientStartColor`
/// (= `colorIconPrimary`) twin when activated; `nav_buttons_active`'s 2dp
/// stroke is the *ripple mask*, which is never painted. The screenshots
/// confirm it — the Library glyph is simply the accent, with no ring around
/// it. Home has no Poweramp glyph (Poweramp has no home) and keeps the app's.
abstract final class ZenithNavBarMetrics {
  /// `@dimen/Navbar_height`.
  static const barHeight = 40.0;

  /// From the mini row's bottom to the button row's top: `NavbarList`
  /// `marginBottom` −4 + `NavbarSeekbar_height` 32 + `marginBottom` −6.
  static const seekBandHeight = 22.0;

  /// `NavigationMargin` in `@style/proxima`.
  static const marginHorizontal = 35.0;

  /// `@dimen/Navbar_normal_marginB`.
  static const marginBottom = 4.0;

  /// `NavbarNavButtonsLayout` `padding`.
  static const buttonRowInset = 2.0;

  /// The panel's corners. `corners_navbar` is 5dp in `@style/proxima`'s
  /// defaults; the skin's screenshots — the reference the user pointed at —
  /// show the rounder "Navigation Style", which reads as about 20dp.
  static const cornerRadius = 20.0;

  /// Proxima's `navbar_elevation`.
  static const elevation = 3.0;

  /// `@dimen/NavBarButton_drawableSize` (28dp) × `NavIconScale` (0.75).
  static const iconSize = 21.0;

  /// `colorIconDisabled` — the resting glyph colour (#55ffffff in the dark
  /// skin), and its mirror for light.
  static const inactiveGlyphDark = Color(0x55FFFFFF);
  static const inactiveGlyphLight = Color(0x55000000);

  /// `NavbarSeekbar_marginLR`, and `seekbar_nav`'s 4dp line.
  static const seekInset = 10.0;
  static const seekLineHeight = 4.0;

  /// The footer slot with the player closed: seek band + buttons + margin.
  static const closedHeight = seekBandHeight + barHeight + marginBottom;

  /// `scene_navbar_1line`: the buttons alone, under the open player.
  static const playerSceneHeight = barHeight + marginBottom;
}

/// 50 with the player closed, 0 with it open; `PlayerOverlay` drives it from
/// the panel position and the mini row, the player and this bar all read it.
final navigationPanelHeight = StateProvider<double>((ref) => 50);

class SonolythNavigationBar extends HookConsumerWidget {
  const SonolythNavigationBar({
    super.key,
  });

  static ZenithNavGlyph? _glyphFor(String id) => switch (id) {
        "library" => ZenithNavGlyph.list,
        "search" => ZenithNavGlyph.search,
        _ => null,
      };

  @override
  Widget build(BuildContext context, ref) {
    final colorScheme = context.theme.colorScheme;

    final downloadCount = ref.watch(
      downloadManagerProvider.select(
        (tasks) => tasks
            .where((e) =>
                e.status == DownloadStatus.downloading ||
                e.status == DownloadStatus.queued)
            .length,
      ),
    );
    final hasTrack =
        ref.watch(audioPlayerProvider.select((s) => s.activeTrack != null));
    final (
      :bufferProgress,
      :duration,
      :position,
      :progressStatic,
      :seekable,
      :seek
    ) = useProgress(ref);

    // The nav bar's line is a seek bar too, and it had no drag feedback at
    // all: it drew `progressStatic` and only acted on release, so a scrub
    // there looked completely dead until you let go. Hold the dragged value
    // while a finger is on it, exactly as the full player does.
    final navSeek = useState<double?>(null);

    final navbarTileList = useMemoized(
      () => getNavbarTileList(context.l10n),
      [context.l10n],
    );

    final panelHeight = ref.watch(navigationPanelHeight);

    final router = context.watchRouter;
    // -1 when no tile matches (e.g. Settings, Lyrics); no tile is selected.
    final selectedIndex = navbarTileList.indexWhere(
      (e) => router.currentPath.startsWith(e.pathPrefix),
    );

    // Nothing hides this any more. It used to disappear above 820dp (or
    // whenever the Layout Mode setting said "extended") and hand navigation to
    // the desktop sidebar; there is no sidebar (§38), so the panel is the
    // navigation at every width, exactly as it is in Poweramp.

    // 1 with the player closed, 0 with it open. The three-line panel becomes
    // the one-line scene as the player rises: the seek band folds away and the
    // top corners round as soon as the mini row above has gone.
    final closed = (panelHeight / 50).clamp(0.0, 1.0);
    final threeLines = hasTrack;
    final bandHeight =
        threeLines ? ZenithNavBarMetrics.seekBandHeight * closed : 0.0;
    final slotHeight = threeLines
        ? lerpDouble(
            ZenithNavBarMetrics.playerSceneHeight,
            ZenithNavBarMetrics.closedHeight,
            closed,
          )!
        : ZenithNavBarMetrics.playerSceneHeight;
    // The panel's top corners are square only while the mini row is
    // really sitting on them. Halfway up the row has faded out, so the
    // shape rounds — on the position, not on a threshold that snapped
    // the corners the instant a drag began.
    final miniRowAttached = threeLines && closed > 0.5;
    final radius = Radius.circular(ZenithNavBarMetrics.cornerRadius);

    Future<void> select(NavTile tile) async {
      // Poweramp's Library button always lands on the category list, not on
      // the last category.
      if (tile.id == "library") {
        ref.read(libraryRootVisibleProvider.notifier).state = true;
      }
      // Under the open player the bar is still there (the one-line scene); a
      // tab tap closes the player first, the way Poweramp leaves its player
      // scene, then navigates.
      final panel = ref.read(playerOverlayControllerProvider);
      if (panel.isAttached && panel.isPanelOpen) {
        await panel.closeScene();
      }
      if (!context.mounted) return;
      context.navigateTo(tile.route);
    }

    return SizedBox(
      // The footer slot. The scrollable body extends behind it (the root
      // scaffold's footer floats), the way Poweramp's list runs under its
      // navbar, so the slot paints nothing while the player is closed. Under
      // the open player the slot is the player's own ground — the panel stops
      // at the bar's top edge, and without this the list showed through the
      // 35dp margins beside the one-line bar.
      height: slotHeight,
      child: ColoredBox(
        color: colorScheme.background.withValues(alpha: 1 - closed),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZenithNavBarMetrics.marginHorizontal,
            0,
            ZenithNavBarMetrics.marginHorizontal,
            ZenithNavBarMetrics.marginBottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // `navbar_bg_player`: PlayerNavStartColor == colorBgPrimary.
              color: zenithBgPrimary(colorScheme),
              // The mini row above rounds the top while it is attached.
              borderRadius: BorderRadius.vertical(
                top: miniRowAttached ? Radius.zero : radius,
                bottom: radius,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.background.withValues(alpha: 0.9),
                  blurRadius: ZenithNavBarMetrics.elevation * 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                // `navbar_seekbar` — a seek line inside the panel, folding away
                // as the player opens.
                ClipRect(
                  child: SizedBox(
                    height: bandHeight,
                    child: bandHeight <= 0
                        ? null
                        : OverflowBox(
                            minHeight: ZenithNavBarMetrics.seekBandHeight,
                            maxHeight: ZenithNavBarMetrics.seekBandHeight,
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ZenithNavBarMetrics.seekInset,
                              ),
                              child: ZenithSeekbar(
                                value: navSeek.value ?? progressStatic,
                                buffer: bufferProgress,
                                // Same rule as the full player's bar: a queue
                                // mpv never received cannot be scrubbed.
                                enabled: seekable,
                                semanticLabel: context.l10n.seek,
                                semanticValueFor: (f) =>
                                    "${Duration(milliseconds: (f * duration.inMilliseconds).round()).toHumanReadableString()}"
                                    " / ${duration.toHumanReadableString()}",
                                trackHeight: ZenithNavBarMetrics.seekLineHeight,
                                hitHeight: ZenithNavBarMetrics.seekBandHeight,
                                onChangeStart: () =>
                                    navSeek.value = progressStatic,
                                onChanged: (v) => navSeek.value = v,
                                onChangeEnd: (v) async {
                                  navSeek.value = null;
                                  await seek(
                                    Duration(
                                      milliseconds:
                                          (v * duration.inMilliseconds).round(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(
                  height: ZenithNavBarMetrics.barHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZenithNavBarMetrics.buttonRowInset,
                    ),
                    child: Row(
                      children: [
                        for (final tile in navbarTileList)
                          // `layout_flexWeight` is 1.0 on every NavBarButton.
                          Expanded(
                            child: _ZenithNavItem(
                              icon: tile.icon,
                              glyph: _glyphFor(tile.id),
                              label: tile.title,
                              selected: selectedIndex != -1 &&
                                  navbarTileList[selectedIndex] == tile,
                              badgeCount:
                                  tile.id == "library" ? downloadCount : 0,
                              onPressed: () => select(tile),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One nav button.
///
/// **There is no label, deliberately.** `@style/NavBarButton` sets
/// `drawableOnly="true"` — Poweramp's bottom bar is icons only. The label is
/// still passed through as the semantics label.
///
/// **Selection is a colour swap, not an outline.** The glyph steps from
/// `colorIconDisabled` to `colorIconPrimary` and nothing is drawn around it;
/// `nav_buttons_active`'s stroke is a ripple mask (see the class doc).
///
/// **No ripple.** Proxima's ripple colour is effectively invisible and the skin
/// signals press with a 0.95 scale (`ZenithPressable`) instead.
class _ZenithNavItem extends StatelessWidget {
  final IconData icon;
  final ZenithNavGlyph? glyph;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onPressed;

  const _ZenithNavItem({
    required this.icon,
    required this.glyph,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final foreground = selected
        ? colorScheme.primary
        : isDark
            ? ZenithNavBarMetrics.inactiveGlyphDark
            : ZenithNavBarMetrics.inactiveGlyphLight;

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: ZenithPressable(
        onPressed: onPressed,
        child: Center(
          child: SizedBox(
            // `minWidth`/`minHeight` 24dp on the button; the whole flex slot
            // is the hit target, this is just the glyph's box.
            width: 48,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: ZenithMotion.fade,
                  switchInCurve: ZenithMotion.fadeCurve,
                  switchOutCurve: ZenithMotion.fadeCurve,
                  child: KeyedSubtree(
                    key: ValueKey(selected),
                    child: glyph != null
                        ? ZenithNavIcon(
                            glyph!,
                            size: ZenithNavBarMetrics.iconSize,
                            color: foreground,
                          )
                        : Icon(
                            icon,
                            color: foreground,
                            size: ZenithNavBarMetrics.iconSize,
                          ),
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 2,
                    top: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // Cap wide counts so a 3-digit queue (e.g. 679) doesn't
                        // balloon past the button.
                        badgeCount > 99 ? "99+" : badgeCount.toString(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primaryForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
