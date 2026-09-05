import 'dart:async';

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
import 'package:sonolyth/hooks/controllers/use_auto_scroll_controller.dart';
import 'package:sonolyth/modules/lyrics/use_synced_lyrics.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sonolyth/provider/audio_player/audio_player.dart';
import 'package:sonolyth/provider/lyrics/synced.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';
import 'package:sonolyth/services/logger/logger.dart';

class SyncedLyrics extends HookConsumerWidget {
  final bool? isModal;
  final int defaultTextZoom;

  const SyncedLyrics({
    this.isModal,
    this.defaultTextZoom = 100,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);

    final playlist = ref.watch(audioPlayerProvider);

    final controller = useAutoScrollController();

    final delay = ref.watch(syncedLyricsDelayProvider);

    final timedLyricsQuery =
        ref.watch(syncedLyricsProvider(playlist.activeTrack));

    final lyricValue = timedLyricsQuery.asData?.value;

    final lyricsState = ref.watch(
      syncedLyricsMapProvider(playlist.activeTrack),
    );
    // `const` so the hook's effect key is stable while there are no lyrics —
    // a fresh `{}` every build re-subscribed the position stream each frame.
    final currentTime = useSyncedLyrics(
      ref,
      lyricsState.asData?.value.lyricsMap ?? const <int, String>{},
      delay,
    );
    final textZoomLevel = useState<int>(defaultTextZoom);

    ref.listen(
      audioPlayerProvider.select((s) => s.activeTrack),
      (previous, next) {
        controller.animateTo(
          0,
          duration: ZenithMotion.slide,
          curve: ZenithMotion.slideCurve,
        );
        ref.read(syncedLyricsDelayProvider.notifier).state = 0;
      },
    );

    // `ItemTextTitle_scene_header` — 29sp normal at `textColorPrimary`. The
    // palette-derived colour this used to carry was computed for the album's
    // dark-muted tone, so on a dark cover the title came out near-black on the
    // near-black ground — invisible.
    final headlineTextStyle = zenithPageTitle(theme.colorScheme);

    // `PopupButton_Text` size (16dp) at `textColorSecondary`.
    final bodyTextTheme = TextStyle(
      fontSize: 16,
      color: theme.colorScheme.mutedForeground,
    );

    useEffect(() {
      StreamSubscription? subscription;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        subscription = audioPlayer.positionStream.listen((event) {
          try {
            if (event > Duration.zero || !controller.hasClients) return;
            controller.animateTo(
              0,
              duration: ZenithMotion.slide,
              curve: ZenithMotion.slideCurve,
            );
          } catch (e, stack) {
            AppLogger.reportError(e, stack);
          }
        });
      });

      return subscription?.cancel;
    }, [controller]);

    return Stack(
      children: [
        CustomScrollView(
          controller: controller,
          slivers: [
            if (isModal != true)
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                centerTitle: true,
                title: Text(
                  playlist.activeTrack?.name ?? context.l10n.not_playing,
                  style: headlineTextStyle,
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(40),
                  child: Text(
                    playlist.activeTrack?.artists.asString() ?? "",
                    // `ItemTextTitle_scene_subheader` — 17sp, dimmed.
                    style: zenithSubheaderTitle(theme.colorScheme)
                        .copyWith(color: theme.colorScheme.mutedForeground),
                  ),
                ),
              ),
            if (lyricValue != null &&
                lyricValue.lyrics.isNotEmpty &&
                lyricsState.asData?.value.static != true)
              SliverList.builder(
                itemCount: lyricValue.lyrics.length,
                itemBuilder: (context, index) {
                  final lyricSlice = lyricValue.lyrics[index];
                  final isActive = lyricSlice.time.inSeconds == currentTime;

                  if (isActive) {
                    controller.scrollToIndex(
                      index,
                      preferPosition: AutoScrollPosition.middle,
                    );
                  }
                  return AutoScrollTag(
                    key: ValueKey(index),
                    index: index,
                    controller: controller,
                    child: lyricSlice.text.isEmpty
                        ? Container(
                            padding: index == lyricValue.lyrics.length - 1
                                ? EdgeInsets.only(
                                    bottom: mediaQuery.height / 2,
                                  )
                                : null,
                          )
                        : Center(
                            child: Padding(
                              padding: index == lyricValue.lyrics.length - 1
                                  ? const EdgeInsets.all(8.0).copyWith(
                                      bottom: 100,
                                    )
                                  : const EdgeInsets.all(8.0),
                              child: AnimatedDefaultTextStyle(
                                duration: ZenithMotion.fade,
                                curve: ZenithMotion.fadeCurve,
                                style: TextStyle(
                                  color: isActive
                                      ? theme.colorScheme.foreground
                                      : theme.colorScheme.mutedForeground,
                                  fontWeight: isActive
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  fontSize: (isActive ? 28 : 26) *
                                      (textZoomLevel.value / 100),
                                ),
                                textAlign: TextAlign.center,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () async {
                                      final time = Duration(
                                        seconds:
                                            lyricSlice.time.inSeconds - delay,
                                      );
                                      if (time > audioPlayer.duration ||
                                          time.isNegative) {
                                        return;
                                      }
                                      audioPlayer.seek(time);
                                    },
                                    child: Text(lyricSlice.text),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  );
                },
              ),
            if (playlist.activeTrack != null &&
                (timedLyricsQuery.isLoading || timedLyricsQuery.isRefreshing))
              const SliverToBoxAdapter(child: ShimmerLyrics())
            else if (playlist.activeTrack != null &&
                (timedLyricsQuery.hasError)) ...[
              SliverToBoxAdapter(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.no_lyrics_available,
                    style: bodyTextTheme,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SliverGap(26),
              const SliverToBoxAdapter(
                child: Icon(SonolythIcons.noLyrics, size: 60),
              ),
            ] else if (lyricsState.asData?.value.static == true)
              SliverFillRemaining(
                child: Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: bodyTextTheme,
                      children: [
                        TextSpan(
                          text: context.l10n.synced_lyrics_not_available,
                        ),
                        TextSpan(
                          text: " ${context.l10n.plain_lyrics} ",
                          style: bodyTextTheme.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: context.l10n.tab_instead),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Builder(builder: (context) {
            final actions = [
              ZoomControls(
                label: context.l10n.lyrics_delay,
                value: delay,
                onChanged: (value) =>
                    ref.read(syncedLyricsDelayProvider.notifier).state = value,
                interval: 1,
                unit: "s",
                increaseIcon: const Icon(SonolythIcons.add),
                decreaseIcon: const Icon(SonolythIcons.remove),
                direction: isModal == true ? Axis.horizontal : Axis.vertical,
              ),
              ZoomControls(
                label: context.l10n.text_size,
                value: textZoomLevel.value,
                onChanged: (value) => textZoomLevel.value = value,
                min: 50,
                max: 200,
              ),
            ];

            return isModal == true
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: actions,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: actions,
                  );
          }),
        ),
      ],
    );
  }
}
