import 'dart:math';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/dialogs/playlist_add_track_dialog.dart';
import 'package:sonolyth/components/dialogs/select_device_dialog.dart';
import 'package:sonolyth/components/track_presentation/presentation_actions.dart'
    show showToastForAction;
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/components/ui/zenith_pro_icons.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/connect/connect.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/audio_player/smart_shuffle.dart';
import 'package:sonolyth/provider/connect/connect.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// Poweramp's selection mode over the search results — the same shape as
/// `PresentationState`'s, but the results are not a collection, so the state
/// lives beside the search page instead of in `presentationStateProvider`.
/// Auto-disposed with the page: leaving Search drops the selection.
class SearchSelectionState {
  final bool selectionMode;
  final List<SonolythTrackObject> selectedTracks;

  const SearchSelectionState({
    this.selectionMode = false,
    this.selectedTracks = const [],
  });

  bool get isSelecting => selectionMode || selectedTracks.isNotEmpty;

  bool contains(SonolythTrackObject track) =>
      selectedTracks.any((t) => t.id == track.id);

  SearchSelectionState copyWith({
    bool? selectionMode,
    List<SonolythTrackObject>? selectedTracks,
  }) =>
      SearchSelectionState(
        selectionMode: selectionMode ?? this.selectionMode,
        selectedTracks: selectedTracks ?? this.selectedTracks,
      );
}

class SearchSelectionNotifier
    extends AutoDisposeNotifier<SearchSelectionState> {
  @override
  SearchSelectionState build() => const SearchSelectionState();

  void select(SonolythTrackObject track) {
    if (state.contains(track)) return;
    state = state.copyWith(selectedTracks: [...state.selectedTracks, track]);
  }

  void deselect(SonolythTrackObject track) {
    state = state.copyWith(
      selectedTracks:
          state.selectedTracks.where((t) => t.id != track.id).toList(),
    );
  }

  void clear() => state = const SearchSelectionState();

  /// The header's "Select" (`cmd_list_toggle_selection_mode`): on with nothing
  /// ticked shows the checkboxes; off clears the selection and the boxes.
  void toggleSelectionMode() {
    if (state.isSelecting) {
      clear();
    } else {
      state = state.copyWith(selectionMode: true);
    }
  }
}

final searchSelectionProvider =
    AutoDisposeNotifierProvider<SearchSelectionNotifier, SearchSelectionState>(
  SearchSelectionNotifier.new,
);

/// `merge_item_text_header` in `scene_search_header` — the header-button row
/// under the search chips: shuffle, play, "Select", and the `header_menu`
/// glyph at the right. The search glyph the collection header carries is
/// `dontApplyIfGone` in this scene (you are already searching), so the row is
/// three buttons and the menu — exactly what the skin's search panel shows.
///
/// Shuffle and play act on the result tracks of the current chip (All,
/// Tracks). On a chip with no tracks (Albums, Artists, Playlists) they sit at
/// `disabledAlpha`, the way Poweramp's `AlphaDisabledView` greys a header over
/// an empty list, and the menu holds the list's view mode instead of the bulk
/// actions. While the results are what the queue is playing the row behaves
/// like a collection header: play becomes pause, shuffle shows its mode.
class SearchResultsHeader extends HookConsumerWidget {
  const SearchResultsHeader({
    super.key,
    required this.searchTerm,
    required this.tracks,
    this.isGrid,
    this.onViewMode,
  });

  final String searchTerm;

  /// The current chip's result tracks; null when the chip lists no tracks.
  final List<SonolythFullTrackObject>? tracks;

  /// View mode for the chips that render a `PlaybuttonView`; the menu offers
  /// "Grid view" / "List view" when [onViewMode] is given.
  final bool? isGrid;
  final ValueChanged<bool>? onViewMode;

  @override
  Widget build(BuildContext context, ref) {
    final colorScheme = context.theme.colorScheme;
    final results = tracks ?? const <SonolythFullTrackObject>[];
    final hasTracks = results.isNotEmpty;

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.read(audioPlayerProvider.notifier);
    final downloader = ref.read(downloadManagerProvider.notifier);
    final selection = ref.watch(searchSelectionProvider);
    final selectionNotifier = ref.read(searchSelectionProvider.notifier);

    // The queue remembers which results it was loaded from, so the header can
    // show pause / the shuffle state while they play — like a collection.
    final collectionId = "search:$searchTerm";
    final isActive = hasTracks && playlist.collections.contains(collectionId);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;
    final isShuffled =
        useStream(audioPlayer.shuffledStream).data ?? audioPlayer.isShuffled;
    final smartShuffle = ref.watch(smartShuffleProvider);

    final isPlayLoading = useState(false);
    final isShuffleLoading = useState(false);
    final busy = isPlayLoading.value || isShuffleLoading.value;

    Future<void> start({required bool shuffle}) async {
      final flag = shuffle ? isShuffleLoading : isPlayLoading;
      try {
        flag.value = true;
        final isRemoteDevice = await showSelectDeviceDialog(context, ref);
        if (isRemoteDevice == null) return;
        if (isRemoteDevice) {
          final remotePlayback = ref.read(connectProvider.notifier);
          await remotePlayback.load(
            WebSocketLoadEventData.playlist(
              tracks: results,
              initialIndex: shuffle ? Random().nextInt(results.length) : 0,
            ),
          );
          if (shuffle) await remotePlayback.setShuffle(true);
        } else {
          // Shuffled in Dart and started on a deterministic index, like the
          // collection header (see `useActionCallbacks`); the mode is lit
          // after the start so it persists without delaying it.
          final list = shuffle ? (results.toList()..shuffle()) : results;
          await playlistNotifier.load(list, autoPlay: true);
          if (shuffle) await audioPlayer.setShuffle(true);
          playlistNotifier.addCollection(collectionId);
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      } finally {
        if (context.mounted) flag.value = false;
      }
    }

    // ---- header buttons ---------------------------------------------------
    final shuffleActive = isActive && (isShuffled || smartShuffle);
    final shuffleButton = ZenithHeaderButton(
      tooltip: isActive && smartShuffle
          ? context.l10n.smart_shuffle
          : isActive
              ? context.l10n.unshuffle_playlist
              : context.l10n.shuffle,
      glyph: ZenithHeaderGlyph.shuffle,
      selected: shuffleActive,
      loading: isShuffleLoading.value,
      enabled: hasTracks && !busy,
      onPressed:
          isActive ? () => cycleShuffleMode(ref) : () => start(shuffle: true),
    );

    final playButton = ZenithHeaderButton(
      tooltip: isActive && playing ? context.l10n.pause : context.l10n.play,
      glyph: isActive && playing ? null : ZenithHeaderGlyph.play,
      icon: isActive && playing ? SonolythIcons.pause : null,
      loading: isPlayLoading.value,
      enabled: hasTracks && !busy,
      onPressed: isActive
          ? () => playing ? audioPlayer.pause() : audioPlayer.resume()
          : () => start(shuffle: false),
    );

    final selectButton = ZenithHeaderButton(
      tooltip: context.l10n.select,
      label: context.l10n.select,
      selected: selection.isSelecting,
      enabled: hasTracks,
      onPressed: selectionNotifier.toggleSelectionMode,
    );

    // ---- header menu ------------------------------------------------------
    // Bulk actions over the selection — or over every result when nothing is
    // ticked, the way the collection header's menu works.
    final selectedCount = selection.selectedTracks.length;
    final whole = selectedCount == 0 || selectedCount == results.length;

    Future<void> onMenuAction(String action) async {
      if (action == "grid" || action == "list") {
        onViewMode?.call(action == "grid");
        return;
      }
      if (!hasTracks) return;
      final current = ref.read(searchSelectionProvider);
      final picked = current.selectedTracks.isEmpty
          ? results.cast<SonolythTrackObject>()
          : current.selectedTracks;

      switch (action) {
        case "download":
          final full = picked.whereType<SonolythFullTrackObject>().toList();
          downloader.addAllToQueue(full, collectionName: searchTerm);
          selectionNotifier.clear();
          if (!context.mounted) return;
          showToastForAction(context, action, full.length);
        case "add-to-playlist":
          final worked = await showDialog<bool>(
            context: context,
            builder: (context) => PlaylistAddTrackDialog(
              openFromPlaylist: null,
              tracks: picked.toList(),
            ),
          );
          // Leave selection mode even when the dialog was dismissed.
          selectionNotifier.clear();
          if (!context.mounted || worked != true) return;
          showToastForAction(context, action, picked.length);
        case "play-next":
          await playlistNotifier.addTracksAtFirst(picked);
          selectionNotifier.clear();
          if (!context.mounted) return;
          showToastForAction(context, action, picked.length);
        case "add-to-queue":
          await playlistNotifier.addTracks(picked);
          selectionNotifier.clear();
          if (!context.mounted) return;
          showToastForAction(context, action, picked.length);
        default:
      }
    }

    List<AdaptiveMenuButton<String>> Function(BuildContext)? menuItems;
    if (tracks != null) {
      menuItems = (context) => [
            AdaptiveMenuButton(
              value: "download",
              leading: const Icon(SonolythIcons.download),
              child: Text(
                whole
                    ? context.l10n.download_all
                    : context.l10n.download_count(selectedCount),
              ),
            ),
            AdaptiveMenuButton(
              value: "add-to-playlist",
              leading: const Icon(SonolythIcons.playlistAdd),
              child: Text(
                whole
                    ? context.l10n.add_all_to_playlist
                    : context.l10n.add_count_to_playlist(selectedCount),
              ),
            ),
            AdaptiveMenuButton(
              value: "add-to-queue",
              leading: const Icon(SonolythIcons.queueAdd),
              child: Text(
                whole
                    ? context.l10n.add_all_to_queue
                    : context.l10n.add_count_to_queue(selectedCount),
              ),
            ),
            AdaptiveMenuButton(
              value: "play-next",
              leading: const Icon(SonolythIcons.lightning),
              child: Text(
                whole
                    ? context.l10n.play_all_next
                    : context.l10n.play_count_next(selectedCount),
              ),
            ),
          ];
    } else if (onViewMode != null) {
      menuItems = (context) => [
            AdaptiveMenuButton(
              value: "grid",
              leading: const Icon(SonolythIcons.grid),
              child: Text(context.l10n.grid_view),
            ),
            AdaptiveMenuButton(
              value: "list",
              leading: const Icon(SonolythIcons.list),
              child: Text(context.l10n.list_view),
            ),
          ];
    }

    Widget? menu;
    if (menuItems != null) {
      menu = SizedBox(
        width: ZenithListHeaderMetrics.menuButtonWidth,
        height: ZenithListHeaderMetrics.menuButtonSize,
        child: AdaptivePopSheetList<String>(
          tooltip: context.l10n.more_actions,
          items: menuItems,
          icon: ZenithHeaderMenuIcon(
            size: ZenithListHeaderMetrics.menuGlyphSize,
            color: colorScheme.primary,
          ),
          onSelected: onMenuAction,
        ),
      );
      // Nothing to act on yet: greyed like the buttons (`disabledAlpha`).
      if (tracks != null && !hasTracks) {
        menu = IgnorePointer(child: Opacity(opacity: 0.275, child: menu));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZenithListHeaderMetrics.buttonsLeft,
        ZenithListHeaderMetrics.searchHeaderTop,
        ZenithListHeaderMetrics.menuRight,
        ZenithListHeaderMetrics.buttonsBottom,
      ),
      child: SizedBox(
        height: ZenithListHeaderMetrics.menuButtonSize,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            shuffleButton,
            const SizedBox(width: ZenithListHeaderMetrics.buttonGap),
            playButton,
            const SizedBox(width: ZenithListHeaderMetrics.buttonGap),
            selectButton,
            const Spacer(),
            if (menu != null) menu,
          ],
        ),
      ),
    );
  }
}
