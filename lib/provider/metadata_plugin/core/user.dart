import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/core/auth.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';

final metadataPluginUserProvider = FutureProvider<SonolythUserObject?>(
  (ref) async {
    final metadataPlugin = await ref.watch(metadataPluginProvider.future);
    final authenticated =
        await ref.watch(metadataPluginAuthenticatedProvider.future);

    if (!authenticated || metadataPlugin == null) {
      return null;
    }
    try {
      final user = await metadataPlugin.user.me();
      await KVStoreService.setCachedUserProfile(user.toJson());
      return user;
    } catch (e, stack) {
      // A rate-limited / flaky profile fetch shouldn't blank everything that
      // hangs off the profile (Liked Tracks row, owner checks); fall back to
      // the last known profile when there is one.
      final cached = KVStoreService.cachedUserProfile;
      if (cached == null) rethrow;
      AppLogger.reportError(e, stack);
      return SonolythUserObject.fromJson(cached);
    }
  },
);
