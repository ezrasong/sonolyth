import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' show ListTile;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/dialogs/prompt_dialog.dart';
import 'package:sonolyth/modules/settings/section_card_with_heading.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/scrobbler/scrobbler.dart';

class SettingsAccountSection extends HookConsumerWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(context, ref) {
    final scrobbler = ref.watch(scrobblerProvider);

    return SectionCardWithHeading(
      heading: context.l10n.account,
      children: [
        ListTile(
          leading: const Icon(SonolythIcons.extensions),
          title: Text(context.l10n.plugins),
          subtitle: Text(context.l10n.configure_plugins),
          onTap: () {
            context.pushRoute(const SettingsMetadataProviderRoute());
          },
          trailing: const Icon(SonolythIcons.angleRight),
        ),
        if (scrobbler.asData?.value == null)
          ListTile(
            leading: const Icon(SonolythIcons.music),
            title: Text(context.l10n.audio_scrobblers),
            subtitle: Text(context.l10n.audio_scrobblers_description),
            onTap: () {
              context.pushRoute(const SettingsScrobblingRoute());
            },
            trailing: const Icon(SonolythIcons.angleRight),
          )
        else
          ListTile(
            leading: const Icon(SonolythIcons.lastFm),
            title: Text(context.l10n.disconnect_lastfm),
            trailing: Button.destructive(
              onPressed: () async {
                final confirmed = await showPromptDialog(
                  context: context,
                  title: context.l10n.disconnect_lastfm,
                  message: context.l10n.disconnect_lastfm_confirmation,
                  okText: context.l10n.disconnect,
                  destructive: true,
                );
                if (!confirmed) return;
                await ref.read(scrobblerProvider.notifier).logout();
              },
              child: Text(context.l10n.disconnect),
            ),
          ),
      ],
    );
  }
}
