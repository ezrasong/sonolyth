import 'dart:io';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/modules/settings/youtube_engine_not_installed_dialog.dart';
import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
import 'package:sonolyth/services/kv_store/kv_store.dart';
import 'package:sonolyth/services/youtube_engine/yt_dlp_engine.dart';

void useCheckYtDlpInstalled(WidgetRef ref) {
  final context = useContext();

  useEffect(() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final youtubeEngine = ref.read(
        userPreferencesProvider.select(
          (value) => value.youtubeClientEngine,
        ),
      );

      final customPath =
          KVStoreService.getYoutubeEnginePath(YoutubeClientEngine.ytDlp);

      if (youtubeEngine == YoutubeClientEngine.ytDlp &&
          !await YtDlpEngine.isInstalled() &&
          (customPath == null || !await File(customPath).exists()) &&
          context.mounted) {
        await showDialog(
          context: context,
          builder: (context) =>
              YouTubeEngineNotInstalledDialog(engine: youtubeEngine),
        );
      }
    });

    return null;
  }, []);
}
