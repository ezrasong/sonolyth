import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:sonolyth/utils/platform.dart';

abstract class EncryptedKvStoreService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static FlutterSecureStorage get storage => _storage;

  static String? _encryptionKeySync;

  static Future<void> initialize() async {
    _encryptionKeySync = await encryptionKey;
  }

  static String get encryptionKeySync => _encryptionKeySync!;

  static bool get isUnsupportedPlatform =>
      kIsMacOS || kIsIOS || (kIsLinux && !kIsFlatpak);

  static Future<String> get encryptionKey async {
    if (isUnsupportedPlatform) {
      return KVStoreService.encryptionKey;
    }
    try {
      final value = await _storage.read(key: 'encryption');

      if (value == null) {
        // A previous failed secure-storage write may have stranded the key in
        // plain SharedPreferences — reuse it (and try to migrate it back into
        // secure storage) instead of generating a fresh key, which would make
        // every already-encrypted row permanently undecryptable.
        final fallback =
            KVStoreService.sharedPreferences.getString('encryption');
        if (fallback != null) {
          await setEncryptionKey(fallback);
          return fallback;
        }

        final key = const Uuid().v4();
        await setEncryptionKey(key);
        return key;
      }

      return value;
    } catch (e, stack) {
      // Falling back to plain SharedPreferences weakens at-rest protection —
      // make sure it shows up in logs instead of degrading silently.
      AppLogger.reportError(e, stack);
      return KVStoreService.encryptionKey;
    }
  }

  static Future<void> setEncryptionKey(String key) async {
    if (isUnsupportedPlatform) {
      await KVStoreService.setEncryptionKey(key);
      return;
    }

    try {
      await _storage.write(key: 'encryption', value: key);
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      await KVStoreService.setEncryptionKey(key);
    } finally {
      _encryptionKeySync = key;
    }
  }
}
