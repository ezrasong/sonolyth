import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' as material;
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' show basename;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sonolyth/collections/fake.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/button/back_button.dart';
import 'package:sonolyth/components/track_presentation/presentation_actions.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/string.dart';
import 'package:sonolyth/hooks/controllers/use_shadcn_text_editing_controller.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/library/local_folder/cache_export_dialog.dart';
import 'package:sonolyth/pages/library/user_local_tracks/user_local_tracks.dart';
import 'package:sonolyth/components/expandable_search/expandable_search.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/components/track_presentation/sort_tracks_dropdown.dart';
import 'package:sonolyth/components/track_tile/track_tile.dart';
import 'package:sonolyth/components/ui/sheet_aware_pop_scope.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/local_tracks/local_tracks_provider.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/utils/service_utils.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/components/fallbacks/zenith_illustration.dart';

/// The folder page's header is the only [TitleBar] in the app that stacks two
/// lines — the 29sp folder name over an 11sp size — so it is the only one that
/// passes an explicit `height`, and 48dp clipped it by 6px on the emulator.
///
/// **An explicit height bypasses the growth `TitleBar` adds for its own title**
/// (§37), which is why this page still overflowed by 14px at Android's 200%
/// after that sweep: the fix was in the default branch and this call site never
/// took it. Same rule here — keep the measured 64 and add what *these two*
/// lines grow by, which [zenithLineGrowth] makes **0** at the default scale by
/// construction.
double localFolderHeaderHeight(BuildContext context) =>
    localFolderHeaderBase * context.theme.scaling +
    zenithLineGrowth(context, zenithPageTitle(context.theme.colorScheme)) +
    zenithLineGrowth(context, zenithTextLine2(context.theme.colorScheme));

/// The measured two-line header, before any font-scale growth.
const localFolderHeaderBase = 64.0;

@RoutePage()
class LocalLibraryPage extends HookConsumerWidget {
  static const name = "local_library_page";

  final String location;
  final bool isDownloads;
  final bool isCache;
  const LocalLibraryPage(
    this.location, {
    super.key,
    this.isDownloads = false,
    this.isCache = false,
  });

  Future<void> playLocalTracks(
    WidgetRef ref,
    List<SonolythLocalTrackObject> tracks, {
    SonolythLocalTrackObject? currentTrack,
  }) async {
    if (tracks.isEmpty) return;
    final playlist = ref.read(audioPlayerProvider);
    final playback = ref.read(audioPlayerProvider.notifier);
    currentTrack ??= tracks.first;
    final isPlaylistPlaying = playlist.containsTracks(tracks);
    if (!isPlaylistPlaying) {
      var indexWhere = tracks.indexWhere((s) => s.id == currentTrack?.id);
      await playback.load(
        tracks,
        initialIndex: indexWhere,
        autoPlay: true,
      );
    } else if (isPlaylistPlaying &&
        currentTrack.id != playlist.activeTrack?.id) {
      await playback.jumpToTrack(currentTrack);
    }
  }

  Future<void> shufflePlayLocalTracks(
    WidgetRef ref,
    List<SonolythLocalTrackObject> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final playlist = ref.read(audioPlayerProvider);
    final playback = ref.read(audioPlayerProvider.notifier);
    final isPlaylistPlaying = playlist.containsTracks(tracks);
    final shuffledTracks = tracks.shuffled();
    if (isPlaylistPlaying) return;

    await playback.load(
      shuffledTracks,
      initialIndex: 0,
      autoPlay: true,
    );
  }

  Future<void> addToQueueLocalTracks(
    BuildContext context,
    WidgetRef ref,
    List<SonolythLocalTrackObject> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final playlist = ref.read(audioPlayerProvider);
    final playback = ref.read(audioPlayerProvider.notifier);
    final isPlaylistPlaying = playlist.containsTracks(tracks);
    if (isPlaylistPlaying) return;
    await playback.addTracks(tracks);
    if (!context.mounted) return;
    showToastForAction(context, "add-to-queue", tracks.length);
  }

  @override
  Widget build(BuildContext context, ref) {
    final scale = context.theme.scaling;

    final sortBy = useState<SortBy>(SortBy.none);
    final playlist = ref.watch(audioPlayerProvider);
    final trackSnapshot = ref.watch(localTracksProvider);
    final folderTracks = trackSnapshot.asData?.value[location] ??
        const <SonolythLocalTrackObject>[];
    final isPlaylistPlaying = useMemoized(
      () => folderTracks.isNotEmpty && playlist.containsTracks(folderTracks),
      [playlist, trackSnapshot, location],
    );
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

    final searchController = useShadcnTextEditingController();
    useValueListenable(searchController);
    final searchFocus = useFocusNode();
    final isFiltering = useState(false);

    final controller = useScrollController();

    final directorySize = useMemoized(() async {
      final dir = Directory(location);
      final files = await dir.list(recursive: true).toList();

      final filesLength =
          await Future.wait(files.whereType<File>().map((e) => e.length()));

      return (filesLength.sum.toInt() / pow(10, 9)).toStringAsFixed(2);
    }, [location]);

    return SheetAwarePopScope(
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            TitleBar(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
              height: localFolderHeaderHeight(context),
              surfaceBlur: 0,
              leading: const [BackButton()],
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDownloads
                        ? context.l10n.downloads
                        : isCache
                            ? context.l10n.cache_folder.capitalize()
                            : basename(location),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  FutureBuilder<String>(
                    future: directorySize,
                    builder: (context, snapshot) {
                      // Show a dash until the size is actually known instead of
                      // a misleading "0 GB" while loading (or after an error).
                      return Text(
                        snapshot.hasData
                            ? context.l10n.size_in_gb(snapshot.data!)
                            : "—",
                        // `ItemTextLine2` — 11sp at `textColorPrimary`. The
                        // explicit style matters: `TitleBar` wraps its title in
                        // the 29sp header style, which this would inherit.
                        style: zenithTextLine2(context.theme.colorScheme),
                      );
                    },
                  )
                ],
              ),
              backgroundColor: Colors.transparent,
              trailingGap: 10,
              trailing: [
                if (isCache) ...[
                  // `ItemHeader*Button`: `drawableOnly`, transparent background
                  // in `@style/proxima` — icon-only glyphs with the label as the
                  // tooltip, not labelled outline chips.
                  ZenithTooltip(
                    message: context.l10n.clear_cache,
                    child: IconButton.ghost(
                      shape: ButtonShape.circle,
                      icon: const Icon(SonolythIcons.delete),
                      onPressed: () async {
                        final accepted = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.l10n.clear_cache_confirmation),
                            actions: [
                              Button.outline(
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                                child: Text(context.l10n.decline),
                              ),
                              Button.destructive(
                                onPressed: () async {
                                  Navigator.of(context).pop(true);
                                },
                                child: Text(context.l10n.accept),
                              ),
                            ],
                          ),
                        );

                        if (accepted != true) return;

                        final cacheDir = Directory(
                          await UserPreferencesNotifier.getMusicCacheDir(),
                        );

                        if (cacheDir.existsSync()) {
                          await cacheDir.delete(recursive: true);
                        }

                        ref.invalidate(localTracksProvider);
                      },
                    ),
                  ),
                  ZenithTooltip(
                    message: context.l10n.export,
                    child: IconButton.ghost(
                      shape: ButtonShape.circle,
                      icon: const Icon(SonolythIcons.export),
                      onPressed: () async {
                        final exportPath =
                            await FilePicker.platform.getDirectoryPath();

                        if (exportPath == null) return;
                        final exportDirectory = Directory(exportPath);

                        if (!exportDirectory.existsSync()) {
                          await exportDirectory.create(recursive: true);
                        }

                        final cacheDir = Directory(
                            await UserPreferencesNotifier.getMusicCacheDir());

                        if (!context.mounted) return;
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return LocalFolderCacheExportDialog(
                              cacheDir: cacheDir,
                              exportDir: exportDirectory,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ]
              ],
            ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Gap(5),
                      ZenithTooltip(
                        message: context.l10n.play,
                        // `ItemHeaderPlayButton` in `@style/proxima` sets
                        // `android:background` to transparent — a bare glyph in a
                        // row of equal glyphs, not a filled white disc.
                        child: IconButton.ghost(
                          shape: ButtonShape.circle,
                          // When this folder is already the active playlist the
                          // button toggles pause/resume instead of restarting.
                          onPressed: folderTracks.isNotEmpty
                              ? () async {
                                  if (isPlaylistPlaying) {
                                    playing
                                        ? await audioPlayer.pause()
                                        : await audioPlayer.resume();
                                  } else {
                                    await playLocalTracks(ref, folderTracks);
                                  }
                                }
                              : null,
                          icon: Icon(
                            isPlaylistPlaying && playing
                                ? SonolythIcons.pause
                                : SonolythIcons.play,
                          ),
                        ),
                      ),
                      const Gap(5),
                      ZenithTooltip(
                        message: context.l10n.shuffle,
                        child: IconButton.ghost(
                          shape: ButtonShape.circle,
                          onPressed: folderTracks.isNotEmpty
                              ? () async {
                                  if (!isPlaylistPlaying) {
                                    await shufflePlayLocalTracks(
                                      ref,
                                      folderTracks,
                                    );
                                  }
                                }
                              : null,
                          enabled:
                              folderTracks.isNotEmpty && !isPlaylistPlaying,
                          icon: const Icon(SonolythIcons.shuffle),
                        ),
                      ),
                      const Gap(5),
                      ZenithTooltip(
                        message: context.l10n.add_to_queue,
                        child: IconButton.ghost(
                          shape: ButtonShape.circle,
                          onPressed: folderTracks.isNotEmpty
                              ? () async {
                                  if (!isPlaylistPlaying) {
                                    await addToQueueLocalTracks(
                                      context,
                                      ref,
                                      folderTracks,
                                    );
                                  }
                                }
                              : null,
                          enabled:
                              folderTracks.isNotEmpty && !isPlaylistPlaying,
                          icon: const Icon(SonolythIcons.queueAdd),
                        ),
                      ),
                      const Spacer(),
                      if (constraints.smAndDown)
                        ExpandableSearchButton(
                          isFiltering: isFiltering.value,
                          onPressed: (value) => isFiltering.value = value,
                          searchFocus: searchFocus,
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 300 * scale,
                            maxHeight: 38 * scale,
                          ),
                          child: ExpandableSearchField(
                            isFiltering: true,
                            onChangeFiltering: (value) {},
                            searchController: searchController,
                            searchFocus: searchFocus,
                          ),
                        ),
                      const Gap(5),
                      SortTracksDropdown(
                        value: sortBy.value,
                        onChanged: (value) {
                          sortBy.value = value;
                        },
                      ),
                      const Gap(5),
                      ZenithTooltip(
                        message: context.l10n.refresh,
                        child: IconButton.ghost(
                          shape: ButtonShape.circle,
                          icon: const Icon(SonolythIcons.refresh),
                          onPressed: () {
                            ref.invalidate(localTracksProvider);
                          },
                        ),
                      )
                    ],
                  ),
                ),
                // Wide layouts already render an inline search field in the
                // toolbar; mounting this one too would attach two TextFields
                // to the same FocusNode/controller.
                if (constraints.smAndDown)
                  ExpandableSearchField(
                    searchController: searchController,
                    searchFocus: searchFocus,
                    isFiltering: isFiltering.value,
                    onChangeFiltering: (value) => isFiltering.value = value,
                  ),
                HookBuilder(builder: (context) {
                  return trackSnapshot.when(
                    data: (tracks) {
                      final sortedTracks = useMemoized(() {
                        return ServiceUtils.sortTracks(
                            tracks[location] ?? <SonolythLocalTrackObject>[],
                            sortBy.value);
                      }, [sortBy.value, tracks]);

                      final filteredTracks = useMemoized(() {
                        if (searchController.text.isEmpty) {
                          return sortedTracks;
                        }
                        return sortedTracks
                            .map((e) => (
                                  weightedRatio(
                                    "${e.name} - ${e.artists.asString()}",
                                    searchController.text,
                                  ),
                                  e,
                                ))
                            .toList()
                            .sorted(
                              (a, b) => b.$1.compareTo(a.$1),
                            )
                            .where((e) => e.$1 > 50)
                            .map((e) => e.$2)
                            .toList()
                            .toList();
                      }, [searchController.text, sortedTracks]);

                      if (!trackSnapshot.isLoading && filteredTracks.isEmpty) {
                        return Expanded(
                          // `ItemEmptyList`: one centred line at 60%, no art.
                          child: Center(
                            child:
                                ZenithEmptyListText(context.l10n.nothing_found),
                          ),
                        );
                      }

                      return Expanded(
                        child: material.RefreshIndicator.adaptive(
                          onRefresh: () async {
                            ref.invalidate(localTracksProvider);
                          },
                          child: InterScrollbar(
                            controller: controller,
                            child: Skeletonizer(
                              enabled: trackSnapshot.isLoading,
                              child: CustomScrollView(
                                controller: controller,
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverList.builder(
                                    itemCount: trackSnapshot.isLoading
                                        ? 5
                                        : filteredTracks.length,
                                    itemBuilder: (context, index) {
                                      if (trackSnapshot.isLoading) {
                                        return TrackTile(
                                          playlist: playlist,
                                          track: FakeData.track,
                                          index: index,
                                        );
                                      }

                                      final track = filteredTracks[index];
                                      return TrackTile(
                                        index: index,
                                        playlist: playlist,
                                        track: track,
                                        userPlaylist: false,
                                        onTap: () async {
                                          await playLocalTracks(
                                            ref,
                                            sortedTracks,
                                            currentTrack: track,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  const SliverGap(200),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => Expanded(
                      child: Skeletonizer(
                        enabled: true,
                        child: ListView.builder(
                          itemCount: 5,
                          itemBuilder: (context, index) => TrackTile(
                            track: FakeData.track,
                            index: index,
                            playlist: playlist,
                          ),
                        ),
                      ),
                    ),
                    error: (error, stackTrace) =>
                        Text(error.toString() + stackTrace.toString()),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
