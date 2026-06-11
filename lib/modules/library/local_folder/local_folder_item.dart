import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_card.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_tile.dart';
import 'package:sonolyth/components/track_presentation/presentation_actions.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/extensions/string.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/local_tracks/local_tracks_provider.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';

class LocalFolderItem extends HookConsumerWidget {
  final String folder;
  final bool _isTile;
  const LocalFolderItem({super.key, required this.folder}) : _isTile = false;

  const LocalFolderItem.tile({super.key, required this.folder})
      : _isTile = true;

  @override
  Widget build(BuildContext context, ref) {
    final ThemeData(:colorScheme) = Theme.of(context);

    final downloadFolder =
        ref.watch(userPreferencesProvider.select((s) => s.downloadLocation));
    final cacheFolder = useFuture(UserPreferencesNotifier.getMusicCacheDir());

    final isDownloadFolder = folder == downloadFolder;
    final isCacheFolder = folder == cacheFolder.data;
    // A per-collection subfolder created by downloading a playlist/album. It's
    // managed by the downloader, not a user-added library location.
    final isDownloadSubfolder = downloadFolder.isNotEmpty &&
        folder != downloadFolder &&
        isWithin(downloadFolder, folder);

    final trackSnapshot = ref.watch(
      localTracksProvider.select(
        (s) => s.whenData((tracks) => tracks[folder]),
      ),
    );
    final tracks = trackSnapshot.value ?? <SonolythLocalTrackObject>[];

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.read(audioPlayerProvider.notifier);
    final isPlaying = tracks.isNotEmpty && playlist.containsTracks(tracks);

    final title = isDownloadFolder
        ? context.l10n.downloads
        : isCacheFolder
            ? context.l10n.cache_folder.capitalize()
            : basename(folder);
    final description = "${tracks.length} ${context.l10n.tracks}";

    final onTap = useCallback(() {
      context.navigateTo(
        LocalLibraryRoute(
          location: folder,
          isCache: isCacheFolder,
          isDownloads: isDownloadFolder,
        ),
      );
    }, [context, folder, isCacheFolder, isDownloadFolder]);

    final onPlaybuttonPressed = useCallback(() async {
      if (tracks.isEmpty || isPlaying) return;
      await playlistNotifier.load(tracks, initialIndex: 0, autoPlay: true);
    }, [tracks, isPlaying, playlistNotifier]);

    final onAddToQueuePressed = useCallback(() async {
      if (tracks.isEmpty || isPlaying) return;
      await playlistNotifier.addTracks(tracks);
      if (!context.mounted) return;
      showToastForAction(context, "add-to-queue", tracks.length);
    }, [tracks, isPlaying, playlistNotifier, context]);

    final image = _FolderArtCollage(tracks: tracks);

    final showRemoveMenu = useCallback(() {
      showDropdown(
        context: context,
        builder: (context) {
          return DropdownMenu(
            children: [
              MenuButton(
                leading: Icon(
                  SonolythIcons.folderRemove,
                  color: colorScheme.destructive,
                ),
                child: Text(context.l10n.remove_library_location),
                onPressed: (context) {
                  final libraryLocations =
                      ref.read(userPreferencesProvider).localLibraryLocation;
                  ref
                      .read(userPreferencesProvider.notifier)
                      .setLocalLibraryLocation(
                        libraryLocations.where((e) => e != folder).toList(),
                      );
                },
              )
            ],
          );
        },
      );
    }, [context, colorScheme, ref, folder]);

    final isRemovable =
        !isDownloadFolder && !isCacheFolder && !isDownloadSubfolder;

    if (_isTile) {
      final tile = PlaybuttonTile(
        image: image,
        isPlaying: isPlaying,
        isLoading: trackSnapshot.isLoading,
        title: title,
        description: description,
        onTap: onTap,
        onPlaybuttonPressed: onPlaybuttonPressed,
        onAddToQueuePressed: onAddToQueuePressed,
      );
      if (!isRemovable) return tile;
      return Row(
        children: [
          Expanded(child: tile),
          IconButton.ghost(
            icon: const Icon(SonolythIcons.moreVertical),
            size: ButtonSize.small,
            onPressed: showRemoveMenu,
          ),
        ],
      );
    }

    final card = PlaybuttonCard(
      image: image,
      isPlaying: isPlaying,
      isLoading: trackSnapshot.isLoading,
      title: title,
      description: description,
      onTap: onTap,
      onPlaybuttonPressed: onPlaybuttonPressed,
      onAddToQueuePressed: onAddToQueuePressed,
    );
    if (!isRemovable) return card;
    return Stack(
      children: [
        card,
        Positioned(
          right: 5,
          top: 5,
          child: IconButton.secondary(
            icon: const Icon(SonolythIcons.moreVertical),
            size: ButtonSize.small,
            onPressed: showRemoveMenu,
          ),
        ),
      ],
    );
  }
}

/// Square cover for a folder: a collage of up to 4 album arts, or a folder
/// icon when the folder has no scanned tracks yet.
class _FolderArtCollage extends StatelessWidget {
  final List<SonolythLocalTrackObject> tracks;
  const _FolderArtCollage({required this.tracks});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);

    final arts = tracks
        .take(4)
        .map(
          (track) => track.album.images.asUrlString(
            placeholder: ImagePlaceholder.albumArt,
          ),
        )
        .toList();

    if (arts.isEmpty) {
      return Container(
        color: colorScheme.secondary,
        child: Center(
          child: Icon(
            SonolythIcons.folder,
            size: 60,
            color: colorScheme.mutedForeground,
          ),
        ),
      );
    }

    if (arts.length < 4) {
      return UniversalImage(path: arts.first, fit: BoxFit.cover);
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final art in arts) UniversalImage(path: art, fit: BoxFit.cover),
      ],
    );
  }
}
