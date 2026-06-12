import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/logger/logger.dart';

import 'package:sonolyth/utils/platform.dart';

class AnonymousFallback extends ConsumerWidget {
  final Widget? child;
  const AnonymousFallback({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context, ref) {
    final isLoggedIn = ref.watch(metadataPluginAuthenticatedProvider);
    final pluginConfig = ref
        .watch(metadataPluginsProvider)
        .asData
        ?.value
        .defaultMetadataPluginConfig;

    if (isLoggedIn.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isLoggedIn.asData?.value == true && child != null) return child!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: [
          Undraw(
            illustration: kIsMobile
                ? UndrawIllustration.accessDenied
                : UndrawIllustration.secureLogin,
            height: 200 * context.theme.scaling,
            color: context.theme.colorScheme.primary,
          ),
          Text(context.l10n.not_logged_in),
          Button.primary(
            leading: const Icon(SonolythIcons.login),
            child: Text(
              pluginConfig != null
                  ? context.l10n.sign_in_to_provider(pluginConfig.name)
                  : context.l10n.login,
            ),
            // Launch the provider's sign-in flow right here instead of
            // dropping the user on the settings page to find it themselves.
            onPressed: () async {
              try {
                final plugin = await ref.read(metadataPluginProvider.future);
                if (plugin == null) {
                  // No provider installed — settings is genuinely the place.
                  if (context.mounted) {
                    context.navigateTo(const SettingsMetadataProviderRoute());
                  }
                  return;
                }
                await plugin.auth.authenticate();
              } catch (e, stack) {
                AppLogger.reportError(e, stack);
              }
            },
          ),
        ],
      ),
    );
  }
}
