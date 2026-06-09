import 'package:flutter/services.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/utils/platform.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SpotiFlacDownloader {
  static const _channel = MethodChannel("com.ezrasong.sonolyth/spotiflac");

  static Future<bool> downloadTrack(SpotubeFullTrackObject track) {
    return downloadUrl(track.externalUri);
  }

  static Future<bool> downloadUrl(String url) async {
    if (url.trim().isEmpty) return false;

    if (kIsAndroid) {
      return await _channel.invokeMethod<bool>(
            "downloadUrl",
            {"url": url},
          ) ??
          false;
    }

    return launchUrlString(url);
  }
}
