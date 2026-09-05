import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/presentation_state.dart';
import 'package:sonolyth/components/track_presentation/sort_tracks_dropdown.dart';
import 'package:sonolyth/components/track_presentation/use_action_callbacks.dart';
import 'package:sonolyth/components/track_presentation/use_is_user_playlist.dart';
import 'package:sonolyth/components/ui/zenith_header_overlay.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/playlist/playlist_create_dialog.dart';
import 'package:sonolyth/provider/audio_player/smart_shuffle.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

class TrackPresentationTopSection extends HookConsumerWidget {
  /// The header's search button (`ItemHeaderSearchButton`). Poweramp's reveals
  /// the list filter and closes it again; the owner toggles the row here and
  /// reports its state back through [searchActive].
  final VoidCallback? onSearch;
  final bool searchActive;

  /// The header's "Select" (`ItemHeaderSelectButton`,
  /// `cmd_list_toggle_selection_mode`).
  final VoidCallback? onSelect;
  final bool selectionActive;

  const TrackPresentationTopSection({
    super.key,
    this.onSearch,
    this.searchActive = false,
    this.onSelect,
    this.selectionActive = false,
  });

  static String _formatTotal(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? "$h:${two(m)}:${two(s)}" : "$m:${two(s)}";
  }

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.sizeOf(context);
    final options = TrackPresentationOptions.of(context);
    final colorScheme = context.theme.colorScheme;
    final isUserPlaylist = useIsUserPlaylist(ref, options.collectionId);
    final isWide = mediaQuery.mdAndUp;

    final parentLabel = switch (options.collection) {
      SonolythSimpleAlbumObject() => context.l10n.albums,
      _ => context.l10n.playlists,
    };

    final (
      :isLoading,
      :isActive,
      :isPlayLoading,
      :isShuffleLoading,
      :onPlay,
      :onShuffle
    ) = useActionCallbacks(ref);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    final isShuffled =
        useStream(audioPlayer.shuffledStream).data ?? audioPlayer.isShuffled;
    final smartShuffle = ref.watch(smartShuffleProvider);
    final isDownloadingAll = useState(false);

    Future<void> onDownloadAll() async {
      if (isDownloadingAll.value) return;
      isDownloadingAll.value = true;
      try {
        final tracks = options.tracks.isEmpty
            ? await options.pagination.onFetchAll()
            : options.tracks;
        final fullTracks = tracks.whereType<SonolythFullTrackObject>().toList();
        if (fullTracks.isEmpty) return;

        final queuedCount =
            ref.read(downloadManagerProvider.notifier).addAllToQueue(
                  fullTracks,
                  collectionUrl: options.shareUrl,
                  collectionName: options.title,
                );
        if (!context.mounted) return;
        showToast(
          context: context,
          location: ToastLocation.topRight,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(
              leading: const Icon(SonolythIcons.download),
              title: Text(context.l10n.download_count(queuedCount)),
            ),
          ),
        );
      } finally {
        isDownloadingAll.value = false;
      }
    }

    Future<void> onShare() async {
      await Clipboard.setData(ClipboardData(text: options.shareUrl!));
      if (!context.mounted) return;
      showToast(
        context: context,
        location: ToastLocation.topRight,
        builder: (context, overlay) => SurfaceCard(
          child: Text(
            context.l10n.copied_shareurl_to_clipboard(options.shareUrl!),
          ).small(),
        ),
      );
    }

    // ---- meta line: "♪ n | m:ss | year" ----------------------------------
    final trackCount = options.tracks.isNotEmpty ? options.tracks.length : null;
    final total = Duration(
      milliseconds: options.tracks.fold(0, (sum, t) => sum + t.durationMs),
    );
    final year = switch (options.collection) {
      SonolythSimpleAlbumObject(:final releaseDate?)
          when releaseDate.length >= 4 =>
        releaseDate.substring(0, 4),
      _ => null,
    };
    final metaParts = <String>[
      if (trackCount != null) trackCount.toString(),
      if (total > Duration.zero) _formatTotal(total),
      if (year != null) year,
    ];

    // ---- header buttons ---------------------------------------------------
    final isSmart = isActive && smartShuffle;
    final shuffleActive = isActive && (isShuffled || smartShuffle);

    final shuffleButton = ZenithHeaderButton(
      tooltip: isSmart
          ? context.l10n.smart_shuffle
          : isActive
              ? context.l10n.unshuffle_playlist
              : context.l10n.shuffle_playlist,
      glyph: ZenithHeaderGlyph.shuffle,
      // On: the `alpha_popup_button_layout_activated_bg` pill behind the glyph.
      selected: shuffleActive,
      loading: isShuffleLoading,
      enabled: !isLoading,
      onPressed: isActive ? () => cycleShuffleMode(ref) : onShuffle,
    );

    final playButton = ZenithHeaderButton(
      tooltip: isActive && playing ? context.l10n.pause : context.l10n.play,
      glyph: isActive && playing ? null : ZenithHeaderGlyph.play,
      icon: isActive && playing ? SonolythIcons.pause : null,
      loading: isPlayLoading,
      enabled: !isLoading,
      onPressed: isActive
          ? () => playing ? audioPlayer.pause() : audioPlayer.resume()
          : onPlay,
    );

    final searchButton = onSearch == null
        ? null
        : ZenithHeaderButton(
            tooltip: context.l10n.search_tracks,
            glyph: ZenithHeaderGlyph.search,
            selected: searchActive,
            onPressed: onSearch!,
          );

    final selectButton = onSelect == null
        ? null
        : ZenithHeaderButton(
            tooltip: context.l10n.select,
            label: context.l10n.select,
            selected: selectionActive,
            onPressed: onSelect!,
          );

    // Poweramp's header menu is where "Sort" lives; the filter row's own sort
    // glyph is only there while the row is revealed.
    final sortBy = ref.watch(
      presentationStateProvider(options.collection)
          .select((state) => state.sortBy),
    );
    final presentationNotifier =
        ref.read(presentationStateProvider(options.collection).notifier);

    List<AdaptiveMenuButton<String>> menuItems(BuildContext context) => [
          if (options.onHeart != null)
            AdaptiveMenuButton(
              value: "heart",
              leading: Icon(
                options.isLiked
                    ? SonolythIcons.heartFilled
                    : SonolythIcons.heart,
              ),
              child: Text(
                options.isLiked
                    ? context.l10n.remove_from_favorites
                    : context.l10n.save_as_favorite,
              ),
            ),
          AdaptiveMenuButton(
            value: "sort",
            leading: const Icon(SonolythIcons.sort),
            child: Text(context.l10n.sort_tracks),
          ),
          AdaptiveMenuButton(
            value: "download",
            leading: const Icon(SonolythIcons.download),
            enabled: !options.pagination.isLoading && !isDownloadingAll.value,
            child: Text(context.l10n.download_all),
          ),
          if (options.shareUrl != null)
            AdaptiveMenuButton(
              value: "share",
              leading: const Icon(SonolythIcons.share),
              child: Text(context.l10n.share),
            ),
          if (isUserPlaylist)
            AdaptiveMenuButton(
              value: "edit",
              leading: const Icon(SonolythIcons.edit),
              child: Text(context.l10n.edit),
            ),
        ];

    final menuButton = SizedBox(
      width: ZenithListHeaderMetrics.menuButtonWidth,
      height: ZenithListHeaderMetrics.menuButtonSize,
      // A `Builder` so the sort picker can anchor to the menu glyph itself on
      // wide layouts rather than to the whole header.
      child: Builder(
        builder: (menuContext) => AdaptivePopSheetList<String>(
          tooltip: context.l10n.more_actions,
          items: menuItems,
          icon: ZenithHeaderMenuIcon(
            size: ZenithListHeaderMetrics.menuGlyphSize,
            color: colorScheme.primary,
          ),
          onSelected: (value) async {
            switch (value) {
              case "heart":
                options.onHeart?.call();
              case "sort":
                // Let this menu's sheet finish closing before the next one
                // opens; the phone sheet closes *after* it reports the tap.
                await Future<void>.delayed(ZenithMotion.fade);
                if (!menuContext.mounted) return;
                await showSortTracksSheet(
                  menuContext,
                  value: sortBy,
                  onChanged: presentationNotifier.sortTracks,
                );
              case "download":
                onDownloadAll();
              case "share":
                onShare();
              case "edit":
                showDialog(
                  context: context,
                  builder: (context) => PlaylistCreateDialog(
                    playlistId: options.collectionId,
                    trackIds: options.tracks.map((e) => e.id).toList(),
                  ),
                );
            }
          },
        ),
      ),
    );

    // ---- assemble -----------------------------------------------------------
    return SliverToBoxAdapter(
      child: ZenithHeaderOverlay(
        image: options.image,
        parentLabel: parentLabel,
        title: options.title,
        line2: options.owner?.trim(),
        metaParts: metaParts,
        height: isWide
            ? ZenithHeaderMetrics.wideHeight
            : ZenithHeaderMetrics.phoneHeight,
        buttons: [
          shuffleButton,
          playButton,
          if (searchButton != null) searchButton,
          if (selectButton != null) selectButton,
        ],
        menu: menuButton,
      ),
    );
  }
}
