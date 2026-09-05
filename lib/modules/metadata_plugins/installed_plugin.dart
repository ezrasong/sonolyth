import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/components/ui/zenith_popup_card.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/official_plugin_owners.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/l10n/l10n.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/metadata_plugins/plugin_update_available_dialog.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/updater/update_checker.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

Map<PluginAbilities, (String, IconData)> validAbilities(
        AppLocalizations l10n) =>
    {
      PluginAbilities.metadata: (l10n.metadata, SonolythIcons.album),
      PluginAbilities.audioSource: (l10n.audio_source, SonolythIcons.music),
    };

class MetadataInstalledPluginItem extends HookConsumerWidget {
  final PluginConfiguration plugin;
  final bool isDefaultMetadata;
  final bool isDefaultAudioSource;
  const MetadataInstalledPluginItem({
    super.key,
    required this.plugin,
    required this.isDefaultMetadata,
    required this.isDefaultAudioSource,
  });

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.sizeOf(context);
    final abilities = validAbilities(context.l10n);

    final metadataPlugin = ref.watch(metadataPluginProvider);
    final audioSourcePlugin = ref.watch(audioSourcePluginProvider);
    final pluginSnapshot = switch ((isDefaultMetadata, isDefaultAudioSource)) {
      (true, _) => metadataPlugin,
      (false, true) => audioSourcePlugin,
      _ => null,
    };

    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);

    final logoFuture = useMemoized(
      () => pluginsNotifier.getLogoPath(plugin),
      [plugin.slug, plugin.version],
    );

    final requiresAuth = (isDefaultMetadata || isDefaultAudioSource) &&
        plugin.abilities.contains(PluginAbilities.authentication);
    final supportsScrobbling = isDefaultMetadata &&
        plugin.abilities.contains(PluginAbilities.scrobbling);

    final isMetadataAuthenticatedSnapshot =
        ref.watch(metadataPluginAuthenticatedProvider);
    final isAudioSourceAuthenticatedSnapshot =
        ref.watch(audioSourcePluginAuthenticatedProvider);
    final isAuthenticated = (isDefaultMetadata &&
            isMetadataAuthenticatedSnapshot.asData?.value == true) ||
        (isDefaultAudioSource &&
            isAudioSourceAuthenticatedSnapshot.asData?.value == true);

    final metadataUpdateAvailable =
        ref.watch(metadataPluginUpdateCheckerProvider);
    final audioSourceUpdateAvailable =
        ref.watch(audioSourcePluginUpdateCheckerProvider);
    final updateAvailable = switch ((isDefaultMetadata, isDefaultAudioSource)) {
      (true, _) => metadataUpdateAvailable,
      (false, true) => audioSourceUpdateAvailable,
      _ => null,
    };
    final hasUpdate = updateAvailable?.asData?.value != null;

    // `popup_bg`: one flat fill at radius 20, no stroke. `Card` drew a border.
    return ZenithPopupCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          FutureBuilder(
            future: logoFuture,
            builder: (context, snapshot) {
              final repoUrl = plugin.repository != null
                  ? Uri.tryParse(plugin.repository!)
                  : null;
              final repoOwner = repoUrl?.pathSegments.firstOrNull;

              final isOfficial = repoUrl?.host == "github.com" &&
                  officialPluginOwners.contains(repoOwner);

              return Basic(
                // A logo is artwork: square (`corners_aa_*` = 0), and its
                // placeholder sits in the `colorAABgColor` well.
                leading: snapshot.hasData
                    ? Image.file(
                        snapshot.data!,
                        width: 36,
                        height: 36,
                      )
                    : Container(
                        height: 36,
                        width: 36,
                        alignment: Alignment.center,
                        color: zenithArtWell(context.theme.colorScheme),
                        child: const Icon(SonolythIcons.plugin),
                      ),
                title: Text(plugin.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(plugin.description),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ability in plugin.abilities)
                          if (abilities.keys.contains(ability))
                            ZenithValueChip(
                              icon: abilities[ability]!.$2,
                              child: Text(abilities[ability]!.$1),
                            ),
                      ],
                    ),
                    if (repoUrl != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isOfficial)
                            ZenithValueChip(
                              icon: SonolythIcons.done,
                              child: Text(context.l10n.official),
                            )
                          else ...[
                            Text(context.l10n.author_name(plugin.author)),
                            // Was white text on a `primary` fill — and in
                            // Zenith `primary` IS white, so the label was
                            // invisible.
                            ZenithValueChip(
                              icon: SonolythIcons.warning,
                              child: Text(context.l10n.third_party),
                            ),
                          ],
                          ZenithValueChip(
                            icon: SonolythIcons.connect,
                            child: Text(repoUrl.host),
                            onPressed: () {
                              launchUrl(repoUrl);
                            },
                          ),
                          ZenithValueChip(
                            child: Text(
                              "${context.l10n.version}: ${plugin.version}",
                            ),
                          ),
                        ],
                      )
                  ],
                ),
                trailing: ZenithTooltip(
                  message: context.l10n.delete,
                  child: IconButton.ghost(
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

                      try {
                        await pluginsNotifier.removePlugin(
                          plugin,
                          clearStorage: true,
                        );
                      } catch (e, stackTrace) {
                        AppLogger.reportError(e, stackTrace);
                        if (context.mounted) {
                          showToast(
                            showDuration: const Duration(seconds: 5),
                            context: context,
                            builder: (context, overlay) {
                              return SurfaceCard(
                                child: Basic(
                                  leading: Icon(
                                    SonolythIcons.error,
                                    color:
                                        context.theme.colorScheme.destructive,
                                  ),
                                  title: Text(
                                    context.l10n.error(e.toString()),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      }
                    },
                    icon: Icon(
                      SonolythIcons.trash,
                      color: context.theme.colorScheme.destructive,
                    ),
                  ),
                ),
              );
            },
          ),
          if ((requiresAuth && !isAuthenticated) ||
              hasUpdate ||
              supportsScrobbling)
            Container(
              // A sunk panel inside the card: the `colorAABgColor` well at
              // `corners_medium`. `secondary` is the card's own colour and
              // would vanish here.
              decoration: BoxDecoration(
                color: zenithArtWell(context.theme.colorScheme),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                spacing: 12,
                children: [
                  if (requiresAuth && !isAuthenticated)
                    Row(
                      spacing: 8,
                      children: [
                        Icon(SonolythIcons.warning,
                            color:
                                Theme.of(context).colorScheme.mutedForeground),
                        Text(context.l10n.plugin_requires_authentication),
                      ],
                    ),
                  if (hasUpdate)
                    SizedBox(
                      width: double.infinity,
                      child: Basic(
                        leading: const Icon(SonolythIcons.update),
                        title: Text(context.l10n.update_available),
                        subtitle: Text(
                          updateAvailable!.asData!.value!.version,
                        ),
                        trailing: Button(
                          style: zenithPositiveButton(
                            context.theme.colorScheme,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  MetadataPluginUpdateAvailableDialog(
                                plugin: plugin,
                                update: updateAvailable.asData!.value!,
                              ),
                            );
                          },
                          child: Text(context.l10n.update),
                        ),
                      ),
                    ),
                  if (supportsScrobbling)
                    SizedBox(
                      width: double.infinity,
                      child: Basic(
                        leading: const Icon(SonolythIcons.info),
                        title: Text(context.l10n.supports_scrobbling),
                        subtitle: Text(context.l10n.plugin_scrobbling_info),
                      ),
                    )
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (plugin.abilities.contains(PluginAbilities.metadata))
                    // Positive actions on a card: translucent 5%, see
                    // [zenithPositiveButton].
                    Button(
                      style: zenithPositiveButton(context.theme.colorScheme),
                      enabled: !isDefaultMetadata,
                      onPressed: () async {
                        await pluginsNotifier.setDefaultMetadataPlugin(plugin);
                      },
                      child: Text(
                        isDefaultMetadata
                            ? context.l10n.default_metadata_source
                            : context.l10n.set_default_metadata_source,
                      ),
                    ),
                  if (plugin.abilities.contains(PluginAbilities.audioSource))
                    Button(
                      style: zenithPositiveButton(context.theme.colorScheme),
                      enabled: !isDefaultAudioSource,
                      onPressed: () async {
                        await pluginsNotifier
                            .setDefaultAudioSourcePlugin(plugin);
                      },
                      child: Text(
                        isDefaultAudioSource
                            ? context.l10n.default_audio_source
                            : context.l10n.set_default_audio_source,
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisSize:
                    mediaQuery.smAndUp ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  if ((isDefaultMetadata || isDefaultAudioSource) &&
                      requiresAuth &&
                      !isAuthenticated)
                    Button(
                      style: zenithPositiveButton(context.theme.colorScheme),
                      onPressed: () async {
                        await pluginSnapshot?.asData?.value?.auth
                            .authenticate();
                      },
                      leading: const Icon(SonolythIcons.login),
                      child: Text(context.l10n.login),
                    )
                  else if ((isDefaultMetadata || isDefaultAudioSource) &&
                      requiresAuth &&
                      isAuthenticated)
                    Button.destructive(
                      onPressed: () async {
                        await pluginSnapshot?.asData?.value?.auth.logout();
                      },
                      leading: const Icon(SonolythIcons.logout),
                      child: Text(context.l10n.logout),
                    ),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}
