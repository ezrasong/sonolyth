import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/components/ui/sheet_aware_pop_scope.dart';
import 'package:sonolyth/components/ui/zenith_list_header.dart';
import 'package:sonolyth/modules/stats/summary/summary.dart';
import 'package:sonolyth/modules/stats/top/top.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class StatsPage extends HookConsumerWidget {
  static const name = "stats";

  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    // This is a **pushed** page now, opened from the Library header menu
    // (§38). It used to be a sidebar destination, which is why it had no
    // header on a phone (its only one sat behind a desktop-only flag, since
    // deleted with the rest of the window chrome in §40) and why its back
    // handler navigated *Home* rather than popping — sensible for a root-level
    // tab, wrong for a page you opened from a menu. It could be entered and
    // not left.
    return SheetAwarePopScope(
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            // `item_top_text_back_decor` — "‹ Library" — then the page's own
            // `scene_top_header` title, the same pair every pushed category
            // page wears (see `library.dart`).
            ZenithBackDecor(
              label: context.l10n.library,
              onPressed: () => context.router.maybePop(),
            ),
            ZenithListTitle(title: context.l10n.stats),
            const Gap(4),
          ],
          child: CustomScrollView(
            slivers: [
              const StatsPageSummarySection(),
              const StatsPageTopSection(),
              const SliverToBoxAdapter(
                child: SafeArea(
                  child: SizedBox(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
