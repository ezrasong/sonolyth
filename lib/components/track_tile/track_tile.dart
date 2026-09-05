import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/hover_builder.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/links/artist_link.dart';
import 'package:sonolyth/components/links/link_text.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_tile/track_options_button.dart';
import 'package:sonolyth/components/ui/button_tile.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/duration.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/querying_track_info.dart';
import 'package:sonolyth/provider/audio_player/state.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/provider/blacklist_provider.dart';
import 'package:sonolyth/provider/downloaded_tracks_provider.dart';
import 'package:sonolyth/provider/server/track_format_registry.dart';

/// Track-row geometry and type, read out of the Proxima skin's list styles
/// (`ItemTrack*` in `res/values/styles.xml`, resolved against the Poweramp base
/// styles the skin inherits from) rather than chosen to look about right.
///
/// The two things that make a row read as Zenith rather than as generic
/// Material are easy to lose, so they are called out:
///
/// 1. **The thumbnail is square.** `corners_aa_tracks` is `0.0dip` in
///    `@style/proxima`. A rounded thumbnail is the single most obvious tell.
/// 2. **The playing row is marked by an outline, not by a coloured title.**
///    Poweramp tints the active title with `colorItemActive`, but Proxima sets
///    that to opaque black — i.e. it deliberately opts out — and marks the row
///    with the `ItemTrackPlayingMark` view instead.
abstract final class ZenithTrackRowMetrics {
  /// `ItemTrackAAImage` insets the art 8dp top and bottom of a row and matches
  /// width to height, so the thumbnail is the row height less 16. A row with a
  /// title and line 2 only is `abc_list_item_height_material` (64dp) → 48dp
  /// art; album, playlist and folder rows (`PlaybuttonTile`) are that row.
  static const artSize = 48.0;

  /// A track row is `ListSubstyleBase2`'s `itemSize` — **96dp** — and the art,
  /// `fill_parent` less the 8dp insets top and bottom, is 80dp. That is the
  /// row in the skin's own store screenshots, and why the pictures' rows look
  /// nothing like a 64dp Material row: three text lines (title, line 2, the
  /// `ItemTrackMeta` "♪ 3:23 | flac | 24 bit") beside a large square. Proxima's
  /// default hides the meta line; the pictures show it, and the pictures win.
  static const artSizeWithMeta = 80.0;

  /// The picture's three text lines sit ~21dp apart: title → line 2 needs
  /// only the font metrics plus this, line 2 → meta a little more (the meta's
  /// `marginTop` 5dp on top of its own padding).
  static const titleToLine2 = 4.0;
  static const line2ToMeta = 6.0;

  /// `meta_song` is a 12dp vector (`ItemTrackMeta` `drawableHeight` 12dp),
  /// followed by a short gap before the text.
  static const metaGlyphSize = 12.0;
  static const metaGlyphGap = 5.0;

  /// `corners_aa_tracks` = `0.0dip`. Square, deliberately.
  static const artRadius = 0.0;

  /// `list_aa_elevation` — the list thumbnail is the one raised element in a
  /// row, the same way the cover is in the player.
  static const artElevation = 10.0;

  /// `ItemTrackTitle_Text` is 16.5dp bold, scaled by `ItemTrackTitle_scale`
  /// (0.9). Zenith sets the title apart by WEIGHT here, unlike the player,
  /// which sets it apart by size.
  static const titleSize = 15.0;

  /// `ItemTrackLine2_Text`, 14.5dp × the same 0.9 scale. Colour is
  /// `ColorTrackLine` (#99ffffff = 60%), which is `mutedForeground`.
  static const line2Size = 13.0;

  /// The most vertical space line 2 may take at the default font size — two
  /// lines of [line2Size], since `ArtistLink` wraps rather than ellipsizing.
  static const line2MaxHeight = 40.0;

  /// [line2MaxHeight] plus what its two lines actually grow by at the viewer's
  /// system font size.
  ///
  /// **Not** `textScaler.scale(line2MaxHeight)`, which is the trap this walked
  /// into once: Android 14's font scaling is non-linear, so scaling the 40dp
  /// *cap* grows it far less than it grows a 13sp line inside the cap, and the
  /// artist line stayed clipped mid-glyph at 200% (§37). The growth of the
  /// line is the only thing that predicts the height of the line.
  static double line2MaxHeightOf(BuildContext context) =>
      line2MaxHeight +
      2 * zenithLineGrowth(context, const TextStyle(fontSize: line2Size));

  /// `ItemTrackMeta_Text` — 11dp and **bold**, × `ItemTrackMeta_scale` 0.9
  /// (the same 0.9 the title and line 2 carry), at `colorTrackMeta` (50%).
  static const metaSize = 10.0;

  /// `ItemTrackPlayingMark` margins: left 4, top 1, right 14, bottom 1. The
  /// mark is inset; the row content is not.
  static const playingMarkInset = EdgeInsets.fromLTRB(4, 1, 14, 1);

  /// `SelectedTrackCorners`.
  static const playingMarkRadius = 15.0;
}

final isBlacklistedProvider =
    Provider.autoDispose.family<bool, SonolythTrackObject>(
  (ref, track) {
    ref.watch(blacklistProvider);
    final blacklist = ref.read(blacklistProvider.notifier);
    return blacklist.contains(track);
  },
);

final _overlay = ValueNotifier<OverlayCompleter<dynamic>?>(null);

class TrackTile extends HookConsumerWidget {
  /// [index] will not be shown if null
  final int? index;
  final SonolythTrackObject track;
  final bool selected;
  final bool selectionMode;
  final ValueChanged<bool?>? onChanged;
  final Future<void> Function()? onTap;
  final VoidCallback? onLongPress;
  final bool userPlaylist;
  final String? playlistId;
  final AudioPlayerState playlist;

  final List<Widget>? leadingActions;

  const TrackTile({
    super.key,
    this.index,
    required this.track,
    this.selected = false,
    this.selectionMode = false,
    required this.playlist,
    this.onTap,
    this.onLongPress,
    this.onChanged,
    this.userPlaylist = false,
    this.playlistId,
    this.leadingActions,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);

    // When this row is rendered inside a playlist/album, downloads from it
    // fold into that collection's subfolder. Captured here (under the
    // presentation's Data scope); the options menu renders in a detached
    // overlay where this lookup would miss, so it's threaded down explicitly.
    final collectionName = TrackPresentationOptions.maybeOf(context)?.title;

    final isBlackListed = ref.watch(isBlacklistedProvider(track));

    final isLoading = useState(false);

    final isPlaying = playlist.activeTrack?.id == track.id;
    // Whether audio is actually running — the active tile shows a pause
    // glyph only while playing and a play glyph while paused.
    final isAudioPlaying =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

    final isSelected = isPlaying || isLoading.value;
    // The download queue's per-row button was desktop-only and went with the
    // desktop platforms (§40), so the row no longer watches the queue at all —
    // it only needs the persistent registry, for the meta line's format.
    final downloadedPath = track is SonolythFullTrackObject
        ? ref.watch(
            downloadedTracksProvider.select((tracks) => tracks[track.id]),
          )
        : null;

    // `ItemTrackMeta`: "♪ 3:23 | flac | 24 bit". The format half comes from
    // the registry of streams resolved this session — never from a resolve
    // this row triggers — or, failing that, from the extension of a
    // downloaded or local file. A track nothing has resolved yet shows its
    // duration alone, which is all anyone actually knows about it.
    final format = ref.watch(
          trackFormatRegistryProvider.select((formats) => formats[track.id]),
        ) ??
        switch (track) {
          SonolythLocalTrackObject(:final path) => TrackFormat.fromPath(path),
          _ => downloadedPath == null
              ? null
              : TrackFormat.fromPath(downloadedPath),
        };
    final metaParts = <String>[
      Duration(milliseconds: track.durationMs)
          .toHumanReadableString(padZero: false),
      if (format != null) format.container,
      if (format?.bitDepth != null) "${format!.bitDepth} bit",
      // A blacklisted row used to be a red `ButtonVariance.destructive` slab —
      // the last shadcn accent left in a list, and the loudest thing on any
      // screen carrying one. `ArtistCard` settled the idiom in §34a: the state
      // is a word on the meta line, and the row is dimmed rather than painted.
      if (isBlackListed) context.l10n.blacklisted,
    ];

    final imageProvider = useMemoized(
      () => UniversalImage.imageProvider(
        (track.album.images).smallest(ImagePlaceholder.albumArt),
      ),
      [track.album.images],
    );

    // Treat either explicit selectionMode or presence of onChanged as selection
    // context. Some lists enable selection by providing `onChanged` without
    // toggling a dedicated `selectionMode` flag (e.g. playlists), so we must
    // disable inner navigation in both cases.
    final effectiveSelection = selectionMode || onChanged != null;

    // Proxima's three list-row text grades. Zenith separates them by weight and
    // by alpha step, never by hue.
    final titleStyle = TextStyle(
      fontSize: ZenithTrackRowMetrics.titleSize,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.foreground,
    );
    final line2Style = TextStyle(
      fontSize: ZenithTrackRowMetrics.line2Size,
      fontWeight: FontWeight.w400,
      color: theme.colorScheme.mutedForeground,
    );
    final metaStyle = TextStyle(
      fontSize: ZenithTrackRowMetrics.metaSize,
      fontWeight: FontWeight.w700,
      color: zenithTrackMeta(theme.colorScheme),
    );

    return LayoutBuilder(builder: (context, constrains) {
      return Listener(
        onPointerDown: (event) {
          if (event.buttons != kSecondaryMouseButton) return;
          if (_overlay.value != null) {
            _overlay.value?.remove();
            _overlay.value = null;
          }
          _overlay.value = TrackOptionsButton.showOptions(
            context,
            Offset.zero,
            track,
            userPlaylist: userPlaylist,
            playlistId: playlistId,
            collectionName: collectionName,
          );
        },
        child: HoverBuilder(
          // Only the active row keeps its artwork overlay open. `smAndDown`
          // used to force it on for every row, because touch has no hover — but
          // that put a black wash and a play glyph over every thumbnail, and
          // Proxima has no per-row play button at all: the row itself is the
          // target, and the artwork is meant to be seen. Desktop hover is
          // unaffected.
          permanentState: isSelected ? true : null,
          builder: (context, isHovering) => Stack(
            children: [
              // `ItemTrackPlayingMark` — Proxima marks the playing row with an
              // inset, rounded 1dp outline in white 50% (`SelectedTrackColor`)
              // over a wash, NOT by recolouring the title.
              //
              // The skin's `selected_track_color` gradient runs to that same
              // 50%, but the shape is also `src_atop`-tinted with a fully
              // transparent `SelectedTrackOverlay`, so what it composites to at
              // runtime is genuinely ambiguous. The wash below uses
              // `colorItemPlayingMark` (#15ffffff, 8%) instead — the skin's own
              // value for "this row is playing" — and leaves the outline exact.
              if (isSelected)
                Positioned.fill(
                  child: Padding(
                    padding: ZenithTrackRowMetrics.playingMarkInset,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          ZenithTrackRowMetrics.playingMarkRadius,
                        ),
                        border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(128),
                          width: 1,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.primary.withAlpha(0),
                            theme.colorScheme.primary.withAlpha(21),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // "This one is playing" is drawn by `ItemTrackPlayingMark` — an
              // outline and a wash, nothing a screen reader can see. Read off
              // the device, the playing row was `selected="false"` like every
              // other row, so the only way to know which track was playing
              // was to look at it (§37). `selected` is the flag a list uses
              // for its current item, it costs nothing visually, and it
              // follows the same `isSelected` the mark is painted from, so the
              // two can never disagree.
              //
              // `ButtonTile.selected` stays false: that paints shadcn's accent
              // fill, which Zenith does not have.
              Semantics(
                selected: isSelected,
                // Blacklisted rows read as unavailable rather than alarming:
                // the whole tile drops to 45%, which is what "you told the app
                // not to play this" looks like next to a row you can play. The
                // word itself is on the meta line (see `metaParts`).
                child: Opacity(
                  opacity: isBlackListed ? 0.45 : 1,
                  child: ButtonTile(
                    selected: false,
                    onPressed: () async {
                      if (isBlackListed) return;
                      try {
                        isLoading.value = true;
                        await onTap?.call();
                      } finally {
                        if (context.mounted) {
                          isLoading.value = false;
                        }
                      }
                    },
                    onLongPress: onLongPress,
                    style: ButtonVariance.ghost.copyWith(
                      padding: (context, states, value) =>
                          const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 0),
                    ),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...?leadingActions,
                        AnimatedCrossFade(
                          duration: ZenithMotion.scene,
                          alignment: Alignment.centerLeft,
                          // The default layout pins the *outgoing* child to the
                          // animating width (`left: 0, right: 0`), so for every
                          // frame of leaving selection mode the checkbox was
                          // squeezed to the 16dp spacer's width and threw
                          // "overflowed by 16 pixels". Leave its width alone and
                          // clip the stack instead. (An `OverflowBox` here is
                          // wrong: the stack hands it an unbounded height and it
                          // sizes itself infinite — every row threw on build.)
                          layoutBuilder: (topChild, topChildKey, bottomChild,
                              bottomChildKey) {
                            return Stack(
                              clipBehavior: Clip.hardEdge,
                              alignment: Alignment.centerLeft,
                              children: [
                                Positioned(
                                  key: bottomChildKey,
                                  left: 0,
                                  top: 0,
                                  child: bottomChild,
                                ),
                                Positioned(key: topChildKey, child: topChild),
                              ],
                            );
                          },
                          crossFadeState: index != null && onChanged == null
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Checkbox(
                            state: selected
                                ? CheckboxState.checked
                                : CheckboxState.unchecked,
                            onChanged: (state) =>
                                onChanged?.call(state == CheckboxState.checked),
                          ),
                          secondChild: constrains.smAndDown
                              ? const SizedBox(width: 16)
                              : SizedBox(
                                  width: 50,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Text(
                                      '${(index ?? 0) + 1}',
                                      maxLines: 1,
                                      style: theme.typography.small,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                        ),
                        Stack(
                          children: [
                            Container(
                              height: ZenithTrackRowMetrics.artSizeWithMeta,
                              width: ZenithTrackRowMetrics.artSizeWithMeta,
                              decoration: BoxDecoration(
                                // `corners_aa_tracks` is 0dp in @style/proxima's
                                // defaults; the skin's screenshots run a rounded
                                // corners preset, and [ZenithArt.radius] follows
                                // the pictures.
                                borderRadius:
                                    BorderRadius.circular(ZenithArt.radius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(120),
                                    blurRadius:
                                        ZenithTrackRowMetrics.artElevation,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: imageProvider,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: AnimatedContainer(
                                duration: ZenithMotion.fade,
                                curve: ZenithMotion.fadeCurve,
                                decoration: BoxDecoration(
                                  color: isHovering
                                      ? Colors.black.withAlpha(102)
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Skeleton.ignore(
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final isFetchingActiveTrack =
                                          ref.watch(queryingTrackInfoProvider);
                                      return AnimatedSwitcher(
                                        duration: ZenithMotion.fade,
                                        switchInCurve: ZenithMotion.fadeCurve,
                                        switchOutCurve: ZenithMotion.fadeCurve,
                                        child: switch ((
                                          isPlaying,
                                          isFetchingActiveTrack,
                                          isAudioPlaying,
                                          isHovering,
                                          isLoading.value
                                        )) {
                                          (true, true, _, _, _) ||
                                          (_, _, _, _, true) =>
                                            const SizedBox(
                                              width: 26,
                                              height: 26,
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          // Active + audio running → pause glyph;
                                          // active but paused → play glyph.
                                          (true, _, true, _, _) => Icon(
                                              SonolythIcons.pause,
                                              color: theme.colorScheme.primary,
                                            ),
                                          (true, _, false, _, _) => Icon(
                                              SonolythIcons.play,
                                              color: theme.colorScheme.primary,
                                            ),
                                          (_, _, _, true, _) => const Icon(
                                              SonolythIcons.play,
                                              color: Colors.white,
                                            ),
                                          _ => const SizedBox.shrink(),
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: AbsorbPointer(
                            absorbing: selectionMode,
                            child: switch (track) {
                              SonolythLocalTrackObject() => Text(
                                  track.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              // The track name is plain text (not a navigation link) so
                              // a tap anywhere on the row — name included — falls through
                              // to the row's onPressed and PLAYS the track, Spotify-style.
                              // Track details remain reachable via the row's "⋯" menu.
                              //
                              // The playing row is NOT recoloured here — see
                              // [ZenithTrackRowMetrics]; the outline mark carries it.
                              _ => Text(
                                  track.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                            },
                          ),
                        ),
                        if (constrains.mdAndUp) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: switch (track) {
                              SonolythLocalTrackObject() => Text(
                                  track.album.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: line2Style,
                                ),
                              _ => Align(
                                  alignment: Alignment.centerLeft,
                                  child: DefaultTextStyle.merge(
                                    style: line2Style,
                                    child: LinkText(
                                      track.album.name,
                                      AlbumRoute(
                                        album: track.album,
                                        id: track.album.id,
                                      ),
                                      push: true,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                            },
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: ZenithTrackRowMetrics.titleToLine2,
                          ),
                          child: DefaultTextStyle.merge(
                            style: line2Style,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: track is SonolythLocalTrackObject
                                  ? Text(
                                      track.artists.asString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : ClipRect(
                                      child: ConstrainedBox(
                                        // `ArtistLink` is a wrap of tappable
                                        // names, so the row caps its height
                                        // rather than its line count. The cap
                                        // has to follow the system font size or
                                        // the clip lands mid-glyph — at 200% the
                                        // artist line was cut in half on every
                                        // track row in the app (§37), silently,
                                        // because a clip reports no overflow.
                                        constraints: BoxConstraints(
                                          maxHeight: ZenithTrackRowMetrics
                                              .line2MaxHeightOf(context),
                                        ),
                                        child: AbsorbPointer(
                                          absorbing: effectiveSelection,
                                          child: ArtistLink(
                                            artists: track.artists,
                                            onOverflowArtistClick:
                                                effectiveSelection
                                                    ? () {}
                                                    : () {
                                                        context.navigateTo(
                                                          TrackRoute(
                                                            trackId: track.id,
                                                          ),
                                                        );
                                                      },
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        // `ItemTrackMeta` — attached under line 2, left with the
                        // text, the `meta_song` glyph leading. Duration is the one
                        // part always known; codec and bit depth follow when the
                        // registry has them.
                        Padding(
                          padding: const EdgeInsets.only(
                            top: ZenithTrackRowMetrics.line2ToMeta,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ZenithMetaNoteIcon(
                                size: ZenithTrackRowMetrics.metaGlyphSize,
                                color: zenithTrackMeta(theme.colorScheme),
                              ),
                              const SizedBox(
                                width: ZenithTrackRowMetrics.metaGlyphGap,
                              ),
                              Flexible(
                                child: Text(
                                  metaParts.join(" | "),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 8),
                        // Poweramp's row has no per-row buttons (the picture
                        // shows none); the download lives in the options sheet.
                        // The pointer-driven desktop shortcut went with the
                        // desktop platforms (§40).
                        // Duration lives in the meta line now; Poweramp's row has
                        // no trailing counter.
                        Builder(
                          builder: (context) {
                            return TrackOptionsButton(
                              track: track,
                              userPlaylist: userPlaylist,
                              playlistId: playlistId,
                              collectionName: collectionName,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
