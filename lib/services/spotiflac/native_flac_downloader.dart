import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path;
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/deezer_crypto.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/utils/service_utils.dart';

class SpotiFlacDownloadException implements Exception {
  final String message;
  const SpotiFlacDownloadException(this.message);
  @override
  String toString() => "SpotiFlacDownloadException: $message";
}

/// Downloads a track's lossless file entirely in-app: resolves a direct URL
/// from the ordered [providers], streams it with progress, decrypts when the
/// source requires it, writes it into [downloadDirectory] and tags it.
class NativeFlacDownloader {
  final Dio _dio;

  NativeFlacDownloader([Dio? dio]) : _dio = dio ?? Dio();

  Future<String> download({
    required SonolythFullTrackObject track,
    required List<SpotiFlacProvider> providers,
    required String downloadDirectory,
    required Map<String, String> qualityByProvider,
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    if (providers.isEmpty) {
      throw const SpotiFlacDownloadException("No download providers enabled");
    }

    SpotiFlacDownloadResolution? resolution;
    for (final provider in providers) {
      final quality = qualityByProvider[provider.id] ?? provider.defaultQuality;
      try {
        resolution = await provider.resolve(track, quality);
      } catch (_) {
        resolution = null;
      }
      if (resolution != null) break;
    }

    if (resolution == null) {
      throw const SpotiFlacDownloadException(
        "No provider could find this track",
      );
    }

    final directory = Directory(downloadDirectory);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = _buildFileName(track, resolution.fileExtension);
    final outputPath = path.join(downloadDirectory, fileName);

    final bytes = await _downloadBytes(
      resolution.url,
      cancelToken: cancelToken,
      onProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          // Reserve the last 10% for decrypt + tagging.
          onProgress((received / total) * 0.9);
        }
      },
    );

    final finalBytes = resolution.encryption == SpotiFlacEncryption.deezerBlowfish
        ? DeezerCrypto.decrypt(bytes, resolution.decryptionSeed ?? "")
        : bytes;

    final file = File(outputPath);
    await file.writeAsBytes(finalBytes);
    onProgress?.call(0.95);

    await _writeTags(track, outputPath, finalBytes.length);
    onProgress?.call(1.0);

    return outputPath;
  }

  Future<Uint8List> _downloadBytes(
    String url, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const SpotiFlacDownloadException("Empty download stream");
    }
    return Uint8List.fromList(data);
  }

  Future<void> _writeTags(
    SonolythFullTrackObject track,
    String filePath,
    int fileLength,
  ) async {
    try {
      final imageBytes = await ServiceUtils.downloadImage(
        track.album.images.asUrlString(
          placeholder: ImagePlaceholder.albumArt,
          index: 1,
        ),
      );
      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: track.toMetadata(
          imageBytes: imageBytes,
          fileLength: fileLength,
        ),
      );
    } catch (_) {
      // Tagging is best-effort; the audio file itself is already written.
    }
  }

  String _buildFileName(SonolythFullTrackObject track, String extension) {
    final artists = track.artists.map((a) => a.name).join(", ");
    final base = artists.isEmpty ? track.name : "$artists - ${track.name}";
    final sanitized = ServiceUtils.sanitizeFilename(base).trim();
    final safe = sanitized.isEmpty ? track.id : sanitized;
    return "$safe.$extension";
  }
}

final nativeFlacDownloader = NativeFlacDownloader();
