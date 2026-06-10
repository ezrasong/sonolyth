import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' as material;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/modules/getting_started/blur_card.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';

class GettingStartedScreenSupportSection extends HookConsumerWidget {
  const GettingStartedScreenSupportSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
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
                      SonolythIcons.extensions,
                      color: material.Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text("Set up music sources").semiBold(),
                  ],
                ),
                const Gap(16),
                Text(
                  "Install a provider to search, stream, and download music.",
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
                Button.primary(
                  leading: const Icon(SonolythIcons.extensions),
                  onPressed: () async {
                    await KVStoreService.setDoneGettingStarted(true);
                    if (context.mounted) {
                      context.pushRoute(const SettingsMetadataProviderRoute());
                    }
                  },
                  child: Text(context.l10n.install_a_metadata_provider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
