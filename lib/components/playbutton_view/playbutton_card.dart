import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/string.dart';

/// Grid-card geometry and type, read out of the skin's **zoomed** grid scene
/// (`ItemTrack*_scene_grid_zoomed`).
///
/// The zoomed scene is the right reference, not the plain `_scene_grid` one:
/// Poweramp has two grid densities, and the dense one scales its labels by 0.65
/// while the zoomed one scales by 0.9 — the same 0.9 the list rows use. Our
/// cards are 150dp wide with two or three to a phone screen, i.e. the zoomed
/// grid, so a card title and a track-row title come out the same size, which is
/// what makes the two surfaces read as one system.
///
/// On corners the defaults and the pictures disagree, and the pictures win:
/// every `corners_aa_*` in `@style/proxima` is `0.0dip` (`_grid_zoomed`
/// variants included), but the skin's own screenshots show rounded art, so
/// the card draws at [ZenithArt.radius] like every other art in the app
/// (§27). The dead `artRadius = 0.0` that recorded the default was removed in
/// §34 — it had not been read since.
abstract final class ZenithCardMetrics {
  /// `grid_aa_elevation` in `@style/proxima`. Same value as the list
  /// thumbnail's `list_aa_elevation`, and rendered the same way.
  static const artElevation = 10.0;

  /// `ItemTrackAAImage_scene_grid` insets the art 8dp on every side.
  ///
  /// This margin **is** the grid's gutter — the sliver delegate's cross/main
  /// axis spacing and the rail's separator are both 0, so that two adjacent
  /// cells are separated by their own two 8dp margins and nothing else, exactly
  /// as they are in the skin.
  static const artInset = 8.0;

  /// `ItemTrackTitle_scene_grid_zoomed` / `ItemTrackLine2_scene_grid_zoomed`
  /// `layout_marginLeft` and `layout_marginRight`, from the cell edge — so the
  /// labels sit 13dp further in than the artwork does.
  static const labelInset = 21.0;

  /// `ItemTrackTitle_Text` 16.5dp bold × `ItemTrackTitle_scene_grid_zoomed_scale`
  /// (0.9) — identical to a track row's title.
  static const titleSize = 15.0;

  /// `ItemTrackLine2_Text` 14.5dp × the same 0.9.
  static const line2Size = 13.0;

  /// `ItemTrackLine2_scene_grid_zoomed` `layout_marginTop`.
  static const labelGap = 1.0;

  /// `ItemTrackLine2_scene_grid_zoomed` `layout_marginBottom`.
  static const labelBottom = 11.0;

  /// The cell's height at the system default font size: the 150dp art block
  /// plus the two label lines and their margins, measured off the skin's grid.
  ///
  /// One number for the grid delegate's `mainAxisExtent` and for the rail's
  /// box, so a card is the same height wherever it appears.
  static const baseExtent = 225.0;

  /// [baseExtent] for a viewer who has not touched Android's font size, and
  /// exactly as much more as the two label lines need for one who has.
  ///
  /// The cell height cannot come from the card itself — a sliver delegate and
  /// a horizontal rail both have to state it up front — so at 200% text the
  /// label column simply overflowed its cell and the description was clipped
  /// under a yellow bar on every grid and rail in the app. Growing by the
  /// measured line growth (see [zenithLineGrowth]) leaves the skin's 225dp
  /// untouched at the default scale.
  static double extent(BuildContext context) {
    final scale = context.theme.scaling;
    return (baseExtent * scale) +
        zenithLineGrowth(
          context,
          const TextStyle(fontSize: titleSize, fontWeight: FontWeight.w700),
        ) +
        zenithLineGrowth(context, const TextStyle(fontSize: line2Size));
  }
}

class PlaybuttonCard extends StatelessWidget {
  final void Function()? onTap;
  final void Function()? onPlaybuttonPressed;
  final void Function()? onAddToQueuePressed;

  /// The item's context menu — see `ZenithPressable.onLongPress`.
  final void Function()? onLongPress;
  final String? description;

  final String? imageUrl;
  final Widget? image;
  final bool isPlaying;
  final bool isLoading;
  final String title;
  final bool isOwner;

  const PlaybuttonCard({
    required this.isPlaying,
    required this.isLoading,
    required this.title,
    this.description,
    this.onPlaybuttonPressed,
    this.onAddToQueuePressed,
    this.onTap,
    this.onLongPress,
    this.isOwner = false,
    this.imageUrl,
    this.image,
    super.key,
  }) : assert(
          imageUrl != null || image != null,
          "imageUrl and image can't be null at the same time",
        );

  @override
  Widget build(BuildContext context) {
    final cleanDescription = description?.unescapeHtml().cleanHtml() ?? "";
    final theme = context.theme;
    final scale = theme.scaling;
    final colorScheme = theme.colorScheme;
    // `layout_matchDimension="heightToWidth"` — the art is square, and it is
    // the cell less its own 8dp margins.
    final artExtent = (150 * scale) - (ZenithCardMetrics.artInset * 2);

    const shadow = BoxShadow(
      color: Color(0x78000000),
      blurRadius: ZenithCardMetrics.artElevation,
      offset: Offset(0, 3),
    );

    // One node for the whole cell: "Title, description", announced as a
    // button. The label column below is excluded so its two lines are not read
    // a second time as separate stops, while the hover overlay's play and
    // queue buttons keep their own nodes.
    return Semantics(
      button: true,
      label: [
        title,
        if (cleanDescription.isNotEmpty) cleanDescription,
      ].join(', '),
      child: ZenithPressable(
        onPressed: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 150 * scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(ZenithCardMetrics.artInset),
                child: SizedBox(
                  width: artExtent,
                  height: artExtent,
                  child: Stack(
                    children: [
                      Container(
                        width: artExtent,
                        height: artExtent,
                        decoration: BoxDecoration(
                          // Rounded per the skin's screenshots; see
                          // [ZenithArt.radius].
                          borderRadius: BorderRadius.circular(ZenithArt.radius),
                          boxShadow: const [shadow],
                          image: imageUrl != null
                              ? DecorationImage(
                                  image: UniversalImage.imageProvider(
                                    imageUrl!,
                                    height: 200 * scale,
                                    width: 200 * scale,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl != null ? null : image,
                      ),
                      StatedWidget.builder(
                        builder: (context, states) {
                          // Hover only — NOT `|| kIsMobile`. Proxima has no
                          // per-item play button: the item is the target and the
                          // artwork is meant to be seen, which is the same call
                          // `track_tile.dart` made about its own hover overlay.
                          // Both actions stay reachable on a phone through the
                          // page the card opens.
                          // An item with no play or queue action of its own
                          // (an artist card — Poweramp's artist cell has no
                          // transport either) gets no overlay at all, rather
                          // than two disabled buttons fading in under the
                          // pointer.
                          final revealed = states.contains(WidgetState.hovered);
                          return Positioned(
                            right: ZenithCardMetrics.artInset,
                            bottom: ZenithCardMetrics.artInset,
                            child: Column(
                              children: [
                                // Proxima has no bounce anywhere — the overlay
                                // controls fade, they do not spring in. Reveals go
                                // to 0 rather than to `ZenithMotion.fadeFloor`,
                                // which is for cross-fades: a button held at 10%
                                // over artwork still reads as a button and is
                                // still hit-testable.
                                ZenithReveal(
                                  visible: revealed &&
                                      !isLoading &&
                                      onAddToQueuePressed != null,
                                  child: ZenithTooltip(
                                    message: context.l10n.add_to_queue,
                                    child: IconButton.secondary(
                                      icon: const Icon(SonolythIcons.queueAdd),
                                      onPressed: onAddToQueuePressed,
                                      size: ButtonSize.small,
                                    ),
                                  ),
                                ),
                                const Gap(5),
                                ZenithReveal(
                                  visible: onPlaybuttonPressed != null &&
                                      (revealed || isPlaying || isLoading),
                                  child: ZenithTooltip(
                                    message: isPlaying
                                        ? context.l10n.pause
                                        : context.l10n.play,
                                    child: IconButton.secondary(
                                      icon: switch ((isLoading, isPlaying)) {
                                        (true, _) =>
                                          const CircularProgressIndicator(
                                              size: 15),
                                        (false, false) =>
                                          const Icon(SonolythIcons.play),
                                        (false, true) =>
                                          const Icon(SonolythIcons.pause)
                                      },
                                      enabled: !isLoading,
                                      onPressed: onPlaybuttonPressed,
                                      size: ButtonSize.small,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (isOwner)
                        const Positioned(
                          right: 5,
                          top: 5,
                          child: SecondaryBadge(
                            style: ButtonStyle.secondaryIcon(
                              shape: ButtonShape.circle,
                              size: ButtonSize.small,
                            ),
                            child: Icon(SonolythIcons.user),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZenithCardMetrics.labelInset,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ZenithTooltip.plain(
                        message: title,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ZenithCardMetrics.titleSize,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                      // `ItemTrackLine2` is `layout_goneWhenEmpty="true"` and
                      // `layout_applyMarginsForGone="true"` — with no line 2 the
                      // view and its margins both collapse, so a card with no
                      // description is genuinely shorter. No blank placeholder line.
                      if (cleanDescription.isNotEmpty) ...[
                        const Gap(ZenithCardMetrics.labelGap),
                        Text(
                          cleanDescription,
                          // `android:maxLines="1"`.
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ZenithCardMetrics.line2Size,
                            // `ColorTrackLine` — 60%.
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                      const Gap(ZenithCardMetrics.labelBottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
