import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/dialogs/playlist_add_track_dialog.dart';
import 'package:sonolyth/components/dialogs/prompt_dialog.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/presentation_state.dart';
import 'package:sonolyth/components/track_presentation/use_is_user_playlist.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/provider/history/history.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/metadata_plugin/library/playlists.dart';

ToastOverlay showToastForAction(
  BuildContext context,
  String action,
  int count,
) {
  final message = switch (action) {
    "download" => (context.l10n.download_count(count), SonolythIcons.download),
    "add-to-playlist" => (
        context.l10n.add_count_to_playlist(count),
        SonolythIcons.playlistAdd
      ),
    "add-to-queue" => (
        context.l10n.add_count_to_queue(count),
        SonolythIcons.queueAdd
      ),
    "play-next" => (
        context.l10n.play_count_next(count),
        SonolythIcons.lightning
      ),
    "remove-from-playlist" => (
        context.l10n.remove_from_playlist,
        SonolythIcons.trash
      ),
    _ => ("", SonolythIcons.error),
  };

  return showToast(
    context: context,
    location: ToastLocation.topRight,
    builder: (context, overlay) {
      return SurfaceCard(
        child: Basic(
          leading: Icon(message.$2),
          title: Text(message.$1),
          leadingAlignment: Alignment.center,
          trailing: IconButton.ghost(
            size: ButtonSize.small,
            icon: const Icon(SonolythIcons.close),
            onPressed: () {
              overlay.close();
            },
          ),
        ),
      );
    },
  );
}

class TrackPresentationActionsSection extends HookConsumerWidget {
  const TrackPresentationActionsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final options = TrackPresentationOptions.of(context);

    final downloader = ref.read(downloadManagerProvider.notifier);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final historyNotifier = ref.watch(playbackHistoryActionsProvider);

    final state = ref.watch(presentationStateProvider(options.collection));
    final notifier =
        ref.watch(presentationStateProvider(options.collection).notifier);
    final selectedTracks = state.selectedTracks;

    final isUserPlaylist = useIsUserPlaylist(ref, options.collectionId);
    final favoritePlaylistsNotifier =
        ref.read(metadataPluginSavedPlaylistsProvider.notifier);

    Future<void> actionDownloadTracks({
      required BuildContext context,
      required List<SonolythTrackObject> tracks,
      required String action,
      String? collectionUrl,
      String? collectionName,
    }) async {
      final fullTrackObjects =
          tracks.whereType<SonolythFullTrackObject>().toList();
      downloader.addAllToQueue(
        fullTrackObjects,
        collectionUrl: collectionUrl,
        collectionName: collectionName,
      );
      notifier.deselectAllTracks();
      if (!context.mounted) return;
      showToastForAction(context, action, fullTrackObjects.length);
    }

    return AdaptivePopSheetList(
      tooltip: context.l10n.more_actions,
      headings: [
        Text(
          context.l10n.more_actions,
          style: context.theme.typography.large,
        ),
      ],
      onSelected: (action) async {
        var tracks = selectedTracks;
        final isWholeCollectionAction = selectedTracks.isEmpty;

        if (isWholeCollectionAction) {
          tracks = await options.pagination.onFetchAll();

          notifier.selectAllTracks();
        }

        if (!context.mounted) return;

        switch (action) {
          case "download":
            await actionDownloadTracks(
              context: context,
              tracks: tracks,
              action: action,
              collectionUrl: isWholeCollectionAction ? options.shareUrl : null,
              collectionName: options.title,
            );
            break;
          case "add-to-playlist":
            {
              if (context.mounted) {
                final worked = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return PlaylistAddTrackDialog(
                      openFromPlaylist: options.collectionId,
                      tracks: tracks.toList(),
                    );
                  },
                );

                // Always leave selection mode, even when the dialog was
                // dismissed — matching the other action branches.
                notifier.deselectAllTracks();
                if (!context.mounted || worked != true) return;
                showToastForAction(context, action, tracks.length);
              }
              break;
            }
          case "play-next":
            {
              playlistNotifier.addTracksAtFirst(tracks);
              playlistNotifier.addCollection(options.collectionId);
              if (options.collection is SonolythSimpleAlbumObject) {
                historyNotifier.addAlbums(
                    [options.collection as SonolythSimpleAlbumObject]);
              } else {
                historyNotifier.addPlaylists(
                    [options.collection as SonolythSimplePlaylistObject]);
              }
              notifier.deselectAllTracks();
              if (!context.mounted) return;
              showToastForAction(context, action, tracks.length);
              break;
            }
          case "add-to-queue":
            {
              playlistNotifier.addTracks(tracks);
              playlistNotifier.addCollection(options.collectionId);
              if (options.collection is SonolythSimpleAlbumObject) {
                historyNotifier.addAlbums(
                    [options.collection as SonolythSimpleAlbumObject]);
              } else {
                historyNotifier.addPlaylists(
                    [options.collection as SonolythSimplePlaylistObject]);
              }
              notifier.deselectAllTracks();
              if (!context.mounted) return;
              showToastForAction(context, action, tracks.length);
              break;
            }
          case "remove-from-playlist":
            {
              final removed = [...tracks];
              final confirmed = await showPromptDialog(
                context: context,
                title: context.l10n.remove_from_playlist,
                message: context.l10n.are_you_sure,
                okText: context.l10n.remove_from_playlist,
              );
              if (!confirmed) {
                notifier.deselectAllTracks();
                break;
              }
              // Optimistic local drop, then the backend removal + invalidation.
              notifier.deselectAllTracks();
              for (final track in removed) {
                notifier.removeTrack(track);
              }
              await favoritePlaylistsNotifier.removeTracks(
                options.collectionId,
                removed.map((t) => t.id).toList(),
              );
              if (!context.mounted) return;
              showToastForAction(context, action, removed.length);
              break;
            }
          default:
        }
      },
      icon: const Icon(SonolythIcons.moreVertical),
      variance: ButtonVariance.outline,
      items: (context) => [
        AdaptiveMenuButton(
          value: "download",
          leading: const Icon(SonolythIcons.download),
          child: selectedTracks.isEmpty ||
                  selectedTracks.length == options.tracks.length
              ? Text(
                  context.l10n.download_all,
                )
              : Text(
                  context.l10n.download_count(selectedTracks.length),
                ),
        ),
        AdaptiveMenuButton(
          value: "add-to-playlist",
          leading: const Icon(SonolythIcons.playlistAdd),
          child: selectedTracks.isEmpty ||
                  selectedTracks.length == options.tracks.length
              ? Text(
                  context.l10n.add_all_to_playlist,
                )
              : Text(
                  context.l10n.add_count_to_playlist(selectedTracks.length),
                ),
        ),
        AdaptiveMenuButton(
          value: "add-to-queue",
          leading: const Icon(SonolythIcons.queueAdd),
          child: selectedTracks.isEmpty ||
                  selectedTracks.length == options.tracks.length
              ? Text(
                  context.l10n.add_all_to_queue,
                )
              : Text(
                  context.l10n.add_count_to_queue(selectedTracks.length),
                ),
        ),
        AdaptiveMenuButton(
          value: "play-next",
          leading: const Icon(SonolythIcons.lightning),
          child: selectedTracks.isEmpty ||
                  selectedTracks.length == options.tracks.length
              ? Text(
                  context.l10n.play_all_next,
                )
              : Text(
                  context.l10n.play_count_next(selectedTracks.length),
                ),
        ),
        // Bulk removal for the user's own playlists — select tracks, then
        // remove them all at once. Only meaningful with an active selection.
        if (isUserPlaylist && selectedTracks.isNotEmpty)
          AdaptiveMenuButton(
            value: "remove-from-playlist",
            leading: const Icon(SonolythIcons.trash),
            child: Text(context.l10n.remove_from_playlist),
          ),
      ],
    );
  }
}
