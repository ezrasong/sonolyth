import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart'
    show ListTile, ListTileTheme, ListTileThemeData, Material, MaterialType;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/modules/settings/section_card_with_heading.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/scrobbler/scrobbler.dart';

@RoutePage()
class SettingsScrobblingPage extends HookConsumerWidget {
  static const name = "settings_scrobbling";

  const SettingsScrobblingPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final scrobbler = ref.watch(scrobblerProvider);
    final isConnected = scrobbler.asData?.value != null;
    final username = scrobbler.asData?.value?.api.username;

    return Material(
      type: MaterialType.transparency,
      child: ListTileTheme(
        data: ListTileThemeData(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 0,
          // `item_bg` — a rounded ripple mask and no stroke, like every
          // other settings row (see `SectionCardWithHeading`).
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              SectionCardWithHeading.rowRadius,
            ),
          ),
          textColor: context.theme.colorScheme.foreground,
          iconColor: context.theme.colorScheme.foreground,
          selectedColor: context.theme.colorScheme.accent,
          // `ItemTextLine2` — 11sp at `textColorPrimary`.
          subtitleTextStyle: zenithTextLine2(context.theme.colorScheme),
        ),
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            headers: [TitleBar(title: Text(context.l10n.scrobbling))],
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // No card: the row sits on the ground, as settings rows do.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(SonolythIcons.lastFm),
                    title: Text(
                      isConnected && username != null
                          ? username
                          : context.l10n.login_with_lastfm,
                    ),
                    subtitle: Text(context.l10n.scrobble_to_lastfm),
                    trailing: isConnected
                        ? Button.destructive(
                            onPressed: () {
                              ref.read(scrobblerProvider.notifier).logout();
                            },
                            child: Text(context.l10n.logout),
                          )
                        : Button(
                            style: zenithPositiveButton(
                              context.theme.colorScheme,
                            ),
                            leading: const Icon(SonolythIcons.lastFm),
                            onPressed: () {
                              context.navigateTo(const LastFMLoginRoute());
                            },
                            child: Text(context.l10n.connect),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
