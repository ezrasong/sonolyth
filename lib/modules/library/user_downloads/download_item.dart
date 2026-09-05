import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/image/universal_image.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/services/spotiflac/native_flac_downloader.dart';

/// One row of the download queue, in the Proxima Zenith idiom: a flat row with
/// square art, a monochrome status affordance, and — while downloading — a
/// hairline progress rule spanning the full row width. Zenith expresses
/// progress as a thin line (its seekbar), never as a spinner or filled pill.
class DownloadItem extends HookConsumerWidget {
  final DownloadTask task;
  const DownloadItem({
    super.key,
    required this.task,
  });

  String _errorHeadline(BuildContext context) {
    return switch (task.errorCode) {
      DownloadErrorCode.rateLimited => context.l10n.download_error_rate_limited,
      DownloadErrorCode.noProviders => context.l10n.download_error_no_providers,
      DownloadErrorCode.needsVerification =>
        "Lossless access not verified — Settings > Playback",
      DownloadErrorCode.noSource => context.l10n.download_error_no_source,
      DownloadErrorCode.emptyStream => context.l10n.download_error_empty_stream,
      DownloadErrorCode.httpStatus =>
        context.l10n.download_error_http(task.errorMessage ?? "?"),
      DownloadErrorCode.timeout => context.l10n.download_error_timeout,
      DownloadErrorCode.noConnection =>
        context.l10n.download_error_no_connection,
      DownloadErrorCode.unknown ||
      DownloadErrorCode.network ||
      null =>
        task.errorMessage ?? context.l10n.download_error_unknown,
    };
  }

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final downloadManager = ref.watch(downloadManagerProvider.notifier);
    final isFailed = task.status == DownloadStatus.failed;

    final artists = task.track.artists.map((a) => a.name).join(", ");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Square art, tight corners — Zenith treats artwork as a panel,
              // not a rounded chip.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: UniversalImage(
                  height: 44,
                  width: 44,
                  path: task.track.album.images.asUrlString(
                    placeholder: ImagePlaceholder.albumArt,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      context.navigateTo(TrackRoute(trackId: task.track.id)),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.small.copyWith(
                          color: scheme.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFailed ? _errorHeadline(context) : artists,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          color: isFailed
                              ? scheme.destructive
                              : scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _Trailing(task: task, downloadManager: downloadManager),
            ],
          ),
          if (task.status == DownloadStatus.downloading)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: StreamBuilder(
                stream: task.downloadedBytesStream,
                builder: (context, snapshot) {
                  final total = task.totalSizeBytes;
                  final progress = total == null || total == 0
                      ? null
                      : ((snapshot.data ?? 0) / total).clamp(0.0, 1.0);
                  // A 2px rule, full bleed across the row.
                  return SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(value: progress),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Status affordance. Every state reads as a word or a single glyph in the
/// monochrome ramp — no coloured badges, which would break the achromatic rule.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.task, required this.downloadManager});

  final DownloadTask task;
  final DownloadManagerNotifier downloadManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (task.status) {
      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder(
              stream: task.downloadedBytesStream,
              builder: (context, snapshot) {
                final total = task.totalSizeBytes;
                final pct = total == null || total == 0
                    ? null
                    : (((snapshot.data ?? 0) / total) * 100).round();
                return Text(
                  pct == null ? "--" : "$pct%",
                  style: theme.typography.xSmall.copyWith(
                    color: scheme.mutedForeground,
                    // Tabular figures stop the row twitching as digits change.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            ZenithTooltip(
              message: context.l10n.cancel_download,
              child: IconButton.ghost(
                size: ButtonSize.small,
                icon: const Icon(SonolythIcons.close),
                onPressed: () => downloadManager.cancel(task.track),
              ),
            ),
          ],
        );
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return ZenithTooltip(
          message: context.l10n.retry_download,
          child: IconButton.ghost(
            size: ButtonSize.small,
            icon: const Icon(SonolythIcons.refresh),
            onPressed: () => downloadManager.retry(task.track),
          ),
        );
      case DownloadStatus.completed:
        return Icon(
          SonolythIcons.done,
          size: 18,
          color: scheme.foreground,
        );
      case DownloadStatus.queued:
        return ZenithTooltip(
          message: context.l10n.cancel_download,
          child: IconButton.ghost(
            size: ButtonSize.small,
            icon: const Icon(SonolythIcons.close),
            onPressed: () => downloadManager.cancel(task.track),
          ),
        );
    }
  }
}
