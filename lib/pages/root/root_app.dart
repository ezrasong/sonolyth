import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/modules/player/player_overlay.dart';
import 'package:sonolyth/modules/root/bottom_player.dart';
import 'package:sonolyth/modules/root/sonolyth_navigation_bar.dart';
import 'package:sonolyth/hooks/configurators/use_endless_playback.dart';
import 'package:sonolyth/modules/root/use_global_subscriptions.dart';
import 'package:sonolyth/hooks/configurators/use_zarz_verify_prompt.dart';
import 'package:sonolyth/provider/glance/glance.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';

@RoutePage()
class RootAppPage extends HookConsumerWidget {
  const RootAppPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final backgroundColor = context.theme.colorScheme.background;
    final systemIconBrightness = context.theme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    ref.listen(glanceProvider, (_, __) {});

    useGlobalSubscriptions(ref);
    useZarzVerifyPrompt(ref);
    useEndlessPlayback(ref);

    useEffect(() {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: backgroundColor,
          statusBarIconBrightness: systemIconBrightness,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: systemIconBrightness,
        ),
      );
      return null;
    }, [backgroundColor, systemIconBrightness]);

    // Remember the screen the user was on and restore it on next launch.
    useEffect(() {
      final router = context.router.root;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRoute = KVStoreService.lastRoutePath;
        if (lastRoute != null &&
            lastRoute.isNotEmpty &&
            lastRoute != "/" &&
            lastRoute != router.currentPath) {
          try {
            await router.navigateNamed(lastRoute);
          } catch (e, stack) {
            AppLogger.reportError(e, stack);
          }
        }
      });

      void persistRoute() {
        final path = router.currentPath;
        if (path.isEmpty || path == "/") return;
        // Don't persist transient player routes; restoring into them on a
        // cold start would land on an empty player with no playback state.
        // Keeping the last non-player path instead.
        if (path.startsWith("/player") || path.startsWith("/mini-player")) {
          return;
        }
        KVStoreService.setLastRoutePath(path);
      }

      router.addListener(persistRoute);
      return () => router.removeListener(persistRoute);
    }, const []);

    final scaffold = MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SafeArea(
        top: false,
        child: Scaffold(
          footers: const [
            BottomPlayer(),
            SonolythNavigationBar(),
          ],
          floatingFooter: true,
          // No sidebar wrapper: the navbar panel is the app's navigation at
          // every width, which is what Poweramp does (§38).
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // Reserve room for the floating footer stack (navigation bar
              // + mini-player) so scrollables aren't covered by it.
              padding: MediaQuery.paddingOf(context)
                  .copyWith(bottom: 140 * context.theme.scaling),
            ),
            // Dims while the player panel rises (Poweramp's list goes
            // dark under the album-art scene).
            child: const PlayerPageScrim(child: AutoRouter()),
          ),
        ),
      ),
    );

    return scaffold;
  }
}
