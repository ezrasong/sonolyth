import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/dialogs/prompt_dialog.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/modules/library/user_downloads/download_item.dart';
import 'package:sonolyth/provider/download_manager_provider.dart';
import 'package:sonolyth/collections/zenith_theme.dart';

@RoutePage()
class UserDownloadsPage extends HookConsumerWidget {
  static const name = 'user_downloads';
  const UserDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
        // Zenith's top counter: the number carries the weight, the label sits
        // quiet beneath it. Generous top margin (the skin uses 35dp) and no
        // container — the count IS the header.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$active",
                      // A figure, not a heading, so it keeps its thin
                      // weight — but it still sits under the skin's 29sp
                      // ceiling like everything else.
                      style: zenithPageTitle(scheme).copyWith(
                        height: 1,
                        fontWeight: FontWeight.w300,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.currently_downloading(active).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.xSmall.copyWith(
                        color: scheme.mutedForeground,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (failed > 0 || completed > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (completed > 0) context.l10n.count_done(completed),
                          if (failed > 0) context.l10n.count_failed(failed),
                        ].join("  ·  "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          color: failed > 0
                              ? scheme.destructive
                              : scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (active > 0 || isPaused)
                ZenithTooltip(
                  message: isPaused
                      ? context.l10n.resume_downloads
                      : context.l10n.pause_downloads,
                  child: IconButton.ghost(
                    icon: Icon(
                      isPaused ? SonolythIcons.play : SonolythIcons.pause,
                    ),
                    onPressed: isPaused
                        ? downloadManagerNotifier.resumeQueue
                        : downloadManagerNotifier.pauseQueue,
                  ),
                ),
              if (failed > 0)
                ZenithTooltip(
                  message: context.l10n.retry_failed_downloads,
                  child: IconButton.ghost(
                    icon: const Icon(SonolythIcons.refresh),
                    onPressed: downloadManagerNotifier.retryAllFailed,
                  ),
                ),
              ZenithTooltip(
                message: context.l10n.clear_download_queue,
                child: IconButton.ghost(
                  icon: const Icon(SonolythIcons.close),
                  onPressed: downloadQueue.isEmpty
                      ? null
                      : () async {
                          // Use the shared prompt dialog (bounded width +
                          // centred text); a bare AlertDialog with a short
                          // title/content right-hugs them against the buttons.
                          final accepted = await showPromptDialog(
                            context: context,
                            title: context.l10n.cancel_all,
                            message: context.l10n.are_you_sure,
                            okText: context.l10n.accept,
                            cancelText: context.l10n.decline,
                            destructive: true,
                          );

                          if (!accepted) return;

                          downloadManagerNotifier.clearAll();
                        },
                ),
              ),
            ],
          ),
        ),
        // Hairline rule instead of a card edge — Zenith separates with a 13%
        // white line, never with elevation.
        Divider(color: scheme.border, height: 1),
        if (isPaused)
          _StatusStrip(
            icon: const Icon(SonolythIcons.pause, size: 13),
            label: context.l10n.downloads_paused,
          ),
        if (cooldownUntil != null && !isPaused)
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, _) {
              final remaining = cooldownUntil.difference(DateTime.now());
              if (remaining.isNegative) return const SizedBox.shrink();
              return _StatusStrip(
                icon: const SizedBox.square(
                  dimension: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                label: context.l10n
                    .download_rate_limit_paused(remaining.inSeconds),
              );
            },
          ),
        Expanded(
          child: SafeArea(
            child: downloadQueue.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // A single dimmed glyph reads as intentional
                          // emptiness; the old illustration was the last
                          // chromatic element on the page.
                          Icon(
                            SonolythIcons.download,
                            size: 40,
                            color: scheme.mutedForeground.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const Gap(14),
                          Text(
                            context.l10n.nothing_found,
                            textAlign: TextAlign.center,
                            style: theme.typography.small.copyWith(
                              color: scheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: downloadQueue.length,
                    padding: const EdgeInsets.only(top: 6, bottom: 200),
                    separatorBuilder: (context, _) => Divider(
                      color: scheme.border.withValues(alpha: 0.5),
                      height: 1,
                      indent: 74,
                    ),
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

/// Full-width notice strip. Flat, bordered top and bottom, no fill — the
/// Zenith way of interrupting a list without introducing a floating card.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.muted,
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: scheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
