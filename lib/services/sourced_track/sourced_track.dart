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
  /// How many Qobuz candidates a single playback resolve will try before
  /// falling back to YouTube. Qobuz ISRC matches are the same recording across
  /// releases, so grinding every one when the gateway is unhappy only stalls
  /// the loading spinner — cap it low and fail over fast.
  static const _maxQobuzPlaybackAttempts = 2;

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
    // Set on the single self-retry after purging a dead cached match, so a
    // match that keeps resolving empty (or a concurrent re-insert of a dead
    // row) can't drive unbounded recursion.
    bool retriedAfterPurge = false,
  }) async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSource == null || audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    final sw = Stopwatch()..start();
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
      final qobuzEnabled =
          await ref.read(qobuzPlaybackEnabledProvider.future);
      AppLogger.diag(
        "[resolve] '${query.name}' cold (qobuz=${qobuzEnabled ? "on" : "off"})",
      );

      // Qobuz (ISRC-exact, lossless) is the priority source. Resolve it on the
      // hot path FIRST and — crucially — WITHOUT touching the YouTube plugin
      // (Piped): a FLAC-served track must never pay a Piped search round trip,
      // and prefetching upcoming tracks must stay cheap so skips don't lag.
      // YouTube is fetched lazily only when Qobuz can't serve the track.
      if (qobuzEnabled) {
        final qobuz = QobuzAudioSource();

        var qobuzCandidates = const <SonolythAudioSourceMatchObject>[];
        try {
          qobuzCandidates = await qobuz.matches(query);
          AppLogger.diag(
            "[resolve] '${query.name}' qobuz matches=${qobuzCandidates.length} "
            "(+${sw.elapsedMilliseconds}ms)",
          );
        } catch (e) {
          AppLogger.diag("[resolve] '${query.name}' qobuz match ERROR: $e");
        }

        SonolythAudioSourceMatchObject? chosen;
        List<SonolythAudioSourceStreamObject> manifest = const [];
        var rateLimited = false;
        for (final candidate
            in qobuzCandidates.take(_maxQobuzPlaybackAttempts)) {
          final attemptAt = sw.elapsedMilliseconds;
          try {
            final streams = await qobuz.streams(candidate);
            if (streams.isNotEmpty) {
              chosen = candidate;
              manifest = streams;
              AppLogger.diag(
                "[resolve] '${query.name}' qobuz stream OK id=${candidate.id} "
                "(${sw.elapsedMilliseconds - attemptAt}ms)",
              );
              break;
            }
            AppLogger.diag(
              "[resolve] '${query.name}' qobuz stream empty id=${candidate.id} "
              "(${sw.elapsedMilliseconds - attemptAt}ms)",
            );
          } on ZarzRateLimitedException {
            rateLimited = true;
            AppLogger.diag("[resolve] '${query.name}' qobuz 429 rate-limited");
            break;
          } catch (e) {
            AppLogger.diag(
              "[resolve] '${query.name}' qobuz stream ERROR id=${candidate.id}: $e",
            );
          }
        }

        if (chosen != null) {
          // Cache the match only after the stream resolves — caching first
          // would poison the table with a match that can't actually stream.
          // Siblings (YouTube alternatives) are fetched lazily by the sibling
          // sheet, exactly like the cached path, so this stays Piped-free.
          await _cacheMatch(ref, query.id, audioSourceConfig.slug, chosen);

          AppLogger.diag(
            "[resolve] '${query.name}' -> QOBUZ flac (total ${sw.elapsedMilliseconds}ms)",
          );
          return SourcedTrack(
            ref: ref,
            siblings: const [],
            info: chosen,
            source: audioSourceConfig.slug,
            sources: manifest,
            query: query,
          );
        }

        // Qobuz is rate-limited, or carries the track (it returned candidates)
        // but couldn't stream it right now — a gateway 500/timeout/network
        // blip, not a real "Qobuz doesn't have it". Play via YouTube WITHOUT
        // caching so the track upgrades back to lossless on a later play,
        // rather than being permanently pinned to a (often wrong) YouTube
        // match.
        if (rateLimited || qobuzCandidates.isNotEmpty) {
          AppLogger.diag(
            "[resolve] '${query.name}' -> youtube (qobuz "
            "${rateLimited ? "rate-limited" : "carried but unplayable"}, "
            "NOT cached, +${sw.elapsedMilliseconds}ms)",
          );
          return _fetchViaPlugin(
            query: query,
            ref: ref,
            pluginAudioSource: audioSource.audioSource,
            slug: audioSourceConfig.slug,
          );
        }
        // Qobuz genuinely doesn't carry the track (no candidates) — fall
        // through to the cached YouTube path below.
        AppLogger.diag(
          "[resolve] '${query.name}' qobuz has no candidates -> youtube (cached)",
        );
      }

      // YouTube path: Qobuz disabled, or it genuinely doesn't carry this
      // track. Resolve the best YouTube sibling and cache it as a stable
      // fallback.
      final youtube = await _fetchViaPlugin(
        query: query,
        ref: ref,
        pluginAudioSource: audioSource.audioSource,
        slug: audioSourceConfig.slug,
        cache: true,
      );
      AppLogger.diag(
        "[resolve] '${query.name}' -> youtube cached (total ${sw.elapsedMilliseconds}ms)",
      );
      return youtube;
    }
    final item = SonolythAudioSourceMatchObject.fromJson(
      jsonDecode(cachedSource.sourceInfo),
    );
    final cachedIsQobuz = QobuzAudioSource.ownsMatch(item);
    AppLogger.diag(
      "[resolve] '${query.name}' cached (${cachedIsQobuz ? "qobuz" : "youtube"} id=${item.id})",
    );

    List<SonolythAudioSourceStreamObject> manifest;
    try {
      manifest = await _resolveStreams(audioSource.audioSource, item);
    } on ZarzRateLimitedException {
      // Qobuz's gateway is rate-limiting. Don't purge the (good) cached match —
      // it resumes once the limit clears. Play via the YouTube plugin right now
      // so the block is never felt, without rewriting the cache.
      AppLogger.diag(
        "[resolve] '${query.name}' cached qobuz 429 -> youtube live "
        "(+${sw.elapsedMilliseconds}ms)",
      );
      return _fetchViaPlugin(
        query: query,
        ref: ref,
        pluginAudioSource: audioSource.audioSource,
        slug: audioSourceConfig.slug,
      );
    } catch (e) {
      AppLogger.diag("[resolve] '${query.name}' cached resolve ERROR: $e");
      manifest = const [];
    }
    if (manifest.isEmpty) {
      // The cached match no longer streams (taken down, plugin change, or a
      // Qobuz URL that won't resolve). Purge it and resolve fresh; otherwise
      // the track stays permanently unplayable — the cached path has no
      // siblings to fall back to.
      AppLogger.diag(
        "[resolve] '${query.name}' cached match dead, purge + re-resolve"
        "${retriedAfterPurge ? " (already retried -> youtube)" : ""}",
      );
      await (database.delete(database.sourceMatchTable)
            ..where((s) =>
                s.trackId.equals(query.id) &
                s.sourceType.equals(audioSourceConfig.slug)))
          .go();
      // Already purged + retried once this call: don't recurse again (guards
      // against a match that perpetually resolves empty). Resolve via YouTube.
      if (retriedAfterPurge) {
        return _fetchViaPlugin(
          query: query,
          ref: ref,
          pluginAudioSource: audioSource.audioSource,
          slug: audioSourceConfig.slug,
          cache: true,
        );
      }
      return fetchFromTrack(
        query: query,
        ref: ref,
        retriedAfterPurge: true,
      );
    }

    final sourcedTrack = SourcedTrack(
      ref: ref,
      siblings: [],
      sources: manifest,
      info: item,
      query: query,
      source: audioSourceConfig.slug,
    );

    AppLogger.diag(
      "[resolve] '${query.name}' -> cached ${cachedIsQobuz ? "qobuz" : "youtube"} ok "
      "(total ${sw.elapsedMilliseconds}ms)",
    );

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

    // Resolve the Qobuz ISRC-exact matches first (best-effort) when the source
    // is enabled. Doing Qobuz first means a YouTube matching hiccup can't sink
    // a lossless Qobuz play.
    var qobuzMatches = const <SonolythAudioSourceMatchObject>[];
    if (await ref.read(qobuzPlaybackEnabledProvider.future)) {
      try {
        qobuzMatches = await QobuzAudioSource().matches(query);
      } catch (_) {
        // Qobuz lookup failed (rate limit/network) — fall back to the plugin.
      }
    }

    // YouTube/plugin siblings are the coverage fallback. When Qobuz already
    // has candidates this call is best-effort: a plugin `matches` failure
    // (e.g. a 400 from the YouTube source) must not block a Qobuz-served
    // track, so the error is only surfaced when there's no Qobuz match to
    // fall back on.
    var pluginSiblings = const <SonolythAudioSourceMatchObject>[];
    try {
      pluginSiblings = rankResults(
        await audioSource.audioSource.matches(query),
        query,
      );
    } catch (_) {
      if (qobuzMatches.isEmpty) rethrow;
    }

    if (qobuzMatches.isNotEmpty) {
      return <SonolythAudioSourceMatchObject>{
        ...qobuzMatches,
        ...pluginSiblings,
      }.toList();
    }

    return pluginSiblings.toSet().toList();
  }

  /// Persists [match] as the cached source for ([trackId], [slug]), replacing
  /// any existing rows first. `sourceMatchTable` has no unique constraint on
  /// (trackId, sourceType), so a plain insert would append; concurrent cold
  /// resolves (e.g. prefetch + the server reading a non-identical track key)
  /// or repeated purge/re-resolve cycles would then grow the table unboundedly.
  /// Replacing keeps it at one row per (track, source).
  static Future<void> _cacheMatch(
    Ref ref,
    String trackId,
    String slug,
    SonolythAudioSourceMatchObject match,
  ) async {
    final database = ref.read(databaseProvider);
    // One transaction so concurrent cold resolves for the same (track, source)
    // can't interleave their delete+insert into duplicate rows.
    await database.transaction(() async {
      await (database.delete(database.sourceMatchTable)
            ..where(
                (s) => s.trackId.equals(trackId) & s.sourceType.equals(slug)))
          .go();
      await database.into(database.sourceMatchTable).insert(
            SourceMatchTableCompanion.insert(
              trackId: trackId,
              sourceInfo: Value(jsonEncode(match)),
              sourceType: slug,
            ),
          );
    });
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

  /// Resolves [query] through the plugin (YouTube) source only.
  ///
  /// With [cache] false (the default) the source-match cache is left untouched
  /// — the live fallback when Qobuz is momentarily unavailable but DOES carry
  /// the track, so it upgrades back to lossless on a later play. With [cache]
  /// true the chosen match is persisted, used when Qobuz genuinely lacks the
  /// track (or is disabled) so it doesn't re-search every play.
  static Future<SourcedTrack> _fetchViaPlugin({
    required SonolythFullTrackObject query,
    required Ref ref,
    required MetadataPluginAudioSourceEndpoint pluginAudioSource,
    required String slug,
    List<SonolythAudioSourceMatchObject>? candidates,
    bool cache = false,
  }) async {
    // Reuse already-ranked siblings when the caller has them, so we don't
    // re-run a YouTube `matches` that may have just failed.
    final ranked = candidates ??
        rankResults(await pluginAudioSource.matches(query), query)
            .toSet()
            .toList();
    for (final candidate in ranked) {
      try {
        final streams = await pluginAudioSource.streams(candidate);
        if (streams.isNotEmpty) {
          if (cache) {
            await _cacheMatch(ref, query.id, slug, candidate);
          }
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

    // A sibling that resolves to no playable streams (gateway blip, expired or
    // rate-limited source) must NOT overwrite the cached match — doing so would
    // pin an unplayable entry. Abort the swap and keep the current source.
    if (manifest.isEmpty) {
      return null;
    }

    final database = ref.read(databaseProvider);

    // Delete-then-insert in a single transaction so a concurrent resolve for
    // the same (track, source) can't interleave and leave duplicate rows
    // (sourceMatchTable has no unique constraint — see _cacheMatch).
    await database.transaction(() async {
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
              // Cache the source actually played (newSourceInfo), not the raw
              // argument — for a known sibling these can be distinct objects.
              sourceInfo: Value(jsonEncode(newSourceInfo)),
              sourceType: audioSourceConfig.slug,
              createdAt: Value(DateTime.now()),
            ),
            mode: InsertMode.replace,
          );
    });

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
    final sibling = siblings.elementAtOrNull(index);
    if (sibling == null) return Future.value(null);
    return swapWithSibling(sibling);
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
        options: Options(
          // Bound the probe: a dead/hung URL must degrade to YouTube quickly,
          // not block the (awaited) refresh for the full default timeout.
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (status) => status != null && status < 500,
        ),
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
      // Re-mint the stream. For a Qobuz match this re-signs a fresh FLAC URL;
      // but if the gateway is down/rate-limited it can throw or yield nothing.
      // Degrade to the YouTube plugin in that case instead of returning an
      // empty manifest — an empty manifest makes `url` null and 500s the proxy
      // stream request (no siblings to fall back on for a Qobuz hit).
      try {
        validStreams = await _resolveStreams(audioSource.audioSource, info);
      } catch (_) {
        validStreams = const [];
      }
      if (validStreams.isEmpty) {
        AppLogger.diag(
          "[resolve] '${query.name}' refresh failed (${QobuzAudioSource.ownsMatch(info) ? "qobuz" : "plugin"}) -> youtube",
        );
        return _fetchViaPlugin(
          query: query,
          ref: ref,
          pluginAudioSource: audioSource.audioSource,
          slug: audioSourceConfig.slug,
        );
      }
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
