import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/modules/library/user_downloads/download_item.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class UserDownloadsPage extends HookConsumerWidget {
  static const name = 'user_downloads';
  const UserDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final downloadQueue = ref.watch(downloadManagerProvider);
    final downloadManagerNotifier = ref.watch(downloadManagerProvider.notifier);
    final cooldownUntil = ref.watch(downloadCooldownProvider);
    final isPaused = ref.watch(downloadsPausedProvider);

    final active = downloadQueue
        .where((t) => const [DownloadStatus.queued, DownloadStatus.downloading]
            .contains(t.status))
        .length;
    final failed =
        downloadQueue.where((t) => t.status == DownloadStatus.failed).length;
    final completed =
        downloadQueue.where((t) => t.status == DownloadStatus.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoSizeText(
                      context.l10n.currently_downloading(active),
                      maxLines: 1,
                    ).semiBold(),
                    if (failed > 0 || completed > 0)
                      Text(
                        [
                          if (completed > 0) context.l10n.count_done(completed),
                          if (failed > 0) context.l10n.count_failed(failed),
                        ].join(" · "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          color: failed > 0
                              ? theme.colorScheme.destructive
                              : theme.colorScheme.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (active > 0 || isPaused) ...[
                Tooltip(
                  tooltip: TooltipContainer(
                    child: Text(
                      isPaused
                          ? context.l10n.resume_downloads
                          : context.l10n.pause_downloads,
                    ),
                  ).call,
                  child: IconButton.outline(
                    icon: Icon(
                      isPaused ? SonolythIcons.play : SonolythIcons.pause,
                    ),
                    onPressed: isPaused
                        ? downloadManagerNotifier.resumeQueue
                        : downloadManagerNotifier.pauseQueue,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (failed > 0) ...[
                Button.outline(
                  onPressed: downloadManagerNotifier.retryAllFailed,
                  child: Text(context.l10n.retry_failed),
                ),
                const SizedBox(width: 8),
              ],
              Button.destructive(
                onPressed: downloadQueue.isEmpty
                    ? null
                    : () async {
                        final accepted = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.l10n.cancel_all),
                            content: Text(context.l10n.are_you_sure),
                            actions: [
                              Button.outline(
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                                child: Text(context.l10n.decline),
                              ),
                              Button.destructive(
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                                child: Text(context.l10n.accept),
                              ),
                            ],
                          ),
                        );

                        if (accepted != true) return;

                        downloadManagerNotifier.clearAll();
                      },
                child: Text(context.l10n.cancel_all),
              ),
            ],
          ),
        ),
        if (isPaused)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: theme.borderRadiusMd,
              ),
              child: Row(
                children: [
                  const Icon(SonolythIcons.pause, size: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.downloads_paused,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.xSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (cooldownUntil != null && !isPaused)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
            child: StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, _) {
                final remaining = cooldownUntil.difference(DateTime.now());
                if (remaining.isNegative) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.muted,
                    borderRadius: theme.borderRadiusMd,
                  ),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n
                              .download_rate_limit_paused(remaining.inSeconds),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.xSmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: SafeArea(
            child: downloadQueue.isEmpty
                // Center: the page column is start-aligned, which otherwise
                // pins this block (sized by the illustration) to the left.
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Undraw(
                          illustration: UndrawIllustration.empty,
                          height: 200 * theme.scaling,
                          color: theme.colorScheme.primary,
                        ),
                        const Gap(10),
                        Text(
                          context.l10n.nothing_found,
                          textAlign: TextAlign.center,
                        ).muted().small(),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: downloadQueue.length,
                    padding: const EdgeInsets.only(bottom: 200),
                    itemBuilder: (context, index) {
                      return DownloadItem(
                        task: downloadQueue[index],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
