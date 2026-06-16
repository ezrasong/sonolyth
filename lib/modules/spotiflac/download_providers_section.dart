import 'package:flutter/material.dart' show ListTileControlAffinity;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/adaptive/adaptive_select_tile.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/spotiflac/download_settings.dart';
import 'package:sonolyth/services/spotiflac/providers/qobuz_provider.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/services/spotiflac/providers/tidal_provider.dart';
import 'package:sonolyth/services/spotiflac/providers/youtube_provider.dart';

/// Settings for the native lossless download providers. Downloads run entirely
/// in-app through the zarz gateway (no external SpotiFLAC app), so this manages
/// which providers are enabled, their priority order, and per-provider quality.
class SpotiFlacDownloadProvidersSection extends ConsumerWidget {
  const SpotiFlacDownloadProvidersSection({super.key});

  String _qualityLabel(SpotiFlacProvider provider, String quality) {
    if (provider is QobuzProvider) return QobuzProvider.labelFor(quality);
    if (provider is TidalProvider) return TidalProvider.labelFor(quality);
    return quality;
  }

  @override
  Widget build(BuildContext context, ref) {
    final settingsSnapshot = ref.watch(spotiFlacDownloadSettingsProvider);
    final notifier = ref.watch(spotiFlacDownloadSettingsProvider.notifier);

    return settingsSnapshot.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: ErrorBox(
          error: error,
          onRetry: () => ref.invalidate(spotiFlacDownloadSettingsProvider),
        ),
      ),
      data: (settings) {
        final providersById = {
          for (final provider in allSpotiFlacProviders) provider.id: provider,
        };
        final ordered = [
          for (final id in settings.order)
            if (providersById.containsKey(id)) providersById[id]!,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Basic(
                leading: const Icon(SonolythIcons.download),
                title: Text(context.l10n.lossless_downloads),
                subtitle: Text(context.l10n.lossless_downloads_description),
              ),
            ),
            const Gap(12),
            for (var index = 0; index < ordered.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProviderCard(
                  provider: ordered[index],
                  index: index,
                  total: ordered.length,
                  enabled: !settings.disabled.contains(ordered[index].id),
                  lossy: ordered[index] is YouTubeProvider,
                  quality: settings.qualityByProvider[ordered[index].id] ??
                      ordered[index].defaultQuality,
                  qualityLabel: _qualityLabel,
                  onToggle: (value) {
                    // Never allow every provider to be switched off — downloads
                    // would silently have nothing to resolve against.
                    if (!value && settings.enabledProviders.length <= 1) {
                      showToast(
                        context: context,
                        location: ToastLocation.topRight,
                        builder: (context, overlay) => SurfaceCard(
                          child: Basic(
                            leading: const Icon(
                              SonolythIcons.warning,
                              color: Colors.yellow,
                            ),
                            title: Text(context.l10n.keep_one_download_provider),
                          ),
                        ),
                      );
                      return;
                    }
                    notifier.setEnabled(ordered[index].id, value);
                  },
                  onQuality: (value) =>
                      notifier.setQuality(ordered[index].id, value),
                  onMoveUp: index == 0
                      ? null
                      : () => notifier.reorder(index, index - 1),
                  onMoveDown: index == ordered.length - 1
                      ? null
                      : () => notifier.reorder(index, index + 2),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final SpotiFlacProvider provider;
  final int index;
  final int total;
  final bool enabled;

  /// True for providers that can't deliver lossless audio (the YouTube
  /// fallback) so the row can carry a "Lossy" hint.
  final bool lossy;
  final String quality;
  final String Function(SpotiFlacProvider, String) qualityLabel;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onQuality;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _ProviderCard({
    required this.provider,
    required this.index,
    required this.total,
    required this.enabled,
    required this.lossy,
    required this.quality,
    required this.qualityLabel,
    required this.onToggle,
    required this.onQuality,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Row(
            children: [
              Column(
                children: [
                  IconButton.ghost(
                    size: ButtonSize.small,
                    enabled: onMoveUp != null,
                    icon: const Icon(SonolythIcons.angleUp),
                    onPressed: onMoveUp,
                  ),
                  IconButton.ghost(
                    size: ButtonSize.small,
                    enabled: onMoveDown != null,
                    icon: const Icon(SonolythIcons.angleDown),
                    onPressed: onMoveDown,
                  ),
                ],
              ),
              const Gap(8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("${index + 1}. ").muted(),
                        Flexible(
                          child: Text(
                            provider.displayName,
                            overflow: TextOverflow.ellipsis,
                          ).semiBold(),
                        ),
                        if (lossy) ...[
                          const Gap(8),
                          SecondaryBadge(child: Text(context.l10n.lossy)),
                        ],
                      ],
                    ),
                    Text(
                      enabled
                          ? context.l10n.priority_count(index + 1)
                          : context.l10n.disabled,
                    ).xSmall().muted(),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
          if (provider.qualities.length > 1)
            AdaptiveSelectTile<String>(
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(context.l10n.quality),
              value: quality,
              onChanged: (value) {
                if (value != null) onQuality(value);
              },
              options: [
                for (final option in provider.qualities)
                  SelectItemButton(
                    value: option,
                    child: Text(qualityLabel(provider, option)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
