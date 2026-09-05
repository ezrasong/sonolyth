import 'dart:async';
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
import 'package:sonolyth/services/dio/dio.dart';
import 'package:sonolyth/services/logger/logger.dart';

import 'package:sonolyth/services/sourced_track/exceptions.dart';
import 'package:sonolyth/services/sourced_track/qobuz_audio_source.dart';
import 'package:sonolyth/services/sourced_track/tidal_audio_source.dart';
import 'package:sonolyth/services/sourced_track/tidal_dash.dart';
import 'package:sonolyth/services/spotiflac/zarz_client.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

class SourcedTrack extends BasicSourcedTrack {
  /// How many candidates a single playback resolve will try per lossless
  /// source before moving on. ISRC matches are the same recording across
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

  /// Cache key for resolved lossless matches. Playback no longer goes through
  /// a plugin audio source, so the cache is keyed by a stable constant instead
  /// of the (now absent) plugin slug.
  static const losslessSourceSlug = "lossless";

  static Future<SourcedTrack> fetchFromTrack({
    required SonolythFullTrackObject query,
    required Ref ref,
    // Set on the single self-retry after purging a dead cached match, so a
    // match that keeps resolving empty (or a concurrent re-insert of a dead
    // row) can't drive unbounded recursion.
    bool retriedAfterPurge = false,
  }) async {
    const slug = losslessSourceSlug;
    final sw = Stopwatch()..start();
    final database = ref.read(databaseProvider);
    final cachedSource = await (database.select(database.sourceMatchTable)
          ..where((s) => s.trackId.equals(query.id) & s.sourceType.equals(slug))
          ..limit(1)
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .get()
        .then((s) => s.firstOrNull);

    if (cachedSource == null) {
      AppLogger.diag("[resolve] '${query.name}' cold (lossless-only)");

      // Qobuz then Tidal, both ISRC-exact. YouTube has been removed entirely:
      // there is no lossy fallback, so a track either resolves to lossless
      // FLAC or fails loudly with TrackNotFoundError.
      //
      // Both searches start up front so a Qobuz miss doesn't pay Tidal's
      // search round trip on top of its own — the expensive signed stream
      // calls (ticket + dl) stay sequential and Qobuz-first, so an early
      // Qobuz win only wastes one cheap tidal.com search. The pre-read no-op
      // error handler keeps an early return from leaving an unhandled async
      // error behind; _tryLosslessSource sees the original failure when it
      // awaits the future itself.
      final qobuz = QobuzAudioSource();
      final tidal = TidalAudioSource();
      final tidalMatches = tidal.matches(query);
      unawaited(tidalMatches.then((_) {}, onError: (_, __) {}));

      final qobuzResult = await _tryLosslessSource(
        label: "qobuz",
        match: () => qobuz.matches(query),
        stream: qobuz.streams,
        query: query,
        ref: ref,
        slug: slug,
        sw: sw,
      );
      if (qobuzResult.sourced != null) return qobuzResult.sourced!;

      final tidalResult = await _tryLosslessSource(
        label: "tidal",
        match: () => tidalMatches,
        stream: tidal.streams,
        query: query,
        ref: ref,
        slug: slug,
        sw: sw,
      );
      if (tidalResult.sourced != null) return tidalResult.sourced!;

      // Distinguish "neither catalog has it" from "we were never allowed to
      // ask". With no lossy fallback left, reporting an unverified session as
      // TrackNotFound would send the user hunting for a catalogue problem
      // that doesn't exist.
      //
      // ⚠️ This is `||`, not `&&`, and the difference is not cosmetic. A track
      // only ONE catalog carries — extremely common; K-pop b-sides are on
      // Tidal and not Qobuz all the time — produces `matches=0` on the other
      // side, which sets `needsVerification: false` there simply because it
      // never got as far as a stream call. Requiring both to be true meant
      // every single-catalog track was reported as "NO lossless source" while
      // the real cause was an unverified session, and the user was told the
      // catalog didn't have a track it plainly did. If ANY candidate was
      // blocked purely by verification, "not found" is not a conclusion this
      // code is entitled to draw.
      if (qobuzResult.needsVerification || tidalResult.needsVerification) {
        AppLogger.diag(
          "[resolve] '${query.name}' blocked: lossless access not verified",
        );
        throw const ZarzVerificationRequiredException();
      }

      AppLogger.diag(
        "[resolve] '${query.name}' NO lossless source "
        "(total ${sw.elapsedMilliseconds}ms)",
      );
      throw TrackNotFoundError(query);
    }

    final item = SonolythAudioSourceMatchObject.fromJson(
      jsonDecode(cachedSource.sourceInfo),
    );
    final cachedIsQobuz = QobuzAudioSource.ownsMatch(item);
    AppLogger.diag(
      "[resolve] '${query.name}' cached "
      "(${cachedIsQobuz ? "qobuz" : "tidal"} id=${item.id})",
    );

    List<SonolythAudioSourceStreamObject> manifest;
    try {
      manifest = await _resolveStreams(item);
    } on ZarzRateLimitedException {
      // The gateway is rate-limiting. Don't purge the (good) cached match —
      // it resumes once the limit clears. With no lossy fallback left, the
      // only honest outcome is to surface the failure.
      AppLogger.diag(
        "[resolve] '${query.name}' cached 429 rate-limited "
        "(+${sw.elapsedMilliseconds}ms)",
      );
      rethrow;
    } catch (e) {
      AppLogger.diag("[resolve] '${query.name}' cached resolve ERROR: $e");
      if (e is ZarzVerificationRequiredException) rethrow;
      manifest = const [];
    }
    if (manifest.isEmpty) {
      // The cached match no longer streams (taken down, or a URL that won't
      // resolve). Purge it and resolve fresh; otherwise the track stays
      // permanently unplayable — the cached path has no siblings to fall
      // back to.
      AppLogger.diag(
        "[resolve] '${query.name}' cached match dead, purge + re-resolve"
        "${retriedAfterPurge ? " (already retried -> give up)" : ""}",
      );
      await (database.delete(database.sourceMatchTable)
            ..where(
                (s) => s.trackId.equals(query.id) & s.sourceType.equals(slug)))
          .go();
      // Already purged + retried once this call: don't recurse again (guards
      // against a match that perpetually resolves empty).
      if (retriedAfterPurge) throw TrackNotFoundError(query);
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
      source: slug,
    );

    AppLogger.diag(
      "[resolve] '${query.name}' -> cached ${cachedIsQobuz ? "qobuz" : "tidal"} ok "
      "(total ${sw.elapsedMilliseconds}ms)",
    );

    return sourcedTrack;
  }

  /// Alternate lossless matches for [query], used by the "swap source" UI.
  /// Both lossless catalogs are searched; YouTube siblings no longer exist.
  static Future<List<SonolythAudioSourceMatchObject>> fetchSiblings({
    required SonolythFullTrackObject query,
    required Ref ref,
  }) async {
    final results = <SonolythAudioSourceMatchObject>[];

    try {
      results.addAll((await QobuzAudioSource().matches(query)).accepted);
    } catch (_) {
      // Qobuz lookup failed (rate limit/network) — Tidal may still have it.
    }

    try {
      results.addAll((await TidalAudioSource().matches(query)).accepted);
    } catch (_) {
      // Both catalogs failing just means no siblings to offer.
    }

    return results.toSet().toList();
  }

  static Future<void> _cacheMatch(
    Ref ref,
    String trackId,
    String slug,
    SonolythAudioSourceMatchObject match,
  ) async {
    final database = ref.read(databaseProvider);
    // A single upsert against `uniq_track_match` (schema 13). This used to be
    // a delete-then-insert inside a transaction, which only *narrowed* the
    // window in which two concurrent cold resolves for the same
    // (track, source) could leave two rows; the unique index closes it.
    await database.into(database.sourceMatchTable).insert(
          SourceMatchTableCompanion.insert(
            trackId: trackId,
            sourceInfo: Value(jsonEncode(match)),
            sourceType: slug,
          ),
          onConflict: DoUpdate(
            (_) => SourceMatchTableCompanion(
              sourceInfo: Value(jsonEncode(match)),
              createdAt: Value(DateTime.now()),
            ),
            target: [
              database.sourceMatchTable.trackId,
              database.sourceMatchTable.sourceType,
            ],
          ),
        );
  }

  /// Resolves [query] against one lossless source (Qobuz or Tidal) on the hot
  /// path, WITHOUT touching the YouTube plugin. Returns the SourcedTrack (and
  /// caches the match) on success, or `transient: true` when the source was
  /// rate-limited/errored or carried the track but couldn't stream it right
  /// now — so the caller tries the next source and avoids caching a YouTube
  /// fallback for what's only a temporary miss. A clean empty result is
  /// `transient: false` (the source genuinely doesn't carry the track).
  static Future<
          ({SourcedTrack? sourced, bool transient, bool needsVerification})>
      _tryLosslessSource({
    required String label,
    required Future<
                ({
                  List<SonolythAudioSourceMatchObject> accepted,
                  bool sawResults
                })>
            Function()
        match,
    required Future<List<SonolythAudioSourceStreamObject>> Function(
            SonolythAudioSourceMatchObject)
        stream,
    required SonolythFullTrackObject query,
    required Ref ref,
    required String slug,
    required Stopwatch sw,
  }) async {
    var candidates = const <SonolythAudioSourceMatchObject>[];
    var sawResults = false;
    var rateLimited = false;
    var matchError = false;
    var needsVerification = false;
    try {
      final result = await match();
      candidates = result.accepted;
      sawResults = result.sawResults;
      AppLogger.diag(
        "[resolve] '${query.name}' $label matches=${candidates.length} "
        "(raw=${sawResults ? "some" : "none"}, +${sw.elapsedMilliseconds}ms)",
      );
    } on ZarzRateLimitedException {
      rateLimited = true;
      AppLogger.diag("[resolve] '${query.name}' $label match 429 rate-limited");
    } on ZarzVerificationRequiredException {
      needsVerification = true;
      AppLogger.diag("[resolve] '${query.name}' $label match needs verify");
    } catch (e) {
      matchError = true;
      AppLogger.diag("[resolve] '${query.name}' $label match ERROR: $e");
    }

    SonolythAudioSourceMatchObject? chosen;
    var manifest = const <SonolythAudioSourceStreamObject>[];
    for (final candidate in candidates.take(_maxQobuzPlaybackAttempts)) {
      try {
        final streams = await stream(candidate);
        if (streams.isNotEmpty) {
          chosen = candidate;
          manifest = streams;
          break;
        }
      } on ZarzRateLimitedException {
        rateLimited = true;
        AppLogger.diag("[resolve] '${query.name}' $label 429 rate-limited");
        break;
      } on ZarzVerificationRequiredException {
        needsVerification = true;
        AppLogger.diag("[resolve] '${query.name}' $label stream needs verify");
        break;
      } catch (e) {
        AppLogger.diag(
          "[resolve] '${query.name}' $label stream ERROR id=${candidate.id}: $e",
        );
      }
    }

    if (chosen != null) {
      // Cache only after the stream resolves — caching first would poison the
      // table with a match that can't actually stream.
      await _cacheMatch(ref, query.id, slug, chosen);
      AppLogger.diag(
        "[resolve] '${query.name}' -> $label flac (total ${sw.elapsedMilliseconds}ms)",
      );
      return (
        sourced: SourcedTrack(
          ref: ref,
          siblings: const [],
          info: chosen,
          source: slug,
          sources: manifest,
          query: query,
        ),
        transient: false,
        needsVerification: false,
      );
    }

    // `sawResults` counts as transient: the search returned candidates that
    // all failed scoring, which is a matching miss (romanized credits, junk
    // ISRC results), NOT proof the catalog lacks the track. Caching a YouTube
    // fallback for it would permanently pin what may be the wrong song.
    return (
      sourced: null,
      transient: rateLimited || matchError || sawResults,
      needsVerification: needsVerification,
    );
  }

  /// Routes stream resolution for [match] to the source that produced it: the
  /// native Qobuz/Tidal sources for their own matches, otherwise the active
  /// plugin audio source (YouTube).
  /// Routes stream resolution for [match] to the source that produced it.
  /// Only the native lossless sources exist now that YouTube is gone.
  static Future<List<SonolythAudioSourceStreamObject>> _resolveStreams(
    SonolythAudioSourceMatchObject match,
  ) async {
    if (QobuzAudioSource.ownsMatch(match)) {
      return QobuzAudioSource().streams(match);
    }
    if (TidalAudioSource.ownsMatch(match)) {
      return TidalAudioSource().streams(match);
    }
    // A row left over from a pre-lossless-only install (a YouTube match).
    // Treat it as dead so the caller purges and re-resolves against Qobuz or
    // Tidal instead of trying to stream a source that no longer exists.
    return const [];
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

    // a sibling source that was fetched from the search results
    final isStepSibling = siblings.none((s) => s.id == sibling.id);

    final newSourceInfo = isStepSibling
        ? sibling
        : siblings.firstWhere((s) => s.id == sibling.id);

    final newSiblings = siblings.where((s) => s.id != sibling.id).toList()
      ..insert(0, info);

    final manifest = await _resolveStreams(newSourceInfo);

    // A sibling that resolves to no playable streams (gateway blip, expired or
    // rate-limited source) must NOT overwrite the cached match — doing so would
    // pin an unplayable entry. Abort the swap and keep the current source.
    if (manifest.isEmpty) {
      return null;
    }

    final database = ref.read(databaseProvider);

    // One upsert against `uniq_track_match` — see `_cacheMatch`.
    await database.into(database.sourceMatchTable).insert(
          SourceMatchTableCompanion.insert(
            trackId: query.id,
            // Cache the source actually played (newSourceInfo), not the raw
            // argument — for a known sibling these can be distinct objects.
            sourceInfo: Value(jsonEncode(newSourceInfo)),
            sourceType: losslessSourceSlug,
            createdAt: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (_) => SourceMatchTableCompanion(
              sourceInfo: Value(jsonEncode(newSourceInfo)),
              createdAt: Value(DateTime.now()),
            ),
            target: [
              database.sourceMatchTable.trackId,
              database.sourceMatchTable.sourceType,
            ],
          ),
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
    final sibling = siblings.elementAtOrNull(index);
    if (sibling == null) return Future.value(null);
    return swapWithSibling(sibling);
  }

  Future<SourcedTrack> refreshStream() async {
    List<SonolythAudioSourceStreamObject> validStreams = [];

    final stringBuffer = StringBuffer();
    for (final source in sources) {
      // A TIDAL DASH source's url is the `x-tidal-dash:` marker, not a real HTTP
      // URL (HEAD-probing it throws "No host specified"). Skip it so the
      // empty -> re-resolve path below re-mints a fresh manifest instead.
      if (isDashUrl(source.url)) continue;
      final res = await globalDio.head(
        source.url,
        options: Options(
          // Bound the probe: a dead/hung URL must fail fast, not block the
          // (awaited) refresh for the full default timeout.
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
      // Re-mint the stream — this re-signs a fresh FLAC URL. With YouTube
      // gone there is no lossy fallback, so purge the cached match and
      // re-resolve from scratch (Qobuz then Tidal) rather than returning an
      // empty manifest, which would make `url` null and 500 the proxy stream.
      try {
        validStreams = await _resolveStreams(info);
      } catch (_) {
        validStreams = const [];
      }
      if (validStreams.isEmpty) {
        AppLogger.diag(
          "[resolve] '${query.name}' refresh failed "
          "(${QobuzAudioSource.ownsMatch(info) ? "qobuz" : "tidal"}) "
          "-> purge + re-resolve",
        );
        final database = ref.read(databaseProvider);
        await (database.delete(database.sourceMatchTable)
              ..where((s) =>
                  s.trackId.equals(query.id) &
                  s.sourceType.equals(losslessSourceSlug)))
            .go();
        return fetchFromTrack(query: query, ref: ref, retriedAfterPurge: true);
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

  /// The playback URL, or null when no preset/stream combination resolves.
  ///
  /// This used to index `presets[selectedStreamingContainerIndex]` directly.
  /// That is the single hottest path in playback — the local server calls it
  /// for every stream request — and it threw `RangeError` whenever the preset
  /// list was empty or the persisted index outlived the list it was chosen
  /// from. Both are reachable: see `kBuiltInLosslessPresets`. It shares
  /// [_selectedStream] now so there is exactly one bounds check to get right.
  String? get url => _selectedStream?.url;

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
    // `elementAtOrNull`, not `[]`: a persisted container index can outlive the
    // preset list it was chosen from (an install that used to have the
    // YouTube plugin's several presets and now has one built-in FLAC entry).
    final preset = preferences.presets
        .elementAtOrNull(preferences.selectedStreamingContainerIndex);
    if (preset == null || preset.qualities.isEmpty) return null;
    final qualityIndex = preferences.selectedStreamingQualityIndex
        .clamp(0, preset.qualities.length - 1);
    return getStreamOfQuality(preset, qualityIndex);
  }

  /// The stream [url] resolves to, for callers outside this class that only
  /// want to *describe* it — the track rows' format line reads its container
  /// and bit depth through the format registry.
  SonolythAudioSourceStreamObject? get selectedStream => _selectedStream;

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

  /// Human label for the stream ACTUALLY being played (e.g. "flac • 16bit •
  /// 44.1kHz" for a Qobuz/Tidal lossless stream, "mp4 • 256kbps" for a YouTube
  /// fallback) — derived from the resolved stream, not the configured preset, so
  /// the player shows the real source quality. Null when no stream is selected.
  String? get qualityLabel {
    final stream = _selectedStream;
    if (stream == null) return null;
    final container = stream.container;
    if (stream.type == SonolythMediaCompressionType.lossless) {
      if (stream.bitDepth != null && stream.sampleRate != null) {
        return "$container • ${stream.bitDepth}bit • "
            "${oneOptionalDecimalFormatter.format(stream.sampleRate! / 1000)}kHz";
      }
      return "$container • lossless";
    }
    if (stream.bitrate != null) {
      return "$container • "
          "${oneOptionalDecimalFormatter.format(stream.bitrate! / 1000)}kbps";
    }
    return container;
  }
}
