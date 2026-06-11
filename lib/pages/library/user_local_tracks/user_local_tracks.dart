import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sonolyth/components/playbutton_view/playbutton_view.dart';
import 'package:sonolyth/modules/library/local_folder/local_folder_item.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/local_tracks/local_tracks_provider.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/utils/platform.dart';

enum SortBy {
  none,
  ascending,
  descending,
  newest,
  oldest,
  duration,
  artist,
  album,
}

@RoutePage()
class UserLocalLibraryPage extends HookConsumerWidget {
  static const name = 'user_local_library';
  const UserLocalLibraryPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final cacheDir = useFuture(useMemoized(
      () => UserPreferencesNotifier.getMusicCacheDir(),
      const [],
    ));
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final preferences = ref.watch(userPreferencesProvider);
    final controller = useScrollController();

    final searchText = useState('');

    final addLocalLibraryLocation = useCallback(() async {
      // The download folder and the music cache folder are managed by the
      // app and already listed; adding them again would make the provider
      // double-process them.
      final reservedLocations = [
        preferences.downloadLocation,
        await UserPreferencesNotifier.getMusicCacheDir(),
      ];

      if (kIsMobile || kIsMacOS) {
        final dirStr = await FilePicker.platform.getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        if (preferences.localLibraryLocation.contains(dirStr)) return;
        if (reservedLocations.contains(dirStr)) return;
        preferencesNotifier.setLocalLibraryLocation(
            [...preferences.localLibraryLocation, dirStr]);
      } else {
        String? dirStr = await getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        if (preferences.localLibraryLocation.contains(dirStr)) return;
        if (reservedLocations.contains(dirStr)) return;
        preferencesNotifier.setLocalLibraryLocation(
            [...preferences.localLibraryLocation, dirStr]);
      }
    }, [preferences.localLibraryLocation, preferences.downloadLocation]);

    final tracksSnapshot = ref.watch(localTracksProvider);

    // Downloaded collections live in subfolders of the download folder and
    // surface as their own keys in the provider; list them as folders too so
    // re-downloaded playlists/albums reappear here.
    final downloadSubfolders = useMemoized(() {
      final keys = tracksSnapshot.asData?.value.keys ?? const <String>[];
      return keys
          .where((k) =>
              k != preferences.downloadLocation &&
              k != cacheDir.data &&
              !preferences.localLibraryLocation.contains(k) &&
              isWithin(preferences.downloadLocation, k))
          .sorted((a, b) => basename(a).compareTo(basename(b)));
    }, [
      tracksSnapshot,
      preferences.downloadLocation,
      preferences.localLibraryLocation,
      cacheDir.data,
    ]);

    final locations = useMemoized(() {
      final all = [
        preferences.downloadLocation,
        ...downloadSubfolders,
        if (cacheDir.hasData) cacheDir.data!,
        ...preferences.localLibraryLocation,
      ];
      if (searchText.value.isEmpty) {
        return all;
      }
      return all
          .map((e) => (weightedRatio(basename(e), searchText.value), e))
          .sorted((a, b) => b.$1.compareTo(a.$1))
          .where((e) => e.$1 > 50)
          .map((e) => e.$2)
          .toList();
    }, [
      preferences.downloadLocation,
      preferences.localLibraryLocation,
      downloadSubfolders,
      cacheDir.data,
      searchText.value,
    ]);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        child: material.RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(localTracksProvider);
          },
          child: InterScrollbar(
            controller: controller,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Theme.of(context).colorScheme.background,
                  floating: true,
                  flexibleSpace: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) => searchText.value = value,
                              features: const [
                                InputFeature.leading(
                                    Icon(SonolythIcons.filter)),
                              ],
                              placeholder: Text(context.l10n.search),
                            ),
                          ),
                          const Gap(8),
                          Button.secondary(
                            leading: const Icon(SonolythIcons.folderAdd),
                            onPressed: addLocalLibraryLocation,
                            child: Text(context.l10n.add_library_location),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverGap(10),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: PlaybuttonView(
                    controller: controller,
                    itemCount: locations.length,
                    hasMore: false,
                    isLoading: tracksSnapshot.isLoading,
                    onRequestMore: () {},
                    gridItemBuilder: (context, index) =>
                        LocalFolderItem(folder: locations[index]),
                    listItemBuilder: (context, index) =>
                        LocalFolderItem.tile(folder: locations[index]),
                  ),
                ),
                const SliverSafeArea(sliver: SliverGap(10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
