import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/routes.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/ui/button_tile.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/track_options/track_options_provider.dart';

/// [track] must be a [SonolythFullTrackObject] or [SonolythLocalTrackObject]
class TrackOptions extends HookConsumerWidget {
  final SonolythTrackObject track;
  final bool userPlaylist;
  final String? playlistId;
  final Widget? icon;
  final VoidCallback? onTapItem;

  const TrackOptions({
    super.key,
    required this.track,
    this.userPlaylist = false,
    this.playlistId,
    this.icon,
    this.onTapItem,
  }) : assert(
          track is SonolythFullTrackObject || track is SonolythLocalTrackObject,
          "Track must be a SonolythFullTrackObject, SonolythLocalTrackObject",
        );

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.of(context);

    final trackOptionActions = ref.watch(trackOptionActionsProvider(track));
    final (
      :isBlacklisted,
      :isInDownloadQueue,
      :isInQueue,
      :isActiveTrack,
      :isAuthenticated,
      :isLiked,
      :downloadTask
    ) = ref.watch(trackOptionsStateProvider(track));
    final isLocalTrack = track is SonolythLocalTrackObject;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.delete,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.trash),
            title: Text(context.l10n.delete),
          ),
        if (mediaQuery.smAndDown && !isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.album,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.album),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.go_to_album),
                Text(
                  track.album.name,
                  style: context.theme.typography.xSmall,
                ),
              ],
            ),
          ),
        if (!isInQueue) ...[
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.addToQueue,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.queueAdd),
            title: Text(context.l10n.add_to_queue),
          ),
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.playNext,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.lightning),
            title: Text(context.l10n.play_next),
          ),
        ] else
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.removeFromQueue,
                playlistId,
              );
              onTapItem?.call();
            },
            enabled: !isActiveTrack,
            leading: const Icon(SonolythIcons.queueRemove),
            title: Text(context.l10n.remove_from_queue),
          ),
        if (isAuthenticated && !isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.favorite,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: isLiked
                ? const Icon(
                    SonolythIcons.heartFilled,
                    color: Colors.pink,
                  )
                : const Icon(SonolythIcons.heart),
            title: Text(
              isLiked
                  ? context.l10n.remove_from_favorites
                  : context.l10n.save_as_favorite,
            ),
          ),
        if (isAuthenticated && !isLocalTrack) ...[
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.startRadio,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.radio),
            title: Text(context.l10n.start_a_radio),
          ),
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.addToPlaylist,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.playlistAdd),
            title: Text(context.l10n.add_to_playlist),
          ),
        ],
        if (userPlaylist && isAuthenticated && !isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.removeFromPlaylist,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.removeFilled),
            title: Text(context.l10n.remove_from_playlist),
          ),
        if (!isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.download,
                playlistId,
              );
              onTapItem?.call();
            },
            enabled: !isInDownloadQueue,
            leading: isInDownloadQueue
                ? StreamBuilder(
                    stream: downloadTask?.downloadedBytesStream,
                    builder: (context, snapshot) {
                      final progress = downloadTask?.totalSizeBytes == null ||
                              downloadTask?.totalSizeBytes == 0
                          ? 0
                          : (snapshot.data ?? 0) /
                              downloadTask!.totalSizeBytes!;
                      return CircularProgressIndicator(
                        value: progress.toDouble(),
                      );
                    },
                  )
                : const Icon(SonolythIcons.download),
            title: Text(context.l10n.download_track),
          ),
        if (!isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.blacklist,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: Icon(
              SonolythIcons.playlistRemove,
              color: isBlacklisted != true ? Colors.red[400] : null,
            ),
            title: Text(
              isBlacklisted == true
                  ? context.l10n.remove_from_blacklist
                  : context.l10n.add_to_blacklist,
              style: TextStyle(
                color: isBlacklisted != true ? Colors.red[400] : null,
              ),
            ),
          ),
        if (!isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.share,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.share),
            title: Text(context.l10n.share),
          ),
        if (!isLocalTrack)
          ButtonTile(
            style: ButtonVariance.menu,
            onPressed: () async {
              await trackOptionActions.action(
                rootNavigatorKey.currentContext!,
                TrackOptionValue.details,
                playlistId,
              );
              onTapItem?.call();
            },
            leading: const Icon(SonolythIcons.info),
            title: Text(context.l10n.details),
          ),
      ],
    );
  }
}
