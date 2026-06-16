import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
// ignore: implementation_imports
import 'package:riverpod/src/async_notifier.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/logger/logger.dart';

mixin PaginatedAsyncNotifierMixin<K>
    // ignore: invalid_use_of_internal_member
    on AsyncNotifierBase<SonolythPaginationResponseObject<K>> {
  Future<SonolythPaginationResponseObject<K>> fetch(int offset, int limit);

  /// Wraps [fetch] with retry + backoff for HTTP 429 (rate limit) responses.
  /// The metadata provider (e.g. Spotify) returns 429 when the app issues a
  /// burst of requests on load, which otherwise surfaces as a hard error in a
  /// tab or silently halts pagination. Honors a `Retry-After` header when
  /// present, else exponential backoff (1s, 2s, 4s). Non-429 errors rethrow
  /// immediately so genuine failures aren't masked.
  Future<SonolythPaginationResponseObject<K>> fetchWithRetry(
    int offset,
    int limit, {
    int maxAttempts = 4,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await fetch(offset, limit);
      } catch (e) {
        if (attempt >= maxAttempts - 1 || !_isRateLimited(e)) rethrow;
        await Future<void>.delayed(
          _retryAfter(e) ?? Duration(seconds: 1 << attempt),
        );
      }
    }
  }

  bool _isRateLimited(Object error) {
    if (error is DioException && error.response?.statusCode == 429) return true;
    return error.toString().contains('429');
  }

  Duration? _retryAfter(Object error) {
    if (error is! DioException) return null;
    final header = error.response?.headers.value('retry-after');
    final seconds = header == null ? null : int.tryParse(header.trim());
    if (seconds == null) return null;
    return Duration(seconds: seconds.clamp(1, 30));
  }

  Future<void> fetchMore() async {
    if (state.value == null || !state.value!.hasMore) return;

    final oldState = state.value;
    try {
      state = AsyncLoadingNext(state.asData!.value);

      final newState = await fetchWithRetry(
        state.value!.nextOffset!,
        state.value!.limit,
      );

      final oldItems =
          state.value!.items.isEmpty ? <K>[] : state.value!.items.cast<K>();
      final items = newState.items.isEmpty ? <K>[] : newState.items.cast<K>();

      state = AsyncData(newState.copyWith(items: <K>[...oldItems, ...items]));
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      state = AsyncData(oldState!);
    }
  }

  Future<List<K>> fetchAll() async {
    if (state.value == null) return [];
    if (!state.value!.hasMore) return state.value!.items.cast<K>();

    // Dedup across pages and stop when a page adds nothing new, so a stalled
    // cursor or capped listing can't loop forever or silently truncate.
    final seen = <K>{...state.value!.items.cast<K>()};

    bool hasMore = true;
    var pages = 0;
    while (hasMore && pages++ < 1000) {
      final offset = state.value!.nextOffset!;
      final newState = await fetch(offset, max(state.value!.limit, 100))
          .catchError((e) => fetch(offset, max(state.value!.limit, 50)))
          .catchError((e) => fetch(offset, state.value!.limit))
          .catchError((e) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return fetch(offset, state.value!.limit);
      });

      final fresh = [
        for (final item in newState.items.cast<K>())
          if (seen.add(item)) item,
      ];

      if (fresh.isEmpty) {
        if (newState.total > seen.length) {
          AppLogger.diag(
            "fetchAll stopped early at ${seen.length}/${newState.total} "
            "(offset $offset returned no new items)",
          );
        }
        break;
      }

      hasMore = newState.hasMore;

      final oldItems =
          state.value!.items.isEmpty ? <K>[] : state.value!.items.cast<K>();

      state = AsyncData(
        newState.copyWith(items: [...oldItems, ...fresh]),
      );
    }

    return state.value!.items.cast<K>();
  }
}

abstract class PaginatedAsyncNotifier<K>
    extends AsyncNotifier<SonolythPaginationResponseObject<K>>
    with PaginatedAsyncNotifierMixin<K>, MetadataPluginMixin<K> {}

abstract class AutoDisposePaginatedAsyncNotifier<K>
    extends AutoDisposeAsyncNotifier<SonolythPaginationResponseObject<K>>
    with PaginatedAsyncNotifierMixin<K>, MetadataPluginMixin<K> {}
