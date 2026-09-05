import 'package:flutter/gestures.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_popup_card.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/artist/wikipedia.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The artist's Wikipedia blurb.
///
/// It used to be a 300dp block with the artist's photo darkened 50% behind the
/// text and a `Colors.sky[300]` "read more" link — the last coloured link and
/// the last decorative image-behind-text in the app. Proxima is achromatic and
/// its text surfaces are flat `popup_bg`, so the blurb is a `ZenithPopupCard`
/// and the link is the primary colour like every other link.
class ArtistPageFooter extends ConsumerWidget {
  final SonolythFullArtistObject artist;
  const ArtistPageFooter({super.key, required this.artist});

  @override
  Widget build(BuildContext context, ref) {
    final colorScheme = context.theme.colorScheme;
    final summary = ref.watch(artistWikipediaSummaryProvider(artist));
    final extract = summary.asData?.value?.extract;
    if (extract == null || extract.isEmpty) return const SizedBox.shrink();

    return ZenithPopupCard(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      padding: const EdgeInsets.all(20),
      maxWidth: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                SonolythIcons.wikipedia,
                color: colorScheme.foreground,
                size: 20,
              ),
              const Gap(8),
              Text("Wikipedia", style: zenithSubhead(colorScheme)),
            ],
          ),
          const Gap(12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: extract),
                TextSpan(
                  text: "\n\nRead more on Wikipedia",
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      await launchUrlString(
                        "https://en.wikipedia.org/wiki?curid="
                        "${summary.asData?.value?.pageid}",
                      );
                    },
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
