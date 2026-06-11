import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' show ListTile;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonStyle;
import 'package:sonolyth/collections/env.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/modules/settings/section_card_with_heading.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';

class SettingsAboutSection extends HookConsumerWidget {
  const SettingsAboutSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);

    return SectionCardWithHeading(
      heading: context.l10n.about,
      children: [
        if (Env.enableUpdateChecker)
          ListTile(
            leading: const Icon(SonolythIcons.update),
            title: Text(context.l10n.check_for_updates),
            trailing: Switch(
              value: preferences.checkUpdate,
              onChanged: (checked) =>
                  preferencesNotifier.setCheckUpdate(checked),
            ),
          ),
        ListTile(
          leading: const Icon(SonolythIcons.info),
          title: Text(context.l10n.about_spotube),
          trailing: const Icon(SonolythIcons.angleRight),
          onTap: () {
            context.navigateTo(const AboutSonolythRoute());
          },
        )
      ],
    );
  }
}
