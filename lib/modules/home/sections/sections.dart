import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/components/fallbacks/error_box.dart';
import 'package:sonolyth/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sonolyth/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/browse/sections.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';
import 'package:flutter_undraw/flutter_undraw.dart';

class HomePageBrowseSection extends HookConsumerWidget {
  const HomePageBrowseSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final browseSections = ref.watch(metadataPluginBrowseSectionsProvider);
    final sections = browseSections.asData?.value.items;
    final ThemeData(:colorScheme) = Theme.of(context);

    if (browseSections.isLoading) {
      return SliverToBoxAdapter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            Undraw(
              height: 200,
              illustration: UndrawIllustration.process,
              color: colorScheme.primary,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                const CircularProgressIndicator(),
                Text(context.l10n.building_your_timeline).muted,
              ],
            ),
            const Gap(16),
          ],
        ),
      );
    }

    if (browseSections.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const SliverFillRemaining(
        child: Center(child: NoDefaultMetadataPlugin()),
      );
    }

    if (browseSections.hasError) {
      // When the default metadata plugin supports auth but the user isn't
      // signed in, the failure is almost always an auth error — surface a
      // "Log in" button instead of a generic "something went wrong".
      final pluginConfig = ref.watch(metadataPluginsProvider).asData?.value;
      final supportsAuth = pluginConfig?.defaultMetadataPluginConfig?.abilities
              .contains(PluginAbilities.authentication) ??
          false;
      final isAuthenticated =
          ref.watch(metadataPluginAuthenticatedProvider).asData?.value ?? false;
      final pluginSnapshot = ref.watch(metadataPluginProvider);

      return SliverFillRemaining(
        child: Center(
          child: ErrorBox(
            error: browseSections.error!,
            onLogin: supportsAuth && !isAuthenticated
                ? () async {
                    await pluginSnapshot.asData?.value?.auth.authenticate();
                  }
                : null,
            onRetry: () {
              ref.invalidate(metadataPluginBrowseSectionsProvider);
            },
          ),
        ),
      );
    }

    return SliverInfiniteList(
      hasReachedMax: browseSections.asData?.value.hasMore == false,
      isLoading: !browseSections.isLoading && browseSections.isLoadingNextPage,
      onFetchData: () {
        ref.read(metadataPluginBrowseSectionsProvider.notifier).fetchMore();
      },
      itemCount: sections?.length ?? 0,
      itemBuilder: (context, index) {
        final section = sections![index];
        if (section.items.isEmpty) return const SizedBox.shrink();

        return HorizontalPlaybuttonCardView(
          items: section.items,
          title: Text(section.title),
          hasNextPage: false,
          isLoadingNextPage: false,
          onFetchMore: () {},
          titleTrailing: section.browseMore
              ? Button.text(
                  child: Text(context.l10n.browse_all),
                  onPressed: () {
                    context.navigateTo(
                      HomeBrowseSectionItemsRoute(
                        sectionId: section.id,
                        section: section,
                      ),
                    );
                  },
                )
              : null,
        );
      },
    );
  }
}
