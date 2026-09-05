import 'package:flutter/gestures.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/components/ui/zenith_popup_card.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/collections/official_plugin_owners.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/markdown/markdown.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:change_case/change_case.dart';

final validTopics = {
  "spotube-metadata-plugin": ("Metadata", SonolythIcons.album),
  "spotube-audio-source-plugin": ("Audio Source", SonolythIcons.music),
};

class MetadataPluginRepositoryItem extends HookConsumerWidget {
  final MetadataPluginRepository pluginRepo;
  const MetadataPluginRepositoryItem({
    super.key,
    required this.pluginRepo,
  });

  @override
  Widget build(BuildContext context, ref) {
    final pluginsNotifier = ref.watch(metadataPluginsProvider.notifier);
    final host = useMemoized(
      () => Uri.parse(pluginRepo.repoUrl).host,
      [pluginRepo.repoUrl],
    );
    final pluginTitle = pluginRepo.name.startsWith("spotube-plugin")
        ? pluginRepo.name
            .replaceFirst("spotube-plugin-", "")
            .trim()
            .toCapitalCase()
        : pluginRepo.name.toCapitalCase();
    final isInstalling = useState(false);

    // `popup_bg`: one flat fill at radius 20, no stroke.
    return ZenithPopupCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Basic(
            title: Text(
              pluginTitle,
            ),
            subtitle: Text(pluginRepo.description),
            trailing: Button(
              style: zenithPositiveButton(context.theme.colorScheme),
              enabled: !isInstalling.value,
              onPressed: () async {
                try {
                  isInstalling.value = true;
                  final pluginConfig = await pluginsNotifier
                      .downloadAndCachePlugin(pluginRepo.repoUrl);

                  if (!context.mounted) return;
                  final isOfficialPlugin =
                      officialPluginOwners.contains(pluginRepo.owner);

                  final isAllowed = isOfficialPlugin
                      ? true
                      : await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            final pluginAbilities = pluginConfig.apis
                                .map((e) =>
                                    context.l10n.can_access_name_api(e.name))
                                .join("\n\n");

                            return AlertDialog(
                              title: Text(
                                context.l10n.do_you_want_to_install_this_plugin,
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.l10n.third_party_plugin_warning),
                                  const Gap(8),
                                  FutureBuilder(
                                    future: pluginsNotifier
                                        .getLogoPath(pluginConfig),
                                    builder: (context, snapshot) {
                                      return Basic(
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
                                                color: zenithArtWell(
                                                  context.theme.colorScheme,
                                                ),
                                                child: const Icon(
                                                    SonolythIcons.plugin),
                                              ),
                                        title: Text(pluginConfig.name),
                                        subtitle:
                                            Text(pluginConfig.description),
                                      );
                                    },
                                  ),
                                  const Gap(8),
                                  AppMarkdown(
                                    data:
                                        "**${context.l10n.author}**: ${pluginConfig.author}\n\n"
                                        "**${context.l10n.repository}**: [${pluginConfig.repository ?? 'N/A'}](${pluginConfig.repository})\n\n\n\n"
                                        "${context.l10n.this_plugin_can_do_following}:\n\n"
                                        "$pluginAbilities",
                                  ),
                                ],
                              ),
                              actions: [
                                Button.ghost(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  child: Text(context.l10n.decline),
                                ),
                                Button(
                                  style: zenithPositiveButton(
                                    context.theme.colorScheme,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  child: Text(context.l10n.accept),
                                ),
                              ],
                            );
                          },
                        );

                  if (isAllowed != true) return;
                  await pluginsNotifier.addPlugin(pluginConfig);
                } finally {
                  if (context.mounted) {
                    isInstalling.value = false;
                  }
                }
              },
              leading: isInstalling.value
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: context.theme.colorScheme.foreground,
                      ),
                    )
                  : const Icon(SonolythIcons.add),
              child: Text(context.l10n.install),
            ),
          ),
          if (!officialPluginOwners.contains(pluginRepo.owner))
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: context.l10n.source),
                  TextSpan(
                    text: pluginRepo.repoUrl.replaceAll("https://", ""),
                    style: TextStyle(
                      color: context.theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        launchUrlString(pluginRepo.repoUrl);
                      },
                  ),
                ],
              ),
              style: context.theme.typography.xSmall,
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (officialPluginOwners.contains(pluginRepo.owner))
                ZenithValueChip(
                  icon: SonolythIcons.done,
                  child: Text(context.l10n.official),
                )
              else ...[
                Text(
                  context.l10n.author_name(pluginRepo.owner),
                  style: context.theme.typography.xSmall,
                ),
                // Was white text on a `primary` fill — invisible in an
                // achromatic theme where `primary` is white.
                ZenithValueChip(
                  icon: SonolythIcons.warning,
                  child: Text(context.l10n.third_party),
                ),
              ],
              for (final topic in pluginRepo.topics)
                if (validTopics.keys.contains(topic))
                  ZenithValueChip(
                    icon: validTopics[topic]!.$2,
                    child: Text(validTopics[topic]!.$1),
                  ),
              ZenithValueChip(
                icon: host == "github.com" ? SonolythIcons.github : null,
                child: Text(host),
                onPressed: () {
                  launchUrlString(pluginRepo.repoUrl);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
