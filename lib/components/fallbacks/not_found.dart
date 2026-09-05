import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/components/fallbacks/zenith_illustration.dart';

class NotFound extends StatelessWidget {
  const NotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ZenithIllustration(
          illustration: UndrawIllustration.empty,
          height: 200 * context.theme.scaling,
        ),
        const Gap(10),
        Text(
          context.l10n.nothing_found,
          textAlign: TextAlign.center,
        ).muted().small()
      ],
    );
  }
}
