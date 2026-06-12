import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/modules/getting_started/blur_card.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';

class GettingStartedScreenSupportSection extends HookConsumerWidget {
  const GettingStartedScreenSupportSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final pluginConfig = ref
        .watch(metadataPluginsProvider)
        .asData
        ?.value
        .defaultMetadataPluginConfig;
    final providerName = pluginConfig?.name;
    final signingIn = useState(false);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlurCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      SonolythIcons.login,
                      color: material.Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      providerName != null
                          ? context.l10n.sign_in_to_provider(providerName)
                          : context.l10n.set_up_music_sources,
                    ).semiBold(),
                  ],
                ),
                const Gap(16),
                Text(
                  providerName != null
                      ? context.l10n.sign_in_to_provider_description(
                          providerName,
                        )
                      : context.l10n.set_up_music_sources_description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.mutedForeground,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Gap(48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The default provider ships with the app, so first-run setup
                // is just signing in — launch that flow directly instead of
                // sending the user hunting through the settings page.
                Button.primary(
                  leading: signingIn.value
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(SonolythIcons.login),
                  onPressed: signingIn.value
                      ? null
                      : () async {
                          await KVStoreService.setDoneGettingStarted(true);
                          final plugin =
                              await ref.read(metadataPluginProvider.future);
                          if (plugin == null) {
                            if (context.mounted) {
                              context.replaceRoute(
                                const SettingsMetadataProviderRoute(),
                              );
                            }
                            return;
                          }
                          try {
                            signingIn.value = true;
                            await plugin.auth.authenticate();
                            if (context.mounted) {
                              context.replaceRoute(const HomeRoute());
                            }
                          } catch (e, stack) {
                            AppLogger.reportError(e, stack);
                          } finally {
                            if (context.mounted) {
                              signingIn.value = false;
                            }
                          }
                        },
                  child: Text(
                    providerName != null
                        ? context.l10n.sign_in_to_provider(providerName)
                        : context.l10n.login,
                  ),
                ),
                const Gap(8),
                Button.ghost(
                  leading: const Icon(SonolythIcons.extensions),
                  onPressed: () async {
                    await KVStoreService.setDoneGettingStarted(true);
                    if (context.mounted) {
                      context.pushRoute(const SettingsMetadataProviderRoute());
                    }
                  },
                  child: Text(context.l10n.manage_providers),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
