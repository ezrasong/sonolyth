import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/ui/zenith_popup_card.dart';

/// A getting-started step. The name is historical — it was once a blurred,
/// bordered card — and it now is `popup_bg` like every other dialog-shaped
/// surface; see [ZenithPopupCard] for the token.
class BlurCard extends StatelessWidget {
  final Widget child;
  const BlurCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ZenithPopupCard(child: child);
}
