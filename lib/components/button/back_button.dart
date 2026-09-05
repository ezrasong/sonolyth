import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/collections/sonolyth_icons.dart';
import 'package:sonolyth/components/ui/zenith_tooltip.dart';
import 'package:sonolyth/extensions/context.dart';

class BackButton extends StatelessWidget {
  final Color? color;
  final IconData icon;
  const BackButton({
    super.key,
    this.color,
    this.icon = SonolythIcons.angleLeft,
  });

  @override
  Widget build(BuildContext context) {
    return ZenithTooltip(
      message: context.l10n.back,
      child: IconButton.ghost(
        size: const ButtonSize(1.2),
        icon: Icon(icon, color: color),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}
