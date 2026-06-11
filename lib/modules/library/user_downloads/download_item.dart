import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/links/artist_link.dart';
import 'package:sonolyth/components/ui/button_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/services/spotiflac/native_flac_downloader.dart';

class DownloadItem extends HookConsumerWidget {
  final DownloadTask task;
  const DownloadItem({
    super.key,
    required this.task,
  });

  String _errorHeadline(BuildContext context) {
    return switch (task.errorCode) {
      DownloadErrorCode.rateLimited =>
        context.l10n.download_error_rate_limited,
      DownloadErrorCode.noProviders =>
        context.l10n.download_error_no_providers,
      DownloadErrorCode.noSource => context.l10n.download_error_no_source,
      DownloadErrorCode.emptyStream =>
        context.l10n.download_error_empty_stream,
      DownloadErrorCode.httpStatus =>
        context.l10n.download_error_http(task.errorMessage ?? "?"),
      DownloadErrorCode.timeout => context.l10n.download_error_timeout,
      DownloadErrorCode.noConnection =>
        context.l10n.download_error_no_connection,
      DownloadErrorCode.network => context.l10n.download_error_network,
      DownloadErrorCode.unknown ||
      null =>
        task.errorMessage ?? context.l10n.download_error_unknown,
    };
  }

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final downloadManager = ref.watch(downloadManagerProvider.notifier);

    return ButtonTile(
      style: ButtonVariance.ghost,
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: UniversalImage(
            height: 40,
            width: 40,
            path: task.track.album.images.asUrlString(
              placeholder: ImagePlaceholder.albumArt,
            ),
          ),
        ),
      ),
      title: Text(
        task.track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRect(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 20),
              child: ArtistLink(
                artists: task.track.artists,
                mainAxisAlignment: WrapAlignment.start,
                onOverflowArtistClick: () {
                  context.navigateTo(TrackRoute(trackId: task.track.id));
                },
              ),
            ),
          ),
          if (task.status == DownloadStatus.failed &&
              (task.errorCode != null || task.errorMessage != null))
            Tooltip(
              tooltip: TooltipContainer(
                child: Text(task.errorMessage ?? _errorHeadline(context)),
              ).call,
              child: Text(
                _errorHeadline(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.destructive,
                ),
              ),
            ),
        ],
      ),
      trailing: switch (task.status) {
        DownloadStatus.downloading => StreamBuilder(
            stream: task.downloadedBytesStream,
            builder: (context, asyncSnapshot) {
              final progress =
                  task.totalSizeBytes == null || task.totalSizeBytes == 0
                      ? 0.0
                      : (asyncSnapshot.data ?? 0) / task.totalSizeBytes!;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${(progress * 100).round()}%",
                    style: theme.typography.xSmall,
                  ),
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.ghost(
                    size: ButtonSize.small,
                    icon: const Icon(SonolythIcons.close),
                    onPressed: () {
                      downloadManager.cancel(task.track);
                    },
                  ),
                ],
              );
            },
          ),
        DownloadStatus.failed || DownloadStatus.canceled => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                task.status == DownloadStatus.failed
                    ? SonolythIcons.error
                    : SonolythIcons.close,
                size: 18,
                color: task.status == DownloadStatus.failed
                    ? theme.colorScheme.destructive
                    : theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 4),
              IconButton.ghost(
                size: ButtonSize.small,
                icon: const Icon(SonolythIcons.refresh),
                onPressed: () {
                  downloadManager.retry(task.track);
                },
              ),
            ],
          ),
        DownloadStatus.completed =>
          Icon(SonolythIcons.done, color: theme.colorScheme.primary),
        DownloadStatus.queued => IconButton.ghost(
            size: ButtonSize.small,
            icon: const Icon(SonolythIcons.close),
            onPressed: () {
              downloadManager.cancel(task.track);
            },
          ),
      },
    );
  }
}
