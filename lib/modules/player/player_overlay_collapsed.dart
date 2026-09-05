import 'dart:math';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/player/play_or_verify.dart';
import 'package:sonolyth/modules/player/player_overlay.dart';
import 'package:sonolyth/modules/root/sonolyth_navigation_bar.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/querying_track_info.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

/// Proxima's mini player — `item_miniplayer.xml` under `@style/proxima`.
///
/// In Poweramp the mini player is the top row of the **navbar panel**
/// (`scene_navbar_3lines`: mini row, `navbar_seekbar`, nav buttons), not a bar
/// of its own, and Proxima restyles that row three ways that together are the
/// look in the skin's screenshots:
///
/// * `ItemMiniplayerAAImage` is `fill_parent` with −50dp side margins and
///   `centerCrop`, under `MiniplayerOverlay` — the **album art is the row's
///   background**, bled past the edges and dimmed by a black gradient
///   (`colorAABgColor_90 → _80 → _70`, bottom to top);
/// * `ItemMiniplayerPlayButton` moves to the **left** (`left|center`, 40dp,
///   10dp in) and draws `mini_play` / `mini_pause` — a ring with the glyph
///   outlined inside it;
/// * the title is **bold** at `ColorTrackTitle`, line 2 at `ColorTrackLine`,
///   both starting at `MiniplayerTitleLineMarginLeft` 64dp.
///
/// There are no transport buttons on the row: Poweramp changes track with a
/// horizontal swipe here (`ItemMiniplayerPrevNextDecor`), and that swipe is
/// wired the same way. Tap opens the player; drag down dismisses playback,
/// as before.
///
/// The row is `NavbarList`'s 55dp and only rounds its **top** corners
/// (`miniplayer_rounded_mini`): its bottom edge meets the seek line and the nav
/// buttons in `SonolythNavigationBar`, which round the bottom.
abstract final class ZenithMiniPlayerMetrics {
  /// `NavbarList` `layout_height` in `@style/proxima`.
  static const height = 55.0;

  /// `ItemMiniplayerTitle` / `ItemMiniplayerLine2`, the two lines the row has
  /// to hold.
  static const titleSize = 15.0;
  static const line2Size = 13.0;

  /// [height] for a viewer on Android's default font size, and as much more as
  /// the two lines actually need for one who has turned it up.
  ///
  /// At 200% the artist line was clipped mid-glyph on every screen in the app,
  /// because this row is the navbar panel's measured 55dp and the text inside
  /// it is not (§37). The panel is taller for that viewer; nobody else sees a
  /// changed navbar.
  static double heightOf(BuildContext context) =>
      height +
      zenithLineGrowth(
        context,
        const TextStyle(fontSize: titleSize, fontWeight: FontWeight.w700),
      ) +
      zenithLineGrowth(context, const TextStyle(fontSize: line2Size));

  /// `ItemMiniplayerPlayButton`: 40dp, `layout_marginStart` 10.
  static const playButtonSize = 40.0;
  static const playButtonInset = 10.0;

  /// The box the play button is laid out in — the drawn 40dp control, or
  /// Android's [kMinTapTarget], whichever is larger (CONTEXT item 42).
  ///
  /// It is free here: `MiniplayerTitleLineMarginLeft` puts the title 64dp in
  /// and the drawn button ends at 50dp, so the 8dp the box gains comes out of
  /// **14dp of nothing**. [playTapInset] and [playTapToText] give exactly that
  /// back, so the glyph's centre stays where the picture put it and the title
  /// does not move a pixel.
  static double get playTapBox => max(playButtonSize, kMinTapTarget);

  /// [playButtonInset], less what [playTapBox] took at its left edge.
  static double get playTapInset =>
      playButtonInset - (playTapBox - playButtonSize) / 2;

  /// What is left between the tap box and the title line.
  static double get playTapToText => textInsetLeft - playTapInset - playTapBox;

  /// `mini_play` is drawn at its 24dp viewport inside the 40dp button.
  static const playGlyphSize = 24.0;

  /// `MiniplayerTitleLineMarginLeft` / `MiniplayerTitleLineMarginRight`.
  static const textInsetLeft = 64.0;
  static const textInsetRight = 10.0;

  /// `ItemMiniplayerAAImage` margins are −50dp each side: the art is cropped
  /// wider than the row, so its centre stays put while the row is narrower
  /// than the cover.
  static const artBleed = 50.0;

  /// `MiniplayerOverlay` — `colorAABgColor_90/_80/_70`, angle 90 (bottom up).
  static const overlayBottom = Color(0xE6000000);
  static const overlayMiddle = Color(0xCC000000);
  static const overlayTop = Color(0xB3000000);

  /// How far a drag must travel (dp) or how fast it must fling (dp/s) before
  /// it counts as dismiss or as a track change.
  static const dismissDistance = 45.0;
  static const dismissVelocity = 250.0;
  static const skipDistance = 60.0;
  static const skipVelocity = 300.0;
}

class PlayerOverlayCollapsedSection extends HookConsumerWidget {
  final PanelController panelController;
  const PlayerOverlayCollapsedSection({
    super.key,
    required this.panelController,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final track = playlist.activeTrack;
    final canShow = track != null;
    final colorScheme = Theme.of(context).colorScheme;

    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    // The queue is being held out of mpv, so there is nothing to resume and
    // play means verify — the same as on the full player (item 65).
    final deferred = ref.watch(playbackDeferredProvider);

    // Swipe-down dismissal: the row follows the finger, fading as it goes;
    // past the threshold it slides out and playback stops.
    final dragY = useState<double>(0);
    final draggingY = useState(false);

    // Horizontal swipe: the row's content follows the finger and a committed
    // swipe changes track, the way Poweramp's mini player does.
    final dragX = useState<double>(0);
    final draggingX = useState(false);

    final albumArt = useMemoized(
      () => (track?.album.images).asUrlString(
        placeholder: ImagePlaceholder.albumArt,
      ),
      [track?.album.images],
    );

    // Only the arrival / departure of a track is animated here. Fading the
    // row out as the player opens is the panel's job — it is the `collapsed`
    // slot, which the package cross-fades against the panel across the whole
    // travel. Hiding it here as well (on a threshold) is what made it
    // disappear in one frame halfway up.
    return AnimatedSwitcher(
      duration: ZenithMotion.scene,
      switchInCurve: ZenithMotion.fadeCurve,
      switchOutCurve: ZenithMotion.fadeCurve,
      child: canShow
          ? GestureDetector(
              onTap: () => panelController.openScene(),
              onVerticalDragStart: (_) => draggingY.value = true,
              onVerticalDragUpdate: (details) {
                dragY.value = (dragY.value + details.delta.dy)
                    .clamp(0.0, 90.0)
                    .toDouble();
              },
              onVerticalDragCancel: () {
                draggingY.value = false;
                dragY.value = 0;
              },
              onVerticalDragEnd: (details) async {
                final velocity = details.primaryVelocity ?? 0;
                draggingY.value = false;
                if (velocity > ZenithMiniPlayerMetrics.dismissVelocity ||
                    dragY.value > ZenithMiniPlayerMetrics.dismissDistance) {
                  // Finish the slide before stopping so the row visibly
                  // leaves instead of vanishing in place.
                  dragY.value = 90;
                  await Future.delayed(ZenithMotion.fade);
                  await ref.read(audioPlayerProvider.notifier).stop();
                  dragY.value = 0;
                } else {
                  dragY.value = 0;
                  if (velocity < -ZenithMiniPlayerMetrics.dismissVelocity) {
                    panelController.openScene();
                  }
                }
              },
              onHorizontalDragStart: (_) => draggingX.value = true,
              onHorizontalDragUpdate: (details) {
                dragX.value = (dragX.value + details.delta.dx)
                    .clamp(-120.0, 120.0)
                    .toDouble();
              },
              onHorizontalDragCancel: () {
                draggingX.value = false;
                dragX.value = 0;
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                final offset = dragX.value;
                draggingX.value = false;
                dragX.value = 0;
                if (offset < -ZenithMiniPlayerMetrics.skipDistance ||
                    velocity < -ZenithMiniPlayerMetrics.skipVelocity) {
                  audioPlayer.skipToNext();
                } else if (offset > ZenithMiniPlayerMetrics.skipDistance ||
                    velocity > ZenithMiniPlayerMetrics.skipVelocity) {
                  audioPlayer.skipToPrevious();
                }
              },
              child: ClipRect(
                child: AnimatedSlide(
                  offset: Offset(0,
                      dragY.value / ZenithMiniPlayerMetrics.heightOf(context)),
                  duration: draggingY.value ? Duration.zero : ZenithMotion.fade,
                  curve: ZenithMotion.slideCurve,
                  child: AnimatedOpacity(
                    opacity: 1 - (dragY.value / 90) * 0.7,
                    duration:
                        draggingY.value ? Duration.zero : ZenithMotion.fade,
                    curve: ZenithMotion.fadeCurve,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZenithNavBarMetrics.marginHorizontal,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(
                            ZenithNavBarMetrics.cornerRadius,
                          ),
                        ),
                        child: SizedBox(
                          height: ZenithMiniPlayerMetrics.heightOf(context),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // The art, bled 50dp past each side and cropped.
                              Positioned(
                                left: -ZenithMiniPlayerMetrics.artBleed,
                                right: -ZenithMiniPlayerMetrics.artBleed,
                                top: 0,
                                bottom: 0,
                                child: AnimatedSwitcher(
                                  // `aa_fade_in`, like the player's art.
                                  duration: ZenithMotion.artFadeIn,
                                  transitionBuilder: zenithArtTransition,
                                  // `SizedBox.expand`: the switcher lays its
                                  // child out loosely, and left alone the image
                                  // sat at its own size in the middle of the
                                  // row instead of covering it.
                                  child: SizedBox.expand(
                                    key: ValueKey(albumArt),
                                    child: UniversalImage(
                                      path: albumArt,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      ZenithMiniPlayerMetrics.overlayBottom,
                                      ZenithMiniPlayerMetrics.overlayMiddle,
                                      ZenithMiniPlayerMetrics.overlayTop,
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedSlide(
                                offset: Offset(dragX.value / 400, 0),
                                duration: draggingX.value
                                    ? Duration.zero
                                    : ZenithMotion.fade,
                                curve: ZenithMotion.slideCurve,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: ZenithMiniPlayerMetrics
                                          .playTapInset,
                                    ),
                                    Semantics(
                                      button: true,
                                      label: playActionLabel(
                                        context,
                                        playing: playing,
                                        deferred: deferred,
                                      ),
                                      child: ZenithPressable(
                                        onPressed: () => playing
                                            ? audioPlayer.pause()
                                            : playOrVerify(context, ref),
                                        child: SizedBox.square(
                                          dimension: ZenithMiniPlayerMetrics
                                              .playTapBox,
                                          child: Center(
                                            child: isFetchingActiveTrack
                                                ? const CircularProgressIndicator(
                                                    size: 20,
                                                  )
                                                : ZenithMiniPlayIcon(
                                                    playing: playing,
                                                    size:
                                                        ZenithMiniPlayerMetrics
                                                            .playGlyphSize,
                                                    color:
                                                        colorScheme.foreground,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: ZenithMiniPlayerMetrics
                                          .playTapToText,
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: ZenithMiniPlayerMetrics
                                                  .titleSize,
                                              fontWeight: FontWeight.w700,
                                              color: colorScheme.foreground,
                                            ),
                                          ),
                                          if (track.artists.isNotEmpty)
                                            Text(
                                              track.artists.asString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize:
                                                    ZenithMiniPlayerMetrics
                                                        .line2Size,
                                                color:
                                                    colorScheme.mutedForeground,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: ZenithMiniPlayerMetrics
                                          .textInsetRight,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
