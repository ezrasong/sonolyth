import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/adaptive/adaptive_pop_sheet_list.dart';
import 'package:sonolyth/components/dialogs/playlist_add_track_dialog.dart';
import 'package:sonolyth/components/track_presentation/presentation_props.dart';
import 'package:sonolyth/components/track_presentation/presentation_state.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/provider/history/history.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';

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

    ref.watch(downloadManagerProvider);
    final downloader = ref.watch(downloadManagerProvider.notifier);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final historyNotifier = ref.watch(playbackHistoryActionsProvider);

    final state = ref.watch(presentationStateProvider(options.collection));
    final notifier =
        ref.watch(presentationStateProvider(options.collection).notifier);
    final selectedTracks = state.selectedTracks;

    Future<void> actionDownloadTracks({
      required BuildContext context,
      required List<SonolythTrackObject> tracks,
      required String action,
      String? collectionUrl,
    }) async {
      final fullTrackObjects =
          tracks.whereType<SonolythFullTrackObject>().toList();
      downloader.addAllToQueue(
        fullTrackObjects,
        collectionUrl: collectionUrl,
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
          default:
        }

        if (!context.mounted) return;
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
      ],
    );
  }
}
