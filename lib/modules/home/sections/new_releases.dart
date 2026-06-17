import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/album/releases.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';

class HomeNewReleasesSection extends HookConsumerWidget {
  const HomeNewReleasesSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);

    final newReleases = ref.watch(metadataPluginAlbumReleasesProvider);
    final newReleasesNotifier =
        ref.read(metadataPluginAlbumReleasesProvider.notifier);

    // "New Releases" is Spotify's personalized What's-New feed. It can fail in
    // ways the rest of Home doesn't (e.g. a persistent 401 on the pathfinder
    // queryWhatsNewFeed even when catalog calls succeed). Since the row is
    // supplementary, hide it on ANY error instead of dropping a full-width
    // ErrorBox onto the home screen — same graceful degrade as the no-plugin
    // case. The provider re-fetches when the auth state flips, so a transient
    // failure self-heals on the next rebuild.
    if (authenticated.asData?.value != true ||
        newReleases.isLoading ||
        newReleases.hasError ||
        newReleases.asData?.value.items.isEmpty == true) {
      return const SizedBox.shrink();
    }

    return HorizontalPlaybuttonCardView<SonolythSimpleAlbumObject>(
      items: newReleases.asData?.value.items ?? [],
      title: Text(context.l10n.new_releases),
      isLoadingNextPage: newReleases.isLoadingNextPage,
      hasNextPage: newReleases.asData?.value.hasMore ?? false,
      onFetchMore: newReleasesNotifier.fetchMore,
    );
  }
}
