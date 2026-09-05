import 'package:auto_route/annotations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/button/back_button.dart';
import 'package:sonolyth/components/ui/zenith_filter_chip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/pages/lyrics/plain_lyrics.dart';
import 'package:sonolyth/pages/lyrics/synced_lyrics.dart';

/// The lyrics sheet opened from the player. Same content as `LyricsPage`,
/// without the palette tint it used to derive from the album art — see the
/// note there.
@RoutePage()
class PlayerLyricsPage extends HookConsumerWidget {
  const PlayerLyricsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final selectedIndex = useState(0);

    // `TopSearchCatButton` chips, not `TabList` — Poweramp has no tab
    // indicator; see `library.dart`.
    final tabbar = Row(
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
    );

    return Scaffold(
      headers: [
        AppBar(
          backgroundColor: Colors.transparent,
          surfaceBlur: 0,
          leading: [tabbar],
          trailing: const [
            BackButton(icon: SonolythIcons.angleDown),
          ],
        ),
      ],
      child: IndexedStack(
        index: selectedIndex.value,
        children: const [
          SyncedLyrics(isModal: false),
          PlainLyrics(isModal: false),
        ],
      ),
    );
  }
}
