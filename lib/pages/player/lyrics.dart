import 'package:auto_route/annotations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/button/back_button.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/hooks/utils/use_palette_color.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/pages/lyrics/plain_lyrics.dart';
import 'package:sonolyth/pages/lyrics/synced_lyrics.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';

@RoutePage()
class PlayerLyricsPage extends HookConsumerWidget {
  const PlayerLyricsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    String albumArt = useMemoized(
      () => (playlist.activeTrack?.album.images).asUrlString(
        index: (playlist.activeTrack?.album.images.length ?? 1) - 1,
        placeholder: ImagePlaceholder.albumArt,
      ),
      [playlist.activeTrack?.album.images],
    );
    final selectedIndex = useState(0);
    final palette = usePaletteColor(albumArt, ref);

    final tabbar = TabList(
      index: selectedIndex.value,
      onChanged: (index) => selectedIndex.value = index,
      children: [
        TabItem(
          child: Text(context.l10n.synced),
        ),
        TabItem(
          child: Text(context.l10n.plain),
        ),
      ],
    );

    return Scaffold(
      headers: [
        AppBar(
          leading: [tabbar],
          trailing: const [
            BackButton(icon: SonolythIcons.angleDown),
          ],
        ),
      ],
      child: IndexedStack(
        index: selectedIndex.value,
        children: [
          SyncedLyrics(palette: palette, isModal: false),
          PlainLyrics(palette: palette, isModal: false),
        ],
      ),
    );
  }
}
