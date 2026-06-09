import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:spotube/modules/library/local_folder/local_folder_item.dart';
import 'package:spotube/extensions/constrains.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/provider/local_tracks/local_tracks_provider.dart';
import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';
import 'package:spotube/utils/platform.dart';

@RoutePage()
class UserLocalLibraryPage extends HookConsumerWidget {
  static const name = 'user_local_library';
  const UserLocalLibraryPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final cacheDir = useFuture(UserPreferencesNotifier.getMusicCacheDir());
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final preferences = ref.watch(userPreferencesProvider);
    final controller = useScrollController();

    final addLocalLibraryLocation = useCallback(() async {
      if (kIsMobile || kIsMacOS) {
        final dirStr = await FilePicker.platform.getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        if (preferences.localLibraryLocation.contains(dirStr)) return;
        preferencesNotifier.setLocalLibraryLocation(
            [...preferences.localLibraryLocation, dirStr]);
      } else {
        String? dirStr = await getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        if (preferences.localLibraryLocation.contains(dirStr)) return;
        preferencesNotifier.setLocalLibraryLocation(
            [...preferences.localLibraryLocation, dirStr]);
      }
    }, [preferences.localLibraryLocation]);

    // This is just to pre-load the tracks.
    // For now, this gets all of them.
    ref.watch(localTracksProvider);

    final locations = [
      preferences.downloadLocation,
      if (cacheDir.hasData) cacheDir.data!,
      ...preferences.localLibraryLocation,
    ];

    return SafeArea(
      bottom: false,
      child: Scaffold(
        child: material.RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(localTracksProvider);
          },
          child: InterScrollbar(
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: Theme.of(context).colorScheme.background,
                    floating: true,
                    flexibleSpace: SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Button.secondary(
                          leading: const Icon(SpotubeIcons.folderAdd),
                          onPressed: addLocalLibraryLocation,
                          child: Text(context.l10n.add_library_location),
                        ),
                      ),
                    ),
                  ),
                  const SliverGap(10),
                  SliverLayoutBuilder(builder: (context, constrains) {
                    return SliverGrid.builder(
                      itemCount: locations.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisExtent: constrains.smAndDown ? 240 : 250,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        return LocalFolderItem(folder: locations[index]);
                      },
                    );
                  }),
                  const SliverSafeArea(sliver: SliverGap(10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
