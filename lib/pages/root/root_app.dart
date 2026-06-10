import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:spotube/modules/root/bottom_player.dart';
import 'package:spotube/modules/root/sidebar/sidebar.dart';
import 'package:spotube/modules/root/spotube_navigation_bar.dart';
import 'package:spotube/hooks/configurators/use_endless_playback.dart';
import 'package:spotube/modules/root/use_global_subscriptions.dart';
import 'package:spotube/provider/glance/glance.dart';
import 'package:spotube/services/kv_store/kv_store.dart';
import 'package:spotube/services/logger/logger.dart';

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
            SpotubeNavigationBar(),
          ],
          floatingFooter: true,
          child: Sidebar(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.paddingOf(context)
                    .copyWith(bottom: 100 * context.theme.scaling),
              ),
              child: const AutoRouter(),
            ),
          ),
        ),
      ),
    );

    return scaffold;
  }
}
