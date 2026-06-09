import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/provider/spotiflac/extension_registry.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SpotiFlacExtensionRegistrySection extends HookConsumerWidget {
  const SpotiFlacExtensionRegistrySection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final registrySnapshot = ref.watch(spotiFlacExtensionRegistryProvider);
    final registryNotifier = ref.watch(
      spotiFlacExtensionRegistryProvider.notifier,
    );
    final repositoryController = useTextEditingController();

    Future<void> addRepository() async {
      await registryNotifier.addRegistry(repositoryController.text);
      repositoryController.clear();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: TextField(
                controller: repositoryController,
                placeholder: const Text("SpotiFLAC extension registry URL"),
              ),
            ),
            Tooltip(
              tooltip: TooltipContainer(
                child: const Text("Add registry"),
              ).call,
              child: IconButton.primary(
                icon: const Icon(SpotubeIcons.add),
                onPressed: addRepository,
              ),
            ),
            Tooltip(
              tooltip: TooltipContainer(
                child: const Text("Refresh registries"),
              ).call,
              child: IconButton.secondary(
                icon: const Icon(SpotubeIcons.refresh),
                onPressed: registryNotifier.refresh,
              ),
            ),
          ],
        ),
        const Gap(12),
        registrySnapshot.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => Card(
            child: Basic(
              leading: const Icon(SpotubeIcons.error, color: Colors.red),
              title: const Text("Could not load SpotiFLAC registries"),
              subtitle: Text(error.toString()),
            ),
          ),
          data: (registryState) {
            final downloadProviders = registryState.extensions
                .where((extension) => extension.isDownloadProvider)
                .toList();
            final otherExtensions = registryState.extensions
                .where((extension) => !extension.isDownloadProvider)
                .toList();
            final extensions = [...downloadProviders, ...otherExtensions];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final registry in registryState.registries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(SpotubeIcons.extensions, size: 14),
                            const Gap(6),
                            Text(Uri.parse(registry).host).xSmall,
                            if (registry !=
                                defaultSpotiFlacExtensionRegistryUrl) ...[
                              const Gap(4),
                              IconButton.ghost(
                                size: ButtonSize.small,
                                icon: const Icon(SpotubeIcons.close),
                                onPressed: () {
                                  registryNotifier.removeRegistry(registry);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
                const Gap(16),
                if (extensions.isEmpty)
                  Card(
                    child: Basic(
                      leading: const Icon(SpotubeIcons.extensions),
                      title: const Text("No SpotiFLAC extensions found"),
                      subtitle: const Text(
                        "Add another registry URL or refresh the default registry.",
                      ),
                    ),
                  )
                else
                  ...extensions.map(
                    (extension) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 8,
                          children: [
                            Basic(
                              leading: Icon(
                                extension.isDownloadProvider
                                    ? SpotubeIcons.download
                                    : SpotubeIcons.extensions,
                              ),
                              title: Text(extension.name),
                              subtitle: Text(extension.description),
                              trailing: Button.primary(
                                leading: const Icon(SpotubeIcons.download),
                                onPressed: () {
                                  launchUrlString(
                                    extension.downloadUrl,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                child: const Text("Get"),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (extension.version.isNotEmpty)
                                  SecondaryBadge(
                                    child: Text("v${extension.version}"),
                                  ),
                                SecondaryBadge(
                                  child: Text(
                                    extension.isDownloadProvider
                                        ? "Download Provider"
                                        : "Integration",
                                  ),
                                ),
                                SecondaryBadge(
                                  child: Text(
                                    Uri.parse(extension.registryUrl).host,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
