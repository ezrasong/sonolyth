import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart'
    show ZenithTrackRowMetrics;

/// A stats list row: artwork, a title, a line 2, and the figure that put the
/// item in the list.
///
/// The four `Stats*Item` widgets were the last rows in the app still built out
/// of shadcn's `ButtonTile`, i.e. out of `Basic`'s own typography — a 40dp
/// thumbnail at radius 4 beside a `typography.small` title, and for artists a
/// Material `Avatar` circle. No Zenith pass reached them because no Zenith
/// pass could reach the screens (§38d gave Stats its first phone entry point).
/// They are the same skin scene as every other list row, so like
/// `PlaybuttonTile` they take their geometry and type from
/// [ZenithTrackRowMetrics] rather than restating it.
///
/// **The figure is `ItemTrackNum`, not the meta line.** The skin's own style
/// for a number on a track row is 14.5dp x the 0.9 list scale at
/// `colorTrackNum` — `#ff999999`, which Proxima does not override — so it
/// grades with line 2 at 60%, not with the 50% `ItemTrackMeta` run. It is the
/// content of these lists, not metadata about the row.
///
/// **Artists are square here too.** §34a took the circular `Avatar` off the
/// artist card when it became a `PlaybuttonCard`; a circle on a stats row
/// would have been the last one left.
class StatsRow extends StatelessWidget {
  const StatsRow({
    super.key,
    required this.title,
    required this.info,
    this.imageUrl,
    this.subtitle,
    this.onPressed,
  });

  final String title;

  /// The figure — "12 plays", "340 mins", "$0.05".
  final Widget info;

  final String? imageUrl;

  /// Line 2: the artists, the album type, a playlist's description. Given as a
  /// widget because `ArtistLink` is a link row, not a string.
  final Widget? subtitle;

  final VoidCallback? onPressed;

  /// `ItemTrackNum_Text` 14.5dip x the 0.9 list scale, i.e. the same size as
  /// line 2.
  static const infoSize = ZenithTrackRowMetrics.line2Size;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final artExtent = ZenithTrackRowMetrics.artSize * theme.scaling;

    // `ItemTrackAAImage` as `PlaybuttonTile` draws it: raised by
    // `list_aa_elevation` and rounded to [ZenithArt.radius]. Painted as a
    // `DecorationImage` so the artwork adds no stop of its own to the
    // accessibility tree (§36c) — the title beside it is the row's name.
    final artwork = Container(
      width: artExtent,
      height: artExtent,
      decoration: BoxDecoration(
        color: zenithArtWell(colorScheme),
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
    );

    return Button(
      leading: artwork,
      // The ghost button's own horizontal inset is kept, unlike
      // `PlaybuttonTile`, which zeroes it because `PlaybuttonView` supplies the
      // padding around it. Nothing pads these lists, so zeroing it put the
      // artwork flush against the screen edge — and 16dp is the inset
      // `TrackTile` gives a row on a phone anyway.
      style: ButtonVariance.ghost,
      trailing: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: infoSize,
          fontWeight: FontWeight.w400,
          // `colorTrackNum` #ff999999 — 60%, which is `mutedForeground`.
          color: colorScheme.mutedForeground,
        ),
        maxLines: 1,
        child: info,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // `ItemTrackTitle_Text` 16.5dp bold x `ItemTrackTitle_scale` 0.9.
            style: TextStyle(
              fontSize: ZenithTrackRowMetrics.titleSize,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          if (subtitle != null)
            DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: ZenithTrackRowMetrics.line2Size,
                // `ColorTrackLine` — 60%.
                color: colorScheme.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: subtitle!,
            ),
        ],
      ),
    );
  }
}
