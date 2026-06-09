import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';

class DiscordNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> updatePresence(SpotubeTrackObject track) async {}

  Future<void> clear() async {}

  Future<void> close() async {}
}

final discordProvider =
    AsyncNotifierProvider<DiscordNotifier, void>(() => DiscordNotifier());
