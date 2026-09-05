import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/ui/zenith_popup_card.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/button/back_button.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/logs/logs_provider.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/logger/log_file_trimmer.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sonolyth/components/fallbacks/zenith_illustration.dart';

@RoutePage()
class LogsPage extends HookConsumerWidget {
  static const name = "logs";

  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();

    final logsQuery = ref.watch(logsProvider);

    return Scaffold(
      headers: [
        SafeArea(
          bottom: false,
          child: TitleBar(
            title: Text(context.l10n.logs),
            leading: const [BackButton()],
            trailing: [
              ZenithTooltip(
                message: context.l10n.copy_to_clipboard,
                child: IconButton.ghost(
                  icon: const Icon(SonolythIcons.clipboard, size: 16),
                  onPressed: () async {
                    final logsSnapshot = await ref.read(logsProvider.future);

                    await Clipboard.setData(
                      ClipboardData(text: clipboardTail(logsSnapshot)),
                    );
                    if (context.mounted) {
                      showToast(
                        context: context,
                        location: ToastLocation.topRight,
                        builder: (context, overlay) {
                          return SurfaceCard(
                            child: Basic(
                              title: Text(context.l10n.copied_to_clipboard("")),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
              ZenithTooltip(
                message: context.l10n.clear_logs,
                child: IconButton.ghost(
                  icon: const Icon(
                    SonolythIcons.trash,
                    size: 16,
                  ),
                  onPressed: () async {
                    final accepted = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.l10n.are_you_sure),
                        actions: [
                          Button.ghost(
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

                    await AppLogger.clearLogs();

                    ref.invalidate(logsProvider);
                  },
                ),
              )
            ],
          ),
        )
      ],
      child: SafeArea(
        child: switch (logsQuery) {
          AsyncData(:final value) => InterScrollbar(
              controller: controller,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                controller: controller,
                child: ZenithPopupCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(value),
                ),
              ),
            ),
          AsyncError(:final error) => switch (error) {
              StateError() => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ZenithIllustration(
                      illustration: UndrawIllustration.noData,
                      height: 200 * context.theme.scaling,
                      width: 200 * context.theme.scaling,
                    ),
                    Text(context.l10n.no_logs_found).muted().small(),
                  ],
                ),
              _ => Center(child: Text(error.toString())),
            },
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
