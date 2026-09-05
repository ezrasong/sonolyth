import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_motion.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

class ExpandableSearchField extends StatelessWidget {
  final bool isFiltering;
  final ValueChanged<bool> onChangeFiltering;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  const ExpandableSearchField({
    super.key,
    required this.isFiltering,
    required this.onChangeFiltering,
    required this.searchController,
    required this.searchFocus,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: ZenithMotion.fade,
      curve: ZenithMotion.fadeCurve,
      opacity: isFiltering ? 1 : 0,
      child: AnimatedSize(
        duration: ZenithMotion.scene,
        curve: ZenithMotion.slideCurve,
        child: SizedBox(
          height: isFiltering ? 50 : 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CallbackShortcuts(
              bindings: {
                LogicalKeySet(LogicalKeyboardKey.escape): () {
                  onChangeFiltering(false);
                  searchController.clear();
                  searchFocus.unfocus();
                }
              },
              child: TextField(
                // `searchbar_bg`: fully round, page-coloured,
                // no stroke. See `zenithSearchField`.
                decoration: zenithSearchField(context.theme.colorScheme),
                focusNode: searchFocus,
                controller: searchController,
                placeholder: Text(context.l10n.search_tracks),
                features: const [
                  InputFeature.leading(Icon(SonolythIcons.search))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExpandableSearchButton extends StatelessWidget {
  final bool isFiltering;
  final FocusNode searchFocus;
  final Widget icon;
  final ValueChanged<bool>? onPressed;

  const ExpandableSearchButton({
    super.key,
    required this.isFiltering,
    required this.searchFocus,
    this.icon = const Icon(SonolythIcons.filter),
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ZenithTooltip(
      message: context.l10n.search,
      child: IconButton(
        icon: icon,
        // `ItemHeaderSearchButton`: transparent background in `@style/proxima`,
        // and its activated state (`hidden_activated_rounded_large`) resolves to
        // the page colour — i.e. nothing. The field sliding open *is* the state.
        variance: ButtonVariance.ghost,
        shape: ButtonShape.circle,
        onPressed: () {
          if (isFiltering) {
            searchFocus.requestFocus();
          } else {
            searchFocus.unfocus();
          }
          onPressed?.call(!isFiltering);
        },
      ),
    );
  }
}
