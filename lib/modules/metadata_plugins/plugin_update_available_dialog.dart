import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/markdown/markdown.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';

class MetadataPluginUpdateAvailableDialog extends HookConsumerWidget {
  final PluginConfiguration plugin;
  final PluginUpdateAvailable update;
  const MetadataPluginUpdateAvailableDialog({
    super.key,
    required this.plugin,
    required this.update,
  });

  @override
  Widget build(BuildContext context, ref) {
    final isUpdating = useState(false);

    final showErrorSnackbar = useCallback(
      (BuildContext context, String message) {
        showToast(
            context: context,
            builder: (context, overlay) {
              return SurfaceCard(
                child: Basic(
                  leading: const Icon(SonolythIcons.error, color: Colors.red),
                  title: Text(message),
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
            });
      },
      [],
    );

    return AlertDialog(
      title: Text(context.l10n.plugin_update_available),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            context.l10n
                .plugin_name_version_available(plugin.name, update.version),
          ),
          if (update.changelog != null && update.changelog!.isNotEmpty)
            AppMarkdown(
              data: '### Changelog: \n\n${update.changelog}',
            ),
        ],
      ),
      actions: [
        SecondaryButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.dismiss),
        ),
        PrimaryButton(
          enabled: !isUpdating.value,
          onPressed: () async {
            isUpdating.value = true;
            try {
              await ref
                  .read(metadataPluginsProvider.notifier)
                  .updatePlugin(plugin, update);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              if (context.mounted) {
                showErrorSnackbar(context, e.toString());
              }
            } finally {
              if (context.mounted) {
                isUpdating.value = false;
              }
            }
          },
          child: Text(context.l10n.update),
        ),
      ],
    );
  }
}
