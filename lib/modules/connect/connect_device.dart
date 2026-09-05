import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/routes.gr.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/collections/zenith_theme.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/constrains.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/provider/connect/clients.dart';

class ConnectDeviceButton extends HookConsumerWidget {
  final bool _sidebar;
  const ConnectDeviceButton({super.key}) : _sidebar = false;
  const ConnectDeviceButton.sidebar({super.key}) : _sidebar = true;

  @override
  Widget build(BuildContext context, ref) {
    final connectClients = ref.watch(connectClientsProvider);

    final hasServices =
        connectClients.asData?.value.services.isNotEmpty == true;

    if (_sidebar) {
      final mediaQuery = MediaQuery.sizeOf(context);

      if (mediaQuery.mdAndDown) {
        return ZenithTooltip(
          message: context.l10n.connect_to_a_device,
          child: IconButton.ghost(
            icon: const Icon(SonolythIcons.speaker),
            onPressed: () {
              context.navigateTo(const ConnectRoute());
            },
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        // `DialogPositiveButtonStyle`: the translucent 5% positive, never a
        // white-filled `Button.primary` — the wide sidebar's first render
        // showed one (§22).
        child: Button(
          style: zenithPositiveButton(Theme.of(context).colorScheme),
          onPressed: () {
            context.navigateTo(const ConnectRoute());
          },
          trailing: const Icon(SonolythIcons.speaker),
          child: Text(
            "${context.l10n.devices}"
            "${hasServices ? " (${connectClients.asData?.value.services.length})" : ""}",
          ),
        ),
      );
    }

    return Row(
      children: [
        SecondaryBadge(
          onPressed: () {
            context.navigateTo(const ConnectRoute());
          },
          style: const ButtonStyle.secondary(size: ButtonSize(.8)),
          leading: connectClients.asData?.value.resolvedService != null
              ? Center(
                  child: DotItem(
                    size: 6,
                    borderRadius: 10,
                    color: Theme.of(context).colorScheme.foreground,
                  ),
                )
              : null,
          child: Text(
            "${context.l10n.devices}"
            "${hasServices ? " (${connectClients.asData?.value.services.length})" : ""}",
          ),
        ),
        // A bare glyph: a white-filled disc has no source in Proxima.
        ZenithTooltip(
          message: context.l10n.connect_to_a_device,
          child: IconButton.ghost(
            icon: const Icon(SonolythIcons.speaker),
            onPressed: () {
              context.navigateTo(const ConnectRoute());
            },
          ),
        )
      ],
    );
  }
}
