import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:skeletonizer/skeletonizer.dart';

class ShimmerLyrics extends HookWidget {
  const ShimmerLyrics({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        itemCount: 30,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final texts = [
            "Lorem ipsum",
            "consectetur.",
            "Sed",
            "Sed non risus",
          ]..shuffle();
          // Wrap, not Row: four fixed words in a Row overflowed by 11px once
          // the sidebar rail took 70dp of a phone's width.
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [for (final text in texts) Text(text)],
          );
        },
      ),
    );
  }
}
