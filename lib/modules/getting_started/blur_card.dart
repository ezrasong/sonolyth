import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class BlurCard extends HookConsumerWidget {
  final Widget child;
  const BlurCard({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xff181818),
        border: Border.all(color: const Color(0xff2a2a2a)),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxWidth: 400),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: child,
        ),
      ),
    );
  }
}
