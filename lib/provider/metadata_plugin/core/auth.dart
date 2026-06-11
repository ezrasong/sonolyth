import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';

/// The plugin runtime restores stored credentials asynchronously after boot
/// (and after the in-place plugin update swaps the runtime), so a single
/// synchronous [isAuthenticated] probe at build time can report a stale
/// "logged out". Re-check a couple of times so the UI self-heals instead of
/// requiring an app restart.
void _scheduleAuthRechecks(
  bool Function() isAuthenticated,
  void Function(bool) emit,
  void Function(void Function()) onDispose,
) {
  var disposed = false;
  onDispose(() => disposed = true);
  for (final delay in const [Duration(seconds: 3), Duration(seconds: 10)]) {
    Timer(delay, () {
      if (disposed) return;
      emit(isAuthenticated());
    });
  }
}

class MetadataPluginAuthenticatedNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() async {
    final defaultPluginConfig = ref.watch(metadataPluginsProvider);
    if (defaultPluginConfig.asData?.value.defaultMetadataPluginConfig?.abilities
            .contains(PluginAbilities.authentication) !=
        true) {
      return false;
    }

    final defaultPlugin = await ref.watch(metadataPluginProvider.future);
    if (defaultPlugin == null) {
      return false;
    }

    final sub = defaultPlugin.auth.authStateStream.listen((event) {
      state = AsyncData(defaultPlugin.auth.isAuthenticated());
    });

    ref.onDispose(() {
      sub.cancel();
    });

    final initial = defaultPlugin.auth.isAuthenticated();
    if (!initial) {
      _scheduleAuthRechecks(
        defaultPlugin.auth.isAuthenticated,
        (value) => state = AsyncData(value),
        ref.onDispose,
      );
    }
    return initial;
  }
}

final metadataPluginAuthenticatedProvider =
    AsyncNotifierProvider<MetadataPluginAuthenticatedNotifier, bool>(
  MetadataPluginAuthenticatedNotifier.new,
);

class AudioSourcePluginAuthenticatedNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() async {
    final defaultPluginConfig = ref.watch(metadataPluginsProvider);
    if (defaultPluginConfig
            .asData?.value.defaultAudioSourcePluginConfig?.abilities
            .contains(PluginAbilities.authentication) !=
        true) {
      return false;
    }

    final defaultPlugin = await ref.watch(audioSourcePluginProvider.future);
    if (defaultPlugin == null) {
      return false;
    }

    final sub = defaultPlugin.auth.authStateStream.listen((event) {
      state = AsyncData(defaultPlugin.auth.isAuthenticated());
    });

    ref.onDispose(() {
      sub.cancel();
    });

    final initial = defaultPlugin.auth.isAuthenticated();
    if (!initial) {
      _scheduleAuthRechecks(
        defaultPlugin.auth.isAuthenticated,
        (value) => state = AsyncData(value),
        ref.onDispose,
      );
    }
    return initial;
  }
}

final audioSourcePluginAuthenticatedProvider =
    AsyncNotifierProvider<AudioSourcePluginAuthenticatedNotifier, bool>(
  AudioSourcePluginAuthenticatedNotifier.new,
);
