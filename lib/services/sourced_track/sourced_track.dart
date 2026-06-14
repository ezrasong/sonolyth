import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/models/playback/track_sources.dart';
import 'package:sonolyth/provider/database/database.dart';
import 'package:sonolyth/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:sonolyth/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sonolyth/services/dio/dio.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:sonolyth/services/metadata/errors/exceptions.dart';

import 'package:sonolyth/services/sourced_track/exceptions.dart';
import 'package:sonolyth/services/sourced_track/qobuz_audio_source.dart';
import 'package:sonolyth/services/metadata/endpoints/audio_source.dart';
import 'package:sonolyth/provider/audio_player/qobuz_playback.dart';
import 'package:sonolyth/services/spotiflac/track_matching.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';

/// Markers of audio-first uploads (what we want to play).
final audioOnlyRegex = RegExp(
  r"(official\s*audio|audio\s*only|\blyrics?\b|lyric\s*video|visuali[sz]er|color\s*coded|topic)",
  caseSensitive: false,
);

/// Markers of music videos (intros/outros/dialogue — avoid by default).
final musicVideoRegex = RegExp(
  r"(\bm\/v\b|\bmv\b|music\s*video|official\s*video|video\s*oficial|뮤직비디오|\bteaser\b|\btrailer\b)",
  caseSensitive: false,
);

class SourcedTrack extends BasicSourcedTrack {
  final Ref ref;

  SourcedTrack({
    required this.ref,
    required super.info,
    required super.query,
    required super.source,
    required super.siblings,
    required super.sources,
  });

  static Future<SourcedTrack> fetchFromTrack({
    required SonolythFullTrackObject query,
    required Ref ref,
  }) async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSource == null || audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    final database = ref.read(databaseProvider);
    final cachedSource = await (database.select(database.sourceMatchTable)
          ..where((s) =>
              s.trackId.equals(query.id) &
              s.sourceType.equals(audioSourceConfig.slug))
          ..limit(1)
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .get()
        .then((s) => s.firstOrNull);

    if (cachedSource == null) {
      final siblings = await fetchSiblings(ref: ref, query: query);
      if (siblings.isEmpty) {
        throw TrackNotFoundError(query);
      }

      // Resolve the first sibling that actually yields a playable stream. A
      // Qobuz match that matched-by-ISRC but failed to resolve a URL then
      // falls through to the next candidate (e.g. a YouTube sibling) instead
      // of leaving the track silent.
      SonolythAudioSourceMatchObject? chosen;
      List<SonolythAudioSourceStreamObject> manifest = const [];
      for (final candidate in siblings) {
        try {
          final streams = await _resolveStreams(audioSource.audioSource, candidate);
          if (streams.isNotEmpty) {
            chosen = candidate;
            manifest = streams;
            break;
          }
        } catch (_) {
          // Candidate failed to resolve; try the next one.
        }
      }
      if (chosen == null) {
        throw TrackNotFoundError(query);
      }

      // Cache the match only after the stream fetch succeeds — caching first
      // would poison the table with a match that can't actually stream, and
      // every retry would then take the cached (sibling-less) path.
      await database.into(database.sourceMatchTable).insert(
            SourceMatchTableCompanion.insert(
              trackId: query.id,
              sourceInfo: Value(jsonEncode(chosen)),
              sourceType: audioSourceConfig.slug,
            ),
          );

      return SourcedTrack(
        ref: ref,
        siblings: siblings.where((s) => s.id != chosen!.id).toList(),
        info: chosen,
        source: audioSourceConfig.slug,
        sources: manifest,
        query: query,
      );
    }
    final item = SonolythAudioSourceMatchObject.fromJson(
      jsonDecode(cachedSource.sourceInfo),
    );

    List<SonolythAudioSourceStreamObject> manifest;
    try {
      manifest = await _resolveStreams(audioSource.audioSource, item);
    } on ZarzRateLimitedException {
      // Qobuz's gateway is rate-limiting. Don't purge the (good) cached match —
      // it resumes once the limit clears. Play via the YouTube plugin right now
      // so the block is never felt, without rewriting the cache.
      return _fetchViaPlugin(
        query: query,
        ref: ref,
        pluginAudioSource: audioSource.audioSource,
        slug: audioSourceConfig.slug,
      );
    } catch (_) {
      manifest = const [];
    }
    if (manifest.isEmpty) {
      // The cached match no longer streams (taken down, plugin change, or a
      // Qobuz URL that won't resolve). Purge it and resolve fresh; otherwise
      // the track stays permanently unplayable — the cached path has no
      // siblings to fall back to.
      await (database.delete(database.sourceMatchTable)
            ..where((s) =>
                s.trackId.equals(query.id) &
                s.sourceType.equals(audioSourceConfig.slug)))
          .go();
      return fetchFromTrack(query: query, ref: ref);
    }

    final sourcedTrack = SourcedTrack(
      ref: ref,
      siblings: [],
      sources: manifest,
      info: item,
      query: query,
      source: audioSourceConfig.slug,
    );

    AppLogger.log.i("${query.name}: ${sourcedTrack.url}");

    return sourcedTrack;
  }

  static List<SonolythAudioSourceMatchObject> rankResults(
    List<SonolythAudioSourceMatchObject> results,
    SonolythFullTrackObject track,
  ) {
    return results
        .map((sibling) {
          int score = 0;
          final title = sibling.title.toLowerCase();
          final normalizedTitle = TrackMatching.normalize(sibling.title);

          for (final artist in track.artists) {
            final artistName = artist.name.toLowerCase();
            final channel = sibling.artists.map((a) => a.toLowerCase());

            if (channel.any((a) => a == artistName)) {
              score += 2;
            }
            // YouTube's auto-generated "<artist> - Topic" channels are pure
            // audio uploads — the best possible match.
            if (channel.any((a) => a.contains("$artistName - topic"))) {
              score += 4;
            }

            if (normalizedTitle.contains(TrackMatching.normalize(artist.name))) {
              score += 1;
            }
          }

          // Normalized comparison so punctuation/feat. formatting differences
          // ("Song (feat. X)" vs "Song ft. X") don't lose the title match.
          if (normalizedTitle.contains(TrackMatching.normalize(track.name)) ||
              TrackMatching.titleSimilarity(sibling.title, track.name) >= 0.8) {
            score += 3;
          }

          // Live/remix/cover/sped-up... uploads of a plain studio title are
          // wrong recordings; one stray keyword shouldn't be outweighed by a
          // good duration match.
          score -= (TrackMatching.mismatchedVariants(track.name, sibling.title)
                      .length *
                  5)
              .clamp(0, 10);

          // Prefer the song itself over the music video: MVs carry intros,
          // outros and dialogue, so audio-marked uploads win and duration
          // closeness to the actual track is weighted heavily.
          if (audioOnlyRegex.hasMatch(title)) {
            score += 3;
          }
          if (musicVideoRegex.hasMatch(title)) {
            score -= 4;
          }

          final durationDiffSeconds =
              (sibling.duration.inSeconds - track.durationMs ~/ 1000).abs();
          if (durationDiffSeconds <= 3) {
            score += 6;
          } else if (durationDiffSeconds <= 10) {
            score += 3;
          } else if (durationDiffSeconds > 45) {
            score -= 4;
          }

          return (sibling: sibling, score: score);
        })
        .sorted((a, b) => b.score.compareTo(a.score))
        .map((e) => e.sibling)
        .toList();
  }

  static Future<List<SonolythAudioSourceMatchObject>> fetchSiblings({
    required SonolythFullTrackObject query,
    required Ref ref,
  }) async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);

    if (audioSource == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    final pluginSiblings = rankResults(
      await audioSource.audioSource.matches(query),
      query,
    );

    // When the Qobuz playback source is enabled, prefer its ISRC-exact,
    // lossless matches and keep the plugin (YouTube) results as the coverage
    // fallback for tracks Qobuz doesn't carry.
    if (await ref.read(qobuzPlaybackEnabledProvider.future)) {
      try {
        final qobuzMatches = await QobuzAudioSource().matches(query);
        if (qobuzMatches.isNotEmpty) {
          return <SonolythAudioSourceMatchObject>{
            ...qobuzMatches,
            ...pluginSiblings,
          }.toList();
        }
      } catch (_) {
        // Qobuz lookup failed (rate limit/network) — fall back to the plugin.
      }
    }

    return pluginSiblings.toSet().toList();
  }

  /// Routes stream resolution for [match] to the source that produced it: the
  /// native Qobuz source for Qobuz-owned matches, otherwise the active plugin
  /// audio source (YouTube).
  static Future<List<SonolythAudioSourceStreamObject>> _resolveStreams(
    MetadataPluginAudioSourceEndpoint pluginAudioSource,
    SonolythAudioSourceMatchObject match,
  ) async {
    if (QobuzAudioSource.ownsMatch(match)) {
      return QobuzAudioSource().streams(match);
    }
    return pluginAudioSource.streams(match);
  }

  /// Resolves [query] through the plugin (YouTube) source only, without
  /// touching the source-match cache. Used as the live fallback when a cached
  /// Qobuz match is temporarily rate-limited: the user keeps playing while the
  /// cached Qobuz match stays intact for when the limit clears.
  static Future<SourcedTrack> _fetchViaPlugin({
    required SonolythFullTrackObject query,
    required Ref ref,
    required MetadataPluginAudioSourceEndpoint pluginAudioSource,
    required String slug,
  }) async {
    final ranked = rankResults(await pluginAudioSource.matches(query), query)
        .toSet()
        .toList();
    for (final candidate in ranked) {
      try {
        final streams = await pluginAudioSource.streams(candidate);
        if (streams.isNotEmpty) {
          return SourcedTrack(
            ref: ref,
            info: candidate,
            query: query,
            source: slug,
            sources: streams,
            siblings: ranked.where((s) => s.id != candidate.id).toList(),
          );
        }
      } catch (_) {
        // Try the next candidate.
      }
    }
    throw TrackNotFoundError(query);
  }

  Future<SourcedTrack> copyWithSibling() async {
    if (siblings.isNotEmpty) {
      return this;
    }
    final fetchedSiblings = await fetchSiblings(ref: ref, query: query);

    return SourcedTrack(
      ref: ref,
      siblings: fetchedSiblings.where((s) => s.id != info.id).toList(),
      source: source,
      sources: sources,
      info: info,
      query: query,
    );
  }

  Future<SourcedTrack?> swapWithSibling(
    SonolythAudioSourceMatchObject sibling,
  ) async {
    if (sibling.id == info.id) {
      return null;
    }

    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSource == null || audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    // a sibling source that was fetched from the search results
    final isStepSibling = siblings.none((s) => s.id == sibling.id);

    final newSourceInfo = isStepSibling
        ? sibling
        : siblings.firstWhere((s) => s.id == sibling.id);

    final newSiblings = siblings.where((s) => s.id != sibling.id).toList()
      ..insert(0, info);

    final manifest = await _resolveStreams(audioSource.audioSource, newSourceInfo);

    final database = ref.read(databaseProvider);

    // Delete the old Entry
    await (database.sourceMatchTable.delete()
          ..where(
            (table) =>
                table.trackId.equals(query.id) &
                table.sourceType.equals(audioSourceConfig.slug),
          ))
        .go();

    await database.into(database.sourceMatchTable).insert(
          SourceMatchTableCompanion.insert(
            trackId: query.id,
            sourceInfo: Value(jsonEncode(sibling)),
            sourceType: audioSourceConfig.slug,
            createdAt: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );

    return SourcedTrack(
      ref: ref,
      source: source,
      siblings: newSiblings,
      sources: manifest,
      info: newSourceInfo,
      query: query,
    );
  }

  Future<SourcedTrack?> swapWithSiblingOfIndex(int index) {
    return swapWithSibling(siblings[index]);
  }

  Future<SourcedTrack> refreshStream() async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSource == null || audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    List<SonolythAudioSourceStreamObject> validStreams = [];

    final stringBuffer = StringBuffer();
    for (final source in sources) {
      final res = await globalDio.head(
        source.url,
        options:
            Options(validateStatus: (status) => status != null && status < 500),
      );

      stringBuffer.writeln(
        "[${query.id}] ${res.statusCode} ${source.container} ${source.codec} ${source.bitrate}",
      );

      if (res.statusCode! < 400) {
        validStreams.add(source);
      }
    }

    AppLogger.log.d(stringBuffer.toString());

    if (validStreams.isEmpty) {
      validStreams = await _resolveStreams(audioSource.audioSource, info);
    }

    final sourcedTrack = SourcedTrack(
      ref: ref,
      siblings: siblings,
      source: source,
      sources: validStreams,
      info: info,
      query: query,
    );

    AppLogger.log.i("Refreshing ${query.name}: ${sourcedTrack.url}");

    return sourcedTrack;
  }

  String? get url {
    final preferences = ref.read(audioSourcePresetsProvider);

    return getUrlOfQuality(
      preferences.presets[preferences.selectedStreamingContainerIndex],
      preferences.selectedStreamingQualityIndex,
    );
  }

  /// Returns the URL of the track based on the codec and quality preferences.
  /// If an exact match is not found, it will return the closest match based on
  /// the user's audio quality preference.
  ///
  /// If no sources match the codec, it will return the first or last source
  /// based on the user's audio quality preference.
  SonolythAudioSourceStreamObject? getStreamOfQuality(
    SonolythAudioSourceContainerPreset preset,
    int qualityIndex,
  ) {
    if (sources.isEmpty) return null;

    final quality = preset.qualities[qualityIndex];

    final exactMatch = sources.firstWhereOrNull(
      (source) {
        if (source.container != preset.name) return false;

        if (quality case SonolythAudioLosslessContainerQuality()) {
          return source.sampleRate == quality.sampleRate &&
              source.bitDepth == quality.bitDepth;
        } else {
          return source.bitrate ==
              (quality as SonolythAudioLossyContainerQuality).bitrate;
        }
      },
    );

    if (exactMatch != null) {
      return exactMatch;
    }

    // Find the preset with closest quality to the supplied quality. When the
    // plugin offers no source in the preset's container at all, fall back to
    // any source instead of throwing (a bare reduce() on an empty iterable
    // would 500 the playback server and the track wouldn't play).
    final sameContainer = sources.where((source) {
      return source.container == preset.name;
    });
    if (sameContainer.isEmpty) {
      return sources.firstOrNull;
    }
    return sameContainer.reduce((prev, curr) {
      if (quality is SonolythAudioLosslessContainerQuality) {
        final prevDiff = ((prev.sampleRate ?? 0) - quality.sampleRate).abs() +
            ((prev.bitDepth ?? 0) - quality.bitDepth).abs();
        final currDiff = ((curr.sampleRate ?? 0) - quality.sampleRate).abs() +
            ((curr.bitDepth ?? 0) - quality.bitDepth).abs();
        return currDiff < prevDiff ? curr : prev;
      } else {
        final prevDiff = ((prev.bitrate ?? 0) -
                (quality as SonolythAudioLossyContainerQuality).bitrate)
            .abs();
        final currDiff = ((curr.bitrate ?? 0) - quality.bitrate).abs();
        return currDiff < prevDiff ? curr : prev;
      }
    });
  }

  String? getUrlOfQuality(
    SonolythAudioSourceContainerPreset preset,
    int qualityIndex,
  ) {
    return getStreamOfQuality(preset, qualityIndex)?.url;
  }

  SonolythAudioSourceContainerPreset? get qualityPreset {
    final presetState = ref.read(audioSourcePresetsProvider);
    return presetState.presets
        .elementAtOrNull(presetState.selectedStreamingContainerIndex);
  }

  /// The stream actually selected for playback (same preset/quality the [url]
  /// getter resolves), or null when no preset is available.
  SonolythAudioSourceStreamObject? get _selectedStream {
    final preferences = ref.read(audioSourcePresetsProvider);
    final presets = preferences.presets;
    if (presets.isEmpty) return null;
    return getStreamOfQuality(
      presets[preferences.selectedStreamingContainerIndex],
      preferences.selectedStreamingQualityIndex,
    );
  }

  /// File extension of the stream actually being played — derived from the real
  /// stream container (e.g. "flac" for a Qobuz lossless stream) rather than the
  /// active preset, so the music cache doesn't store a FLAC under the YouTube
  /// preset's container. Falls back to the preset when no stream is selected.
  String get playbackFileExtension {
    final container = _selectedStream?.container;
    if (container != null) {
      return switch (container) {
        "mp4" => "m4a",
        "webm" => "weba",
        _ => container,
      };
    }
    return qualityPreset?.getFileExtension() ?? "mp4";
  }

  /// Container label for the selected playback stream, used as the cache file's
  /// `audio/<container>` content-type.
  String get playbackContainer =>
      _selectedStream?.container ?? qualityPreset?.name ?? "mp4";
}
