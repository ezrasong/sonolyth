import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/ui/button_tile.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/services/audio_player/audio_player.dart';

class ConnectPageLocalDevices extends HookWidget {
  const ConnectPageLocalDevices({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:typography) = Theme.of(context);
    final devicesFuture = useFuture(audioPlayer.devices);
    final devicesStream = useStream(audioPlayer.devicesStream);
    final selectedDeviceFuture = useFuture(audioPlayer.selectedDevice);
    final selectedDeviceStream = useStream(audioPlayer.selectedDeviceStream);

    final devices = devicesStream.data ?? devicesFuture.data;
    final selectedDevice =
        selectedDeviceStream.data ?? selectedDeviceFuture.data;

    if (devices == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        const SliverGap(10),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          sliver: SliverToBoxAdapter(
            child: Text(
              context.l10n.this_device,
              style: typography.bold,
            ),
          ),
        ),
        const SliverGap(10),
        SliverList.separated(
          itemCount: devices.length,
          separatorBuilder: (context, index) => const Gap(10),
          itemBuilder: (context, index) {
            final device = devices[index];

            return ButtonTile(
              selected: selectedDevice == device,
              onPressed: () => audioPlayer.setAudioDevice(device),
              leading: const Icon(SonolythIcons.speaker),
              title: Text(device.description),
              subtitle: Text(device.name),
            );
          },
        ),
        const SliverGap(200)
      ],
    );
  }
}
