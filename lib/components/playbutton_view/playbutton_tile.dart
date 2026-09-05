import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/hover_builder.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/ui/zenith_playing_mark.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart'
    show ZenithTrackRowMetrics;
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/string.dart';

/// The list-mode counterpart of `PlaybuttonCard`.
///
/// This is the *same* skin scene as a track row — `ItemTrack*` with no
/// `_scene_*` suffix — so it takes its geometry and type straight from
/// [ZenithTrackRowMetrics] rather than defining a parallel set that could drift.
/// An album in list mode and a track in the list below it must line up.
class PlaybuttonTile extends StatelessWidget {
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

  const PlaybuttonTile({
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
    final artExtent = ZenithTrackRowMetrics.artSize * scale;

    // Raised exactly as `ItemTrackAAImage` is on a track row
    // (`list_aa_elevation` 10dp); `corners_aa_albums` is 0dp in the defaults,
    // rounded in the skin's screenshots — [ZenithArt.radius].
    final artwork = Container(
      width: artExtent,
      height: artExtent,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZenithArt.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: ZenithTrackRowMetrics.artElevation,
            offset: const Offset(0, 3),
          ),
        ],
        image: imageUrl != null
            ? DecorationImage(
                image: UniversalImage.imageProvider(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl != null ? null : image,
    );

    return HoverBuilder(
      builder: (context, isHovering) {
        // Hover only, plus the playing/loading state — the same rule as the
        // grid card. Proxima has no per-row play or queue button: the row is
        // the target, and `ItemTrack` carries nothing on its right but the meta
        // text and the "⋯" menu. So on a phone the two buttons never appear,
        // and on desktop they fade in under the pointer. The play button stays
        // while the row is playing or loading, so it doubles as the control
        // for the thing already happening — exactly as on the card.
        // As on the card: with neither action wired (an artist tile) there
        // is nothing to reveal, so nothing fades in.
        final hasControls =
            onPlaybuttonPressed != null || onAddToQueuePressed != null;
        final revealed = hasControls && (isHovering || isPlaying || isLoading);

        return Stack(
          children: [
            // `ItemTrackPlayingMark`: the row is marked, the title is not
            // recoloured — the same mark a playing track row carries.
            if (isPlaying) const ZenithPlayingMark(),
            GestureDetector(
              onLongPress: onLongPress,
              child: Button(
                leading: artwork,
                style: ButtonVariance.ghost.copyWith(
                  padding: (context, states, value) {
                    return (ButtonVariance.ghost.padding(context, states)
                            as EdgeInsets)
                        .copyWith(right: 0, left: 0);
                  },
                ),
                trailing: ZenithReveal(
                  visible: revealed,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onAddToQueuePressed != null)
                        ZenithTooltip(
                          message: context.l10n.add_to_queue,
                          // `ItemHeader*Button` in `@style/proxima` has a
                          // transparent background: a bare glyph, no outline
                          // and no fill.
                          child: IconButton.ghost(
                            shape: ButtonShape.circle,
                            icon: const Icon(SonolythIcons.queueAdd),
                            onPressed: onAddToQueuePressed,
                            enabled: !isLoading,
                          ),
                        ),
                      if (onPlaybuttonPressed != null)
                        ZenithTooltip(
                          message: context.l10n.play,
                          child: IconButton.ghost(
                            shape: ButtonShape.circle,
                            icon: switch ((isLoading, isPlaying)) {
                              (true, _) =>
                                const CircularProgressIndicator(size: 22),
                              (false, false) => const Icon(SonolythIcons.play),
                              (false, true) => const Icon(SonolythIcons.pause)
                            },
                            onPressed: onPlaybuttonPressed,
                            enabled: !isLoading,
                          ),
                        ),
                    ],
                  ),
                ),
                enabled: !isLoading,
                onPressed: onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // `ItemTrackTitle_Text` 16.5dp bold ×
                      // `ItemTrackTitle_scale` 0.9.
                      style: TextStyle(
                        fontSize: ZenithTrackRowMetrics.titleSize,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    if (cleanDescription.isNotEmpty)
                      Text(
                        cleanDescription,
                        // `ItemTrackLine2` is `android:maxLines="1"`.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ZenithTrackRowMetrics.line2Size,
                          // `ColorTrackLine` — 60%.
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
