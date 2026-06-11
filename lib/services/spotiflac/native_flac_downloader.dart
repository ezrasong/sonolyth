import 'dart:io';

import 'package:dio/dio.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path;
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/spotiflac/deezer_crypto.dart';
import 'package:sonolyth/services/spotiflac/providers/spotiflac_provider.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';
import 'package:sonolyth/utils/service_utils.dart';

class SpotiFlacDownloadException implements Exception {
  final String message;
  const SpotiFlacDownloadException(this.message);
  @override
  String toString() => "SpotiFlacDownloadException: $message";
}

/// Thrown when a track couldn't be sourced specifically because the gateway
/// rate-limited every provider. The download manager treats this differently
/// from a real "no match": it pauses the queue and retries rather than marking
/// the track permanently failed.
class SpotiFlacRateLimitException extends SpotiFlacDownloadException {
  const SpotiFlacRateLimitException()
      : super("Rate limited by the download gateway");
}

/// Downloads a track's lossless file entirely in-app: resolves a direct URL
/// from the ordered [providers], streams it to disk with progress, decrypts
/// when the source requires it, and tags the result.
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
    // Per-provider failure reasons, so a total failure can say *why*
    // (rate limited vs no match vs network) instead of a generic message.
    final failures = <String>[];
    // Whether every failure so far was a rate-limit (vs a genuine no-match), so
    // the manager can pause-and-retry instead of failing the track outright.
    var rateLimited = false;
    for (final provider in providers) {
      final quality = qualityByProvider[provider.id] ?? provider.defaultQuality;
      try {
        resolution = await provider.resolve(track, quality);
        if (resolution == null) {
          failures.add("${provider.displayName}: no match");
        }
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        final is429 = e.response?.statusCode == 429;
        rateLimited = rateLimited || is429;
        failures.add(
          "${provider.displayName}: ${is429 ? "rate limited" : "network error"}",
        );
        resolution = null;
      } on ZarzRateLimitedException {
        rateLimited = true;
        failures.add("${provider.displayName}: rate limited");
        resolution = null;
      } catch (e) {
        failures.add("${provider.displayName}: $e");
        resolution = null;
      }
      if (resolution != null) break;
    }

    if (resolution == null) {
      // If a provider actually matched but the gateway was rate-limiting,
      // signal that distinctly so the queue pauses and retries.
      if (rateLimited) {
        throw const SpotiFlacRateLimitException();
      }
      throw SpotiFlacDownloadException(
        "Couldn't source this track — ${failures.join("; ")}",
      );
    }

    final directory = Directory(downloadDirectory);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = _buildFileName(track, resolution.fileExtension);
    final outputPath = path.join(downloadDirectory, fileName);
    final partPath = "$outputPath.part";

    try {
      // Stream straight to disk; buffering whole FLACs in memory adds up
      // fast on mobile during long playlist runs.
      await _dio.download(
        resolution.url,
        partPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            // Reserve the last 10% for decrypt + tagging.
            onProgress((received / total) * 0.9);
          }
        },
      );

      final partFile = File(partPath);
      final fileLength = await partFile.length();
      if (fileLength == 0) {
        throw const SpotiFlacDownloadException("Empty download stream");
      }

      if (resolution.encryption == SpotiFlacEncryption.deezerBlowfish) {
        final decrypted = DeezerCrypto.decrypt(
          await partFile.readAsBytes(),
          resolution.decryptionSeed ?? "",
        );
        await File(outputPath).writeAsBytes(decrypted);
        await partFile.delete();
      } else {
        if (await File(outputPath).exists()) {
          await File(outputPath).delete();
        }
        await partFile.rename(outputPath);
      }
    } catch (_) {
      // Never leave half-written .part files behind.
      final partFile = File(partPath);
      if (await partFile.exists()) {
        await partFile.delete().catchError((_) => partFile);
      }
      rethrow;
    }

    onProgress?.call(0.95);

    await _writeTags(track, outputPath, await File(outputPath).length());
    onProgress?.call(1.0);

    return outputPath;
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
