import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sonolyth/provider/user_preferences/user_preferences_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show FrbException;
import 'package:sonolyth/utils/service_utils.dart';

const supportedAudioTypes = [
  "audio/webm",
  "audio/ogg",
  "audio/mpeg",
  "audio/mp4",
  "audio/opus",
  "audio/wav",
  "audio/aac",
  "audio/flac",
  "audio/x-flac",
  "audio/x-wav",
];

const imgMimeToExt = {
  "image/png": ".png",
  "image/jpeg": ".jpg",
  "image/webp": ".webp",
  "image/gif": ".gif",
};

typedef MetadataFile = ({
  Metadata? metadata,
  File file,
  String? art,
});

final localTracksProvider =
    FutureProvider<Map<String, List<SonolythLocalTrackObject>>>((ref) async {
  try {
    if (kIsWeb) return {};
    final Map<String, List<SonolythLocalTrackObject>> libraryToTracks = {};

    final downloadLocation = ref.watch(
      userPreferencesProvider.select((s) => s.downloadLocation),
    );

    if (downloadLocation.isEmpty) {
      return {};
    }

    final downloadDir = Directory(downloadLocation);
    final cacheDir =
        Directory(await UserPreferencesNotifier.getMusicCacheDir());
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final localLibraryLocations = ref.watch(
      userPreferencesProvider.select((s) => s.localLibraryLocation),
    );

    // One platform-channel call for the whole scan, not one per file.
    final tempDirPath = (await getTemporaryDirectory()).path;

    for (final location in [
      downloadLocation,
      cacheDir.path,
      ...localLibraryLocations
    ]) {
      if (location.isEmpty) continue;
      final entities = <File>[];
      if (await Directory(location).exists()) {
        try {
          final dirEntities =
              await Directory(location).list(recursive: true).toList();

          entities.addAll(
            dirEntities.where(
              (e) {
                final mime = lookupMimeType(e.path) ??
                    (extension(e.path) == ".opus" ? "audio/opus" : null);

                return e is File && supportedAudioTypes.contains(mime);
              },
            ).cast<File>(),
          );
        } catch (e, stack) {
          AppLogger.reportError(e, stack);
        }
      }

      // Batched: an unbounded Future.wait over thousands of files would hold
      // every cover-art buffer in memory at once and flood IO.
      const batchSize = 16;
      final List<MetadataFile> filesWithMetadata = [];
      for (var i = 0; i < entities.length; i += batchSize) {
        final batch = entities.sublist(i, min(i + batchSize, entities.length));
        final results = await Future.wait(
          batch.map((file) async {
            try {
              final metadata = await MetadataGod.readMetadata(file: file.path);

              // Path hash keeps same-named files in different folders from
              // sharing (and clobbering) one cached art file.
              final pathHash = md5
                  .convert(utf8.encode(file.path))
                  .toString()
                  .substring(0, 8);
              final imageFile = File(
                join(
                  tempDirPath,
                  "spotube",
                  "${ServiceUtils.sanitizeFilename(basenameWithoutExtension(file.path))}-$pathHash"
                      // Unknown art mime types fall back to .jpg instead of
                      // crashing the scan and dropping the track entirely.
                      "${imgMimeToExt[metadata.picture?.mimeType ?? "image/jpeg"] ?? ".jpg"}",
                ),
              );
              final hasEmbeddedArt = metadata.picture != null;
              var artExists = await imageFile.exists();
              if (!artExists && hasEmbeddedArt) {
                await imageFile.create(recursive: true);
                await imageFile.writeAsBytes(
                  metadata.picture?.data ?? [],
                  mode: FileMode.writeOnly,
                );
                artExists = true;
              }

              return (
                metadata: metadata,
                file: file,
                // Tracks without art must get null (placeholder) rather than
                // a path to a file that was never written.
                art: artExists ? imageFile.path : null,
              );
            } catch (e, stack) {
              if (e case FrbException() || TimeoutException()) {
                return (file: file, metadata: null, art: null);
              }
              AppLogger.reportError(e, stack);
              return null;
            }
          }),
        );
        filesWithMetadata.addAll(results.nonNulls);
      }

      final tracksFromMetadata = filesWithMetadata
          .map(
            (fileWithMetadata) => SonolythTrackObject.localTrackFromFile(
              fileWithMetadata.file,
              metadata: fileWithMetadata.metadata,
              art: fileWithMetadata.art,
            ) as SonolythLocalTrackObject,
          )
          .toList();

      // Downloaded collections live in `<downloadLocation>/<name>/` subfolders
      // (see DownloadManager). Group the download folder's tracks by their
      // immediate subfolder so each downloaded playlist/album resurfaces as
      // its own local folder; root-level files stay under the download folder.
      if (location == downloadLocation) {
        for (final track in tracksFromMetadata) {
          final segments = split(relative(track.path, from: downloadLocation));
          final key = segments.length > 1
              ? join(downloadLocation, segments.first)
              : downloadLocation;
          (libraryToTracks[key] ??= []).add(track);
        }
        // Ensure the root folder always has an entry even when every file is
        // nested in a subfolder, so the "Downloads" tile still shows.
        libraryToTracks[downloadLocation] ??= [];
      } else {
        libraryToTracks[location] = tracksFromMetadata;
      }
    }
    return libraryToTracks;
  } catch (e, stack) {
    AppLogger.reportError(e, stack);
    return {};
  }
});
