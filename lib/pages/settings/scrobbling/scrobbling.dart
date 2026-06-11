import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart'
    show ListTile, ListTileTheme, ListTileThemeData, Material, MaterialType;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
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
          shape: RoundedRectangleBorder(
            borderRadius: context.theme.borderRadiusLg,
            side: BorderSide(
              color: context.theme.colorScheme.border,
              width: .5,
            ),
          ),
          textColor: context.theme.colorScheme.foreground,
          iconColor: context.theme.colorScheme.foreground,
          selectedColor: context.theme.colorScheme.accent,
          subtitleTextStyle: context.theme.typography.xSmall,
        ),
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            headers: [TitleBar(title: Text(context.l10n.scrobbling))],
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                Card(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(SonolythIcons.lastFm, color: Colors.red),
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
                        : Button.secondary(
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
