import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Plain passthrough: the draggable semicircle scroll indicator this used to
/// add on mobile was unwanted visual noise, so lists render bare now. Kept as
/// a wrapper so call sites don't churn if an indicator ever returns.
class InterScrollbar extends HookWidget {
  final Widget child;
  final ScrollController controller;

  const InterScrollbar({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
