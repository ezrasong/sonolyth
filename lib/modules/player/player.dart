import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart' show PlaylistMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:sonolyth/collections/assets.gen.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/dialogs/track_details_dialog.dart';
import 'package:sonolyth/components/framework/app_pop_scope.dart';
import 'package:sonolyth/components/heart_button/heart_button.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/duration.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/player/player_actions.dart';
import 'package:sonolyth/modules/player/player_line2.dart';
import 'package:sonolyth/modules/player/play_or_verify.dart';
import 'package:sonolyth/modules/player/player_meta_row.dart';
import 'package:sonolyth/modules/player/player_overlay.dart'
    show PlayerPanelMotion;
import 'package:sonolyth/modules/player/use_progress.dart';
import 'package:sonolyth/modules/settings/playback/zarz_verify_dialog.dart';
import 'package:sonolyth/modules/player/zenith_seekbar.dart';
import 'package:sonolyth/modules/root/sonolyth_navigation_bar.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/querying_track_info.dart';
import 'package:sonolyth/provider/audio_player/smart_shuffle.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/provider/server/sourced_track_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/audio_source/quality_label.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

/// The Zenith player, laid out the way Poweramp lays it out under Proxima's
/// `zenith_layout`.
///
/// Poweramp's player is not a screen of its own: it is the current track's list
/// item in its album-art scene (`ItemTrack*_scene_aa`) with the seekbar,
/// counters and transport (`waveseek_layout`, `sub_aa_buttons`) attached under
/// it. Read out of `activity_main.xml`, `item_track.xml` and the `Zenith_*`
/// styles in Proxima's own `styles.xml` — and checked against the skin's
/// screenshots — the order top to bottom is:
///
/// 1. the art (`aaMargin` 21dp each side, `Zenith_aaSize` 0.975, square,
///    `aa_elevation`), with the like/rating control **centred on its bottom
///    edge** in a `rating_bg` pill (`Zenith_ItemLikeUnlikeLayout_scene_aa`);
/// 2. the title (×1.2) and "artist - album" line, with the **lyrics and menu
///    glyphs as two small ringed buttons at the right of the title line**
///    (`Zenith_ItemTrackLyrics_scene_aa`, `Zenith_ItemTrackMenu_scene_aa`,
///    both on `meta_info_button`);
/// 3. the seekbar (`SeekbarMargin` 23dp), then elapsed and duration at its
///    ends with the codec **meta chip between them** (`Zenith_TopMetaInfoLayout`
///    attaches to `track_elapsed` / `track_duration`, `ZenithTopAudioInfoMargin`
///    27.5dp);
/// 4. `sub_aa_buttons`: five evenly spaced small glyphs with the track counter
///    in the middle slot (`Zenith_TopCounterLayoutCustom`, alpha 0.55);
/// 5. the transport: Proxima's own pro-button shapes as **outlines**
///    (`probuttons_icon_stroke`, the style the Zenith screenshot runs), play at
///    `ProButtonsScale` 0.5 of the base, with the multipurpose dots — ±10s —
///    at either end.
///
/// What is deliberately **not** here, because Poweramp has none of it in this
/// layout: a volume slider (Poweramp's is a popup panel), Queue / Lyrics text
/// buttons, a separate action row, a codec badge at the foot of the screen.
/// Queue, details, download and alternative sources live in the menu glyph;
/// the sleep timer is a slot in the small-glyph row; the heart is on the art.
///
/// The dots that flank Poweramp's transport are `probuttons_dot_multipurpose`,
/// the glyph its ±10s slots wear, and that is what they do here; the
/// prev/next-*category* meaning has nothing to step through in this player.
///
/// **Top-anchored.** Everything stacks down from the art with the picture's
/// gaps and the slack is left at the bottom, where Poweramp's one-line navbar
/// sits under the player. The 26sp title, the 48dp play glyph and the
/// bottom-pinned transport that were here read as a different layout.
abstract final class ZenithPlayerMetrics {
  /// `aaMargin`.
  static const artMargin = 21.0;

  /// `Zenith_aaSize` is 0.975 by default; the Zenith screenshot's art measures
  /// 338dp on a 398dp screen — 0.95 — and the picture wins.
  static const artScale = 0.95;

  /// The art's top edge sits ~26dp under the status bar in the picture, with
  /// nothing above it: no title bar, no collapse chevron.
  static const artTopGap = 24.0;

  /// `aa_elevation` — the one raised surface in the theme.
  static const artElevation = 20.0;

  /// Read off the screenshot: art bottom → title text-box top.
  static const artToTitleGap = 34.0;

  /// `ItemTrackTitle_Text` 16.5dp **bold** × `Alt_ItemTrackTitle_scene_aa_scale`
  /// 1.2 = 19.8sp. Bold: the text appearance is bold and Zenith keeps it — the
  /// 26sp normal-weight title that stood here had no source.
  static const titleSize = 20.0;

  /// `ItemTrackLine2_Text` 14.5dp × `Alt_ItemTrackLine2_scene_aa_scale` 1.0.
  static const line2Size = 14.5;
  static const titleToLine2Gap = 6.0;

  /// Line 2 → the seek line is 26dp in the picture; the seekbar widget's 35dp
  /// hit band puts its 7dp line 14dp below its own top edge.
  static const line2ToSeekbarGap = 12.0;

  /// `SeekbarMargin` is 23dp in `zenith_layout`, but the drawn track in the
  /// Zenith screenshot is inset **24.5dp** from the screen edge in total —
  /// and `ZenithSeekbar` already spends 12dp of its own on the touch
  /// padding Poweramp's `PlainSeekbar` declares. 12 + 12 lands on the
  /// picture; 23 + 12 left the line a visible 10dp short at each end. The
  /// pictures win (§1).
  static const seekbarMargin = 12.0;

  /// Seek line → the codec chip / counters row: 15dp visible in the picture,
  /// 14 of which the hit band already gives.
  static const seekbarToMetaGap = 4.0;

  /// Chip row → the `sub_aa_buttons` row (40dp tall, glyphs centred).
  static const metaToSubAAGap = 26.0;
  static const subAARowHeight = 40.0;

  /// `sub_aa_buttons` → the transport (the play glyph's top sits 53dp under
  /// the small glyphs' bottom; the button's 8dp padding takes part of it).
  static const subAAToTransportGap = 46.0;

  /// The ringed title-line buttons: `BlackListMenu_scene_aa` (0.9) re-scaled
  /// by `Zenith_ItemTrackMenu_scene_aa` 0.75 → a 30dp ring, 5dp apart
  /// (`Zenith_ItemTrackLyrics_scene_aa` attaches 2dp left of the menu).
  static const ringButtonSize = 30.0;
  static const ringGlyphSize = 15.0;
  static const ringGap = 5.0;

  /// The small glyphs measure 17–18dp in the picture, at `colorIconDisabled`.
  static const subAAGlyphSize = 17.0;

  /// `ProButtonsScale` 0.5 of the base buttons: play 40dp, prev/next 30dp —
  /// measured off the picture, where the play outline is 40 × 43.
  static const playSize = 40.0;
  static const prevNextSize = 30.0;
  static const transportGap = 30.0;

  /// The dots flanking the transport (`probuttons_dot_multipurpose`), and the
  /// gap between them and prev/next.
  static const dotSize = 14.0;
  static const dotGap = 44.0;

  // ---- Tap targets: the drawn control, and the box it is centred in --------
  //
  // Read off the device's accessibility tree, the transport measured 30dp for
  // the ±10s dots and 46dp for prev/next — under Android's 48dp minimum, and
  // the dots by a lot (CONTEXT item 42). Every one of those numbers is
  // Proxima's, so growing the *glyphs* would undo §31's measurement against
  // the picture. Growing the **box** costs nothing: the transport row spends
  // 44dp of nothing between a dot and prev, and a 14dp dot centred in 48dp is
  // still a 14dp dot.
  //
  // The gaps below are what makes it free. [dotGap] and [transportGap] are the
  // picture's gaps between the *drawn* controls; a box that grew by 18dp eats
  // 9dp of the gap at each end, so the laid-out gap gives exactly that back
  // and **every drawn centre stays where it was** — pinned by
  // `test/modules/player/transport_metrics_test.dart`.

  /// `_ProButton`'s own padding, which is what the picture has.
  static const proButtonPadding = 8.0;

  /// A transport control's laid-out box: the drawn glyph plus
  /// [proButtonPadding], or [kMinTapTarget], whichever is larger.
  static double proButtonBox(double glyphSize) =>
      max(glyphSize + proButtonPadding * 2, kMinTapTarget);

  /// How far [proButtonBox] reaches past the drawn control on **each** side.
  static double proButtonBleed(double glyphSize) =>
      (proButtonBox(glyphSize) - (glyphSize + proButtonPadding * 2)) / 2;

  /// [dotGap], less what the two boxes either side of it took.
  static double get laidOutDotGap =>
      dotGap - proButtonBleed(dotSize) - proButtonBleed(prevNextSize);

  /// [transportGap], less the same.
  static double get laidOutTransportGap =>
      transportGap - proButtonBleed(prevNextSize) - proButtonBleed(playSize);

  /// What the dots do here: Poweramp's multipurpose slots are its ±10s seek.
  static const skipStep = Duration(seconds: 10);

  /// `Zenith_ItemLikeUnlikeLayout_scene_aa` `layout_marginBottom`.
  static const heartPillBottom = 8.0;

  /// `PlainSeekbar_TopTrackElapsedMoreButtons_scene_playing` scale 0.856 of
  /// the 14dp `TopTrackElapsedDuration_Text`. Defined beside the row that lays
  /// the counters out ([PlayerMetaRow]) and re-exported here.
  static const counterSize = zenithPlayerCounterSize;

  /// `Zenith_TopCounterLayoutCustom` alpha.
  static const trackCounterAlpha = 0.55;

  /// The track counter's share of the five-slot `sub_aa_buttons` row.
  ///
  /// One slot each is the picture, and at the default font size that is what
  /// this returns — the row stays pixel-identical. At Android's 200% a
  /// [counterSize] line reads about twice as wide, and "136 / 233" no longer
  /// fits a fifth of the art's width: it wrapped, and the fixed
  /// [subAARowHeight] ate the second line with **no `RenderFlex` error** to
  /// show for it (§42d) — the silent-clip class §37 paid for once and §41f
  /// closed inside `SummaryCard`.
  ///
  /// Past [zenithStackedRowTextScale] the counter takes three slots and the
  /// four glyphs share the remaining four; they only ever hold a
  /// [subAAGlyphSize] icon, so the slack is theirs to give. Widening a *flex*
  /// share rather than letting the text take its natural width is deliberate:
  /// the row cannot overflow, whatever the locale does to the digits.
  static int trackCounterFlex(BuildContext context) =>
      zenithStacksRows(context) ? 3 : 1;

  /// Everything from the art down, at a given width — used to decide whether
  /// the layout fits the viewport (and stacks down from the art with the slack
  /// left at the bottom, as Poweramp's does) or has to scroll. Deliberately
  /// generous: pinning a screen that is a few pixels too short would overflow,
  /// scrolling one that is a few pixels too tall only leaves a gap.
  ///
  /// [extraMetaRowHeight] is what the counter row gained by stacking its chip
  /// onto a second line ([PlayerMetaRow.extraHeight]) — 0 at every font size
  /// below the reflow threshold, so the estimate this has been making since
  /// §31 is untouched there.
  static double estimatedHeight(
    double width,
    double textScale, {
    double extraMetaRowHeight = 0,
  }) {
    final art = (width - 2 * artMargin) * artScale;
    final text =
        (titleSize * 1.2 + titleToLine2Gap + line2Size * 1.3) * textScale;
    const seekbar = 35.0; // ZenithSeekbar.hitHeight
    final metaRow = 28.0 * textScale + extraMetaRowHeight;
    const transport = playSize + 16;
    const bottom = 24.0;
    return artTopGap +
        art +
        artToTitleGap +
        text +
        line2ToSeekbarGap +
        seekbar +
        seekbarToMetaGap +
        metaRow +
        metaToSubAAGap +
        subAARowHeight +
        subAAToTransportGap +
        transport +
        bottom +
        16;
  }
}

class PlayerView extends HookConsumerWidget {
  final PanelController panelController;
  final ScrollController scrollController;
  const PlayerView({
    super.key,
    required this.panelController,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playlist = ref.watch(audioPlayerProvider);
    final currentActiveTrack = playlist.activeTrack;
    final isLocalTrack = currentActiveTrack is SonolythLocalTrackObject;
    final mediaQuery = MediaQuery.sizeOf(context);
    final qualityLabel = ref.watch(audioSourceQualityLabelProvider);
    final needsVerification =
        ref.watch(activeTrackVerificationBlockedProvider);
    // Not the same fact as [needsVerification], and it arrives first: the gate
    // holds the queue the instant it is built, while the chip's state waits on
    // a resolve that has to fail before it can say anything.
    final deferred = ref.watch(playbackDeferredProvider);
    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    final downloader = ref.read(downloadManagerProvider.notifier);

    // Seeded from the panel's current position, not from a bare `true`:
    // this widget can be built while the panel is already open (a rebuild
    // of the overlay, a hot reload), and a `true` it never gets a change
    // notification to clear leaves the open player empty.
    final shouldHide = useState(ref.read(navigationPanelHeight) >= 49.999);

    // Cover swipe state: the art follows the finger while dragging, springs
    // back on release, and the track-change slide direction is remembered so
    // the next cover enters from the side that was swiped toward.
    final coverDragX = useState<double>(0);
    final coverDragging = useState(false);
    final coverSwipeDir = useRef<int>(0);

    // Seek state. `progress` mirrors playback except while the bar is held.
    final (
      :bufferProgress,
      :duration,
      :position,
      :progressStatic,
      :seekable,
      :seek
    ) = useProgress(ref);
    final progress = useState<double>(progressStatic);
    final isDragging = useState(false);
    useEffect(() {
      if (!isDragging.value) progress.value = progressStatic;
      return null;
    }, [progressStatic]);

    // Mounted for the whole travel, not from a threshold a few pixels in:
    // `PlayerSceneEnter` fades it up from 35% open, and a tree that only
    // starts existing at 49/50 has nothing to fade. Still unmounted at rest,
    // so the closed app never builds the player.
    ref.listen(navigationPanelHeight, (_, height) {
      shouldHide.value = height >= 49.999;
    });

    useEffect(() {
      if (mediaQuery.lgAndUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          panelController.close();
        });
      }
      return null;
    }, [mediaQuery.lgAndUp]);

    String albumArt = useMemoized(
      () => (currentActiveTrack?.album.images).asUrlString(
        placeholder: ImagePlaceholder.albumArt,
      ),
      [currentActiveTrack?.album.images],
    );

    useEffect(() {
      for (final renderView in WidgetsBinding.instance.renderViews) {
        renderView.automaticSystemUiAdjustment = false;
      }

      return () {
        for (final renderView in WidgetsBinding.instance.renderViews) {
          renderView.automaticSystemUiAdjustment = true;
        }
      };
    }, [panelController.isAttached && panelController.isPanelOpen]);

    // All hooks above must run unconditionally on every build; only after them
    // is it safe to short-circuit the widget tree (Rules of Hooks).
    if (shouldHide.value) {
      return const SizedBox();
    }

    // The art's actual left edge: the 21dp margin plus the 1.25% the 0.975
    // scale leaves on each side. Title, counters and the ringed buttons align
    // to it, as they do in the skin.
    final artEdgeInset = ZenithPlayerMetrics.artMargin +
        (1 - ZenithPlayerMetrics.artScale) /
            2 *
            (mediaQuery.width - 2 * ZenithPlayerMetrics.artMargin);

    // `colorIconDisabled` (#55ffffff): the small glyphs rest a third bright
    // and step to the foreground when their mode is on.
    final mutedGlyph = colorScheme.brightness == Brightness.dark
        ? ZenithNavBarMetrics.inactiveGlyphDark
        : ZenithNavBarMetrics.inactiveGlyphLight;
    final activeGlyph = colorScheme.foreground;

    final loopMode = playlist.loopMode;
    final shuffled = playlist.shuffled;
    final smartShuffle = ref.watch(smartShuffleProvider);
    final shuffleActive = shuffled || smartShuffle;

    final showHeart = currentActiveTrack != null &&
        !isLocalTrack &&
        authenticated.asData?.value == true;

    final line2 = [
      currentActiveTrack?.artists.asString(),
      currentActiveTrack?.album.name,
    ].where((s) => s != null && s.isNotEmpty).join(" - ");

    return AppPopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        // A sheet opened from the player (menu, queue, sources) is an overlay
        // above the panel, not a route: back with one open closes the sheet
        // and keeps the player. It used to slide the player away and leave
        // the sheet floating over whatever page was underneath.
        if (context.closeOpenDrawer()) return;
        await panelController.closeScene();
      },
      child: SurfaceCard(
        borderWidth: 0,
        // Fully opaque: the app disables surface blur globally, so a <1 opacity
        // here doesn't frost the backdrop — it just bleeds the screen behind
        // the player through (e.g. Settings text showing under the title).
        surfaceOpacity: 1,
        padding: EdgeInsets.zero,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // No title bar and no collapse chevron: Poweramp's player has
          // neither. The art starts just under the status bar and the layout
          // stacks down from it with fixed gaps, leaving whatever is left
          // above the navbar — exactly the screenshot's proportions. Swipe
          // down or the system back dismiss the panel.
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Pinning is decided from the metrics, not from intrinsic
                // measurement: `IntrinsicHeight` cannot look through the
                // `LayoutBuilder` in the seekbar, and it blanked the whole player.
                final anchored = constraints.maxHeight >=
                    ZenithPlayerMetrics.estimatedHeight(
                      constraints.maxWidth,
                      MediaQuery.textScalerOf(context).scale(1),
                      extraMetaRowHeight: PlayerMetaRow.extraHeight(context),
                    );
                final body = Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: ZenithPlayerMetrics.artTopGap),
                      // Poweramp sizes the art inside the AA bounds and
                      // centres it there, with the controls attached to the
                      // bottom. Our art is square and width-limited, so on a
                      // screen taller than the reference's 720dp the slack
                      // has to go somewhere: it used to pile up *below* the
                      // transport row, leaving 122dp of dead black under it
                      // where the picture has 10. Split it around the art
                      // instead. Only when the layout is pinned — a Spacer
                      // in a scrolling Column has no bounded height.
                      if (anchored) const Spacer(),
                      // ---- 1. Art, with the heart on its bottom edge ------------
                      GestureDetector(
                        onHorizontalDragStart: (_) =>
                            coverDragging.value = true,
                        onHorizontalDragUpdate: (details) {
                          coverDragX.value =
                              (coverDragX.value + details.delta.dx)
                                  .clamp(-160.0, 160.0)
                                  .toDouble();
                        },
                        onHorizontalDragCancel: () {
                          coverDragging.value = false;
                          coverDragX.value = 0;
                        },
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          final offset = coverDragX.value;
                          coverDragging.value = false;
                          coverDragX.value = 0;
                          if (offset < -60 || velocity < -300) {
                            coverSwipeDir.value = 1;
                            audioPlayer.skipToNext();
                          } else if (offset > 60 || velocity > 300) {
                            coverSwipeDir.value = -1;
                            audioPlayer.skipToPrevious();
                          }
                        },
                        child: AnimatedSlide(
                          offset: Offset(coverDragX.value / 300, 0),
                          duration: coverDragging.value
                              ? Duration.zero
                              : ZenithMotion.scene,
                          curve: ZenithMotion.slideCurve,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZenithPlayerMetrics.artMargin,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: ZenithPlayerMetrics.artScale,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: AnimatedSwitcher(
                                        // `aa_fade_in` (600ms) when the art
                                        // simply changed; a cover swipe keeps the
                                        // app's slide so the art follows the
                                        // finger's direction.
                                        duration: coverSwipeDir.value == 0
                                            ? ZenithMotion.artFadeIn
                                            : ZenithMotion.scene,
                                        switchInCurve: ZenithMotion.slideCurve,
                                        switchOutCurve: ZenithMotion.slideCurve,
                                        transitionBuilder: (child, animation) {
                                          final dir =
                                              coverSwipeDir.value.toDouble();
                                          final incoming =
                                              child.key == ValueKey(albumArt);
                                          if (dir == 0) {
                                            return zenithArtTransition(
                                              child,
                                              animation,
                                            );
                                          }
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween(
                                                begin: Offset(
                                                  incoming ? dir : -dir,
                                                  0,
                                                ),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                        // Fill the square. Left to size itself the
                                        // image took its intrinsic pixel size and
                                        // floated inside a larger box — which is
                                        // also where the heart pill was measuring
                                        // its bottom edge from.
                                        child: SizedBox.expand(
                                          key: ValueKey(albumArt),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                ZenithArt.radius,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withAlpha(140),
                                                  blurRadius:
                                                      ZenithPlayerMetrics
                                                          .artElevation,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                ZenithArt.radius,
                                              ),
                                              child: UniversalImage(
                                                path: albumArt,
                                                placeholder: Assets.images
                                                    .albumPlaceholder.path,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (showHeart)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom:
                                            ZenithPlayerMetrics.heartPillBottom,
                                        child: Center(
                                          child: _HeartPill(
                                            track: currentActiveTrack,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (anchored) const Spacer(),
                      const SizedBox(height: ZenithPlayerMetrics.artToTitleGap),

                      // ---- 2. Title line with the lyrics and menu glyphs -------
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: artEdgeInset),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ZenithSeeking(
                                seeking: isDragging.value,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentActiveTrack?.name ??
                                          context.l10n.not_playing,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: ZenithPlayerMetrics.titleSize,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                    const SizedBox(
                                      height:
                                          ZenithPlayerMetrics.titleToLine2Gap,
                                    ),
                                    if (isLocalTrack ||
                                        currentActiveTrack == null)
                                      Text(
                                        line2,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize:
                                              ZenithPlayerMetrics.line2Size,
                                          color: colorScheme.mutedForeground,
                                        ),
                                      )
                                    else
                                      // Poweramp's line 2 in the AA scene reads
                                      // "artist - album"; the artists stay
                                      // links, and it stays ONE line.
                                      PlayerLine2(
                                        artists: currentActiveTrack.artists,
                                        album: currentActiveTrack.album.name,
                                        style: TextStyle(
                                          fontSize:
                                              ZenithPlayerMetrics.line2Size,
                                          color: colorScheme.mutedForeground,
                                        ),
                                        onArtistTap: (route) {
                                          panelController.closeScene();
                                          context.router.navigateNamed(route);
                                        },
                                        onOverflowTap: () {
                                          context.navigateTo(
                                            TrackRoute(
                                              trackId: currentActiveTrack.id,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const Gap(ZenithPlayerMetrics.ringGap),
                            _RingButton(
                              tooltip: context.l10n.lyrics,
                              icon: SonolythIcons.lyrics,
                              onPressed: () {
                                context.pushRoute(const PlayerLyricsRoute());
                              },
                            ),
                            const Gap(ZenithPlayerMetrics.ringGap),
                            SizedBox.square(
                              dimension: ZenithPlayerMetrics.ringButtonSize,
                              child: AdaptivePopSheetList<String>(
                                tooltip: context.l10n.more_actions,
                                variance: zenithRingButtonStyle(colorScheme),
                                icon: const Icon(
                                  SonolythIcons.moreVertical,
                                  size: ZenithPlayerMetrics.ringGlyphSize,
                                ),
                                headings: [Text(context.l10n.more_actions)],
                                onSelected: (action) async {
                                  switch (action) {
                                    case "details":
                                      if (currentActiveTrack
                                          is SonolythFullTrackObject) {
                                        showDialog(
                                          context: context,
                                          builder: (context) =>
                                              TrackDetailsDialog(
                                            track: currentActiveTrack,
                                          ),
                                        );
                                      }
                                    case "queue":
                                      context
                                          .pushRoute(const PlayerQueueRoute());
                                    case "sources":
                                      context.pushRoute(
                                        const PlayerTrackSourcesRoute(),
                                      );
                                    case "download":
                                      if (currentActiveTrack
                                          is SonolythFullTrackObject) {
                                        downloader
                                            .addToQueue(currentActiveTrack);
                                      }
                                  }
                                },
                                items: (context) => [
                                  AdaptiveMenuButton(
                                    value: "queue",
                                    leading: const Icon(SonolythIcons.queue),
                                    child: Text(context.l10n.queue),
                                  ),
                                  if (currentActiveTrack
                                      is SonolythFullTrackObject)
                                    AdaptiveMenuButton(
                                      value: "details",
                                      leading: const Icon(SonolythIcons.info),
                                      child: Text(context.l10n.details),
                                    ),
                                  if (!isLocalTrack &&
                                      currentActiveTrack != null)
                                    AdaptiveMenuButton(
                                      value: "sources",
                                      leading: const Icon(
                                        SonolythIcons.alternativeRoute,
                                      ),
                                      child: Text(
                                        context.l10n.alternative_track_sources,
                                      ),
                                    ),
                                  if (currentActiveTrack
                                      is SonolythFullTrackObject)
                                    AdaptiveMenuButton(
                                      value: "download",
                                      leading:
                                          const Icon(SonolythIcons.download),
                                      child: Text(context.l10n.download_track),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                          height: ZenithPlayerMetrics.line2ToSeekbarGap),

                      // ---- 3. Seekbar, then counters flanking the meta chip ----
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZenithPlayerMetrics.seekbarMargin,
                        ),
                        child: ZenithSeekbarSwell(
                          seeking: isDragging.value,
                          child: ZenithSeekbar(
                            value: progress.value,
                            buffer: bufferProgress,
                            // `seekable` is false while the queue is held
                            // out of mpv (item 64): the total below is the
                            // track's own, but there is no open media to move
                            // a position in.
                            enabled: seekable && !isFetchingActiveTrack,
                            semanticLabel: context.l10n.seek,
                            semanticValueFor: (f) =>
                                "${Duration(milliseconds: (f * duration.inMilliseconds).round()).toHumanReadableString()}"
                                " / ${duration.toHumanReadableString()}",
                            onChangeStart: () => isDragging.value = true,
                            onChanged: (v) => progress.value = v,
                            onChangeEnd: (v) async {
                              isDragging.value = false;
                              // `seek` holds the bar at the requested spot
                              // until playback reaches it, so releasing no
                              // longer snaps back to the old position.
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
                      const SizedBox(
                          height: ZenithPlayerMetrics.seekbarToMetaGap),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZenithPlayerMetrics.seekbarMargin +
                              ZenithSeekbar.padding,
                        ),
                        child: PlayerMetaRow(
                          // While the bar is held the counter reads the spot
                          // under the finger, not where playback still is —
                          // you scrub *to* a time.
                          elapsed: (isDragging.value
                                  ? Duration(
                                      milliseconds: (progress.value *
                                              duration.inMilliseconds)
                                          .round(),
                                    )
                                  : position)
                              .toHumanReadableString(),
                          total: duration.toHumanReadableString(),
                          seeking: isDragging.value,
                          // Blocked, the chip stops naming a codec and starts
                          // offering the fix. It is the only status element on
                          // this screen, and while a verify is outstanding the
                          // label it would otherwise show is the *preset*, not
                          // the stream — a confident description of something
                          // that was never fetched, on a screen that otherwise
                          // reads as merely broken (item 53).
                          chip: needsVerification
                              ? PlayerMetaChip(
                                  // Hardcoded English like the rest of this
                                  // feature — the toast, the dialog and its
                                  // button all are. One translated string out
                                  // of five is worse than none.
                                  label: "Verify lossless",
                                  icon: SonolythIcons.audioQuality,
                                  actionable: true,
                                  onPressed: () => verifyLosslessAccess(
                                    context,
                                    ref,
                                  ),
                                )
                              : PlayerMetaChip(
                                  label: qualityLabel,
                                  onPressed: currentActiveTrack
                                          is SonolythFullTrackObject
                                      ? () => showDialog(
                                            context: context,
                                            builder: (context) =>
                                                TrackDetailsDialog(
                                              track: currentActiveTrack,
                                            ),
                                          )
                                      : null,
                                ),
                        ),
                      ),
                      const SizedBox(
                          height: ZenithPlayerMetrics.metaToSubAAGap),

                      // ---- 4. sub_aa_buttons: five slots, counter in the middle -
                      // `fitCentered` 5 slots across the art's width.
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: artEdgeInset),
                        child: SizedBox(
                          height: ZenithPlayerMetrics.subAARowHeight,
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: ZenithTooltip(
                                    message: context.l10n.queue,
                                    child: IconButton.ghost(
                                      shape: ButtonShape.circle,
                                      icon: Icon(
                                        SonolythIcons.queue,
                                        size:
                                            ZenithPlayerMetrics.subAAGlyphSize,
                                        color: mutedGlyph,
                                      ),
                                      enabled: currentActiveTrack != null,
                                      onPressed: () {
                                        context.pushRoute(
                                            const PlayerQueueRoute());
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: SleepTimerButton(
                                    iconSize:
                                        ZenithPlayerMetrics.subAAGlyphSize,
                                    color: mutedGlyph,
                                    activeColor: activeGlyph,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: ZenithPlayerMetrics.trackCounterFlex(
                                  context,
                                ),
                                child: Center(
                                  child: Text(
                                    playlist.tracks.isEmpty
                                        ? "–"
                                        : "${playlist.currentIndex + 1} / "
                                            "${playlist.tracks.length}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: ZenithPlayerMetrics.counterSize,
                                      color: colorScheme.foreground.withValues(
                                        alpha: ZenithPlayerMetrics
                                            .trackCounterAlpha,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: ZenithTooltip(
                                    message: loopMode == PlaylistMode.single
                                        ? context.l10n.loop_track
                                        : loopMode == PlaylistMode.loop
                                            ? context.l10n.repeat_playlist
                                            : context.l10n.no_loop,
                                    child: IconButton.ghost(
                                      shape: ButtonShape.circle,
                                      icon: Icon(
                                        loopMode == PlaylistMode.single
                                            ? SonolythIcons.repeatOne
                                            : SonolythIcons.repeat,
                                        size:
                                            ZenithPlayerMetrics.subAAGlyphSize,
                                        color: loopMode != PlaylistMode.none
                                            ? activeGlyph
                                            : mutedGlyph,
                                      ),
                                      onPressed: () => audioPlayer.setLoopMode(
                                        switch (loopMode) {
                                          PlaylistMode.loop =>
                                            PlaylistMode.single,
                                          PlaylistMode.single =>
                                            PlaylistMode.none,
                                          PlaylistMode.none =>
                                            PlaylistMode.loop,
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: ZenithTooltip(
                                    message: smartShuffle
                                        ? context.l10n.smart_shuffle
                                        : shuffled
                                            ? context.l10n.unshuffle_playlist
                                            : context.l10n.shuffle_playlist,
                                    child: IconButton.ghost(
                                      shape: ButtonShape.circle,
                                      icon: Icon(
                                        smartShuffle
                                            ? SonolythIcons.lightning
                                            : SonolythIcons.shuffle,
                                        size:
                                            ZenithPlayerMetrics.subAAGlyphSize,
                                        color: shuffleActive
                                            ? activeGlyph
                                            : mutedGlyph,
                                      ),
                                      onPressed: () => cycleShuffleMode(ref),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: ZenithPlayerMetrics.subAAToTransportGap,
                      ),

                      // ---- 5. Transport: Proxima's pro-button outlines ---------
                      // `probuttons_icon_stroke`, as the Zenith screenshot runs
                      // it, with the multipurpose dots at either end — Poweramp's
                      // ±10s seek — dim at `colorIconDisabled`.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _ProButton(
                            glyphSize: ZenithPlayerMetrics.dotSize,
                            tooltip: context.l10n.seek_back_10s,
                            onPressed: () => audioPlayer.seek(
                              position - ZenithPlayerMetrics.skipStep <
                                      Duration.zero
                                  ? Duration.zero
                                  : position - ZenithPlayerMetrics.skipStep,
                            ),
                            child: ZenithProDot(
                              size: ZenithPlayerMetrics.dotSize,
                              color: mutedGlyph,
                            ),
                          ),
                          SizedBox(width: ZenithPlayerMetrics.laidOutDotGap),
                          _ProButton(
                            glyphSize: ZenithPlayerMetrics.prevNextSize,
                            tooltip: context.l10n.previous_track,
                            onPressed: audioPlayer.skipToPrevious,
                            child: const ZenithProIcon(
                              ZenithProGlyph.prev,
                              size: ZenithPlayerMetrics.prevNextSize,
                              outlined: true,
                            ),
                          ),
                          SizedBox(
                              width:
                                  ZenithPlayerMetrics.laidOutTransportGap),
                          _ProButton(
                            // Deferred, this is the verify action and says so
                            // — the glyph stays a play triangle because the
                            // player genuinely is not playing (item 65).
                            glyphSize: ZenithPlayerMetrics.playSize,
                            tooltip: playActionLabel(
                              context,
                              playing: playing,
                              deferred: deferred,
                            ),
                            onPressed: () => playing
                                ? audioPlayer.pause()
                                : playOrVerify(context, ref),
                            child: isFetchingActiveTrack
                                ? const SizedBox.square(
                                    dimension: ZenithPlayerMetrics.playSize,
                                    child: Center(
                                      child:
                                          CircularProgressIndicator(size: 24),
                                    ),
                                  )
                                : ZenithProIcon(
                                    playing
                                        ? ZenithProGlyph.pause
                                        : ZenithProGlyph.play,
                                    size: ZenithPlayerMetrics.playSize,
                                    outlined: true,
                                  ),
                          ),
                          SizedBox(
                              width:
                                  ZenithPlayerMetrics.laidOutTransportGap),
                          _ProButton(
                            glyphSize: ZenithPlayerMetrics.prevNextSize,
                            tooltip: context.l10n.next_track,
                            onPressed: audioPlayer.skipToNext,
                            child: const ZenithProIcon(
                              ZenithProGlyph.next,
                              size: ZenithPlayerMetrics.prevNextSize,
                              outlined: true,
                            ),
                          ),
                          SizedBox(width: ZenithPlayerMetrics.laidOutDotGap),
                          _ProButton(
                            glyphSize: ZenithPlayerMetrics.dotSize,
                            tooltip: context.l10n.seek_forward_10s,
                            onPressed: () => audioPlayer.seek(
                              position + ZenithPlayerMetrics.skipStep > duration
                                  ? duration
                                  : position + ZenithPlayerMetrics.skipStep,
                            ),
                            child: ZenithProDot(
                              size: ZenithPlayerMetrics.dotSize,
                              color: mutedGlyph,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                return SingleChildScrollView(
                  controller: scrollController,
                  child: anchored
                      ? SizedBox(height: constraints.maxHeight, child: body)
                      : body,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// `Zenith_ItemLikeUnlikeLayout_scene_aa`: the like control centred on the
/// art's bottom edge, on `rating_bg` — `colorAABgColor_60` tinted `src_atop`
/// with `colorBgPrimary`, i.e. the page colour at 60% — at radius 30, scaled
/// 0.75.
class _HeartPill extends StatelessWidget {
  const _HeartPill({required this.track});

  final SonolythTrackObject track;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // `container: true` is load-bearing. The pill sits inside the art's
    // horizontal-drag `GestureDetector`, and neither that nor the heart's own
    // annotation is a semantics *boundary* — so they merged, and the
    // accessibility tree carried one 344 x 307dp node labelled "Save as
    // favorite" over the whole artwork. Forcing a node here keeps the heart's
    // name and tap on the pill, and leaves the art with just its swipe.
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: zenithBgPrimary(colorScheme).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Transform.scale(
            scale: 0.75,
            child: TrackHeartButton(track: track),
          ),
        ),
      ),
    );
  }
}

/// One of the two small ringed glyph buttons on the title line
/// (`meta_info_button`, scale 0.75, `NeutralColor` glyph).
class _RingButton extends StatelessWidget {
  const _RingButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ZenithTooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: ZenithPlayerMetrics.ringButtonSize,
        child: IconButton(
          variance: zenithRingButtonStyle(colorScheme),
          icon: Icon(
            icon,
            size: ZenithPlayerMetrics.ringGlyphSize,
            color: colorScheme.foreground,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// A transport button: the glyph alone, `animOnClick` press feedback, a
/// generous square hit area. No ripple and no disc — `ProButtonsShape*` are
/// transparent in `@style/proxima`.
class _ProButton extends StatelessWidget {
  const _ProButton({
    required this.child,
    required this.glyphSize,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget child;

  /// The size of the glyph [child] draws, so the box can be grown to
  /// [kMinTapTarget] around it without the widget having to measure anything.
  final double glyphSize;

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ZenithTooltip(
      message: tooltip,
      child: ZenithPressable(
        onPressed: onPressed,
        // Centred, not padded: past [kMinTapTarget] the box is no longer
        // "the glyph plus 8dp", and a Padding would have pushed the glyph
        // off its measured centre instead of growing around it.
        child: SizedBox.square(
          dimension: ZenithPlayerMetrics.proButtonBox(glyphSize),
          child: Center(child: child),
        ),
      ),
    );
  }
}
