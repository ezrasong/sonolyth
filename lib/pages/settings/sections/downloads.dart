import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' show ListTile;
import 'package:path/path.dart' as p;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/modules/settings/section_card_with_heading.dart';
import 'package:sonolyth/modules/spotiflac/download_providers_section.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/utils/platform.dart';

class SettingsDownloadsSection extends HookConsumerWidget {
  const SettingsDownloadsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final preferences = ref.watch(userPreferencesProvider);

    // Scoped storage (Android 11+) silently rejects raw writes outside the
    // app dir and the public media collections — verify we can actually
    // create a file there before accepting the folder, instead of letting
    // every download fail later.
    Future<bool> isWritable(String dir) async {
      try {
        final probe = File(p.join(dir, ".sonolyth-write-test"));
        await probe.create(recursive: true);
        await probe.delete();
        return true;
      } catch (_) {
        return false;
      }
    }

    final pickDownloadLocation = useCallback(() async {
      final String? dirStr;
      if (kIsMobile || kIsMacOS) {
        dirStr = await FilePicker.platform.getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
      } else {
        dirStr = await getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
      }
      if (dirStr == null) return;

      if (!await isWritable(dirStr)) {
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.download_location_not_writable),
            content: Text(context.l10n.download_location_not_writable_help),
            actions: [
              Button.primary(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
        return;
      }

      preferencesNotifier.setDownloadLocation(dirStr);
    }, [preferences.downloadLocation]);

    return SectionCardWithHeading(
      heading: context.l10n.downloads,
      children: [
        ListTile(
          leading: const Icon(SonolythIcons.download),
          title: Text(context.l10n.download_location),
          subtitle: Text(preferences.downloadLocation),
          trailing: IconButton.secondary(
            onPressed: pickDownloadLocation,
            icon: const Icon(SonolythIcons.folder),
          ),
          onTap: pickDownloadLocation,
        ),
        const SpotiFlacDownloadProvidersSection(),
      ],
    );
  }
}
