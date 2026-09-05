import 'package:collection/collection.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/modules/lyrics/zoom_controls.dart';
import 'package:sonolyth/components/shimmers/shimmer_lyrics.dart';
import 'package:sonolyth/extensions/context.dart';

import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/lyrics/synced.dart';

class PlainLyrics extends HookConsumerWidget {
  final bool? isModal;
  final int defaultTextZoom;
  const PlainLyrics({
    this.isModal,
    this.defaultTextZoom = 100,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final lyricsQuery = ref.watch(syncedLyricsProvider(playlist.activeTrack));
    final colorScheme = Theme.of(context).colorScheme;

    final textZoomLevel = useState<int>(defaultTextZoom);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isModal != true) ...[
              Center(
                child: Text(
                  playlist.activeTrack?.name ?? "",
                  // `ItemTextTitle_scene_header` — 29sp normal. See the note
                  // in `synced_lyrics.dart` on the palette colour this
                  // replaces.
                  style: zenithPageTitle(colorScheme),
                ),
              ),
              Center(
                child: Text(
                  playlist.activeTrack?.artists.asString() ?? "",
                  // `ItemTextTitle_scene_subheader` — 17sp, dimmed.
                  style: zenithSubheaderTitle(colorScheme)
                      .copyWith(color: colorScheme.mutedForeground),
                ),
              )
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Builder(
                      builder: (context) {
                        if (lyricsQuery.isLoading || lyricsQuery.isRefreshing) {
                          return const ShimmerLyrics();
                        } else if (lyricsQuery.hasError) {
                          return Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.l10n.no_lyrics_available,
                                  // `PopupButton_Text` (16dp) at 60%.
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.mutedForeground,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const Gap(26),
                                const Icon(SonolythIcons.noLyrics, size: 60),
                              ],
                            ),
                          );
                        }

                        final lyrics =
                            lyricsQuery.asData?.value.lyrics.mapIndexed((i, e) {
                          final next = lyricsQuery.asData?.value.lyrics
                              .elementAtOrNull(i + 1);
                          if (next != null &&
                              e.time - next.time >
                                  const Duration(milliseconds: 700)) {
                            return "${e.text}\n";
                          }

                          return e.text;
                        }).join("\n");

                        return AnimatedDefaultTextStyle(
                          duration: ZenithMotion.fade,
                          curve: ZenithMotion.fadeCurve,
                          style: TextStyle(
                            color: colorScheme.foreground,
                            fontSize: 24 * textZoomLevel.value / 100,
                            height: textZoomLevel.value < 70
                                ? 1.5
                                : textZoomLevel.value > 150
                                    ? 1.7
                                    : 2,
                          ),
                          child: SelectableText(
                            lyrics == null && playlist.activeTrack == null
                                ? context.l10n.no_tracks_playing
                                : lyrics ?? "",
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: ZoomControls(
            label: context.l10n.text_size,
            value: textZoomLevel.value,
            onChanged: (value) => textZoomLevel.value = value,
            min: 50,
            max: 200,
          ),
        ),
      ],
    );
  }
}
