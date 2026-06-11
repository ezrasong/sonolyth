import 'package:auto_size_text/auto_size_text.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

    final active = downloadQueue
        .where((t) => const [DownloadStatus.queued, DownloadStatus.downloading]
            .contains(t.status))
        .length;
    final failed = downloadQueue
        .where((t) => t.status == DownloadStatus.failed)
        .length;
    final completed = downloadQueue
        .where((t) => t.status == DownloadStatus.completed)
        .length;

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
                          if (completed > 0) "$completed done",
                          if (failed > 0) "$failed failed",
                        ].join(" · "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          color: failed > 0
                              ? Colors.red[400]
                              : theme.colorScheme.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (failed > 0) ...[
                Button.outline(
                  onPressed: downloadManagerNotifier.retryAllFailed,
                  child: const Text("Retry failed"),
                ),
                const SizedBox(width: 8),
              ],
              Button.destructive(
                onPressed: downloadQueue.isEmpty
                    ? null
                    : downloadManagerNotifier.clearAll,
                child: Text(context.l10n.cancel_all),
              ),
            ],
          ),
        ),
        Expanded(
          child: SafeArea(
            child: ListView.builder(
              itemCount: downloadQueue.length,
              padding: const EdgeInsets.only(bottom: 200),
              itemBuilder: (context, index) {
                return DownloadItem(
                  task: downloadQueue.elementAt(index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
