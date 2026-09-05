import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/titlebar/titlebar.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/pages/lyrics/plain_lyrics.dart';
import 'package:sonolyth/pages/lyrics/synced_lyrics.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/lyrics/synced.dart';
import 'package:sonolyth/services/lyrics/embedded_lyrics.dart';
import 'package:auto_route/auto_route.dart';

/// The lyrics screen.
///
/// It used to paint the album art blurred across the whole page with a
/// palette-derived tint over it, and colour its type from the same palette.
/// None of that has a source in Proxima — the skin is achromatic and its ground
/// is `colorBgPrimary` everywhere — and the palette text colours were computed
/// for the album's dark-muted tone, so on a dark cover the title came out
/// near-black on near-black and the "not available" notice vanished with it.
/// The page is now the ground and its type is the scheme's.
@RoutePage()
class LyricsPage extends HookConsumerWidget {
  static const name = "lyrics";

  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final colorScheme = context.theme.colorScheme;
    final selectedIndex = useState(0);

    // `TopSearchCatButton` — the one category-selector idiom the app has.
    // Poweramp defines no tab indicator anywhere (see `library.dart`), so the
    // Material underline tabs this replaced had no source.
    Widget tabbar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ZenithFilterChip.gap,
        children: [
          ZenithFilterChip(
            label: context.l10n.synced,
            selected: selectedIndex.value == 0,
            onPressed: () => selectedIndex.value = 0,
          ),
          ZenithFilterChip(
            label: context.l10n.plain,
            selected: selectedIndex.value == 1,
            onPressed: () => selectedIndex.value = 1,
          ),
        ],
      ),
    );

    tabbar = Row(
      children: [
        tabbar,
        const Spacer(),
        Consumer(
          builder: (context, ref, child) {
            final playback = ref.watch(audioPlayerProvider);
            final lyric = ref.watch(syncedLyricsProvider(playback.activeTrack));
            final providerName = lyric.asData?.value.provider;

            if (providerName == null) {
              return const SizedBox.shrink();
            }

            // Lyrics read out of the file are nobody's service.
            final label = switch (providerName) {
              EmbeddedLyrics.providerTags =>
                context.l10n.lyrics_from_file_tags,
              EmbeddedLyrics.providerSidecar =>
                context.l10n.lyrics_from_lrc_file,
              _ => context.l10n.powered_by_provider(providerName),
            };

            return Text(
              label,
              // `ItemSubheadTracksMetaTitle` — 10sp at `colorTrackMeta`:
              // metadata about the list, not a heading. Explicit, because
              // `TitleBar` wraps its title in the 29sp header style.
              style: TextStyle(
                fontSize: 10,
                color: zenithTrackMeta(colorScheme),
              ),
            );
          },
        ),
        const Gap(12),
      ],
    );

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            backgroundColor: Colors.transparent,
            title: tabbar,
            height: 58 * context.theme.scaling,
            surfaceBlur: 0,
            automaticallyImplyLeading: false,
          )
        ],
        child: IndexedStack(
          index: selectedIndex.value,
          children: const [
            SyncedLyrics(isModal: false),
            PlainLyrics(isModal: false),
          ],
        ),
      ),
    );
  }
}
