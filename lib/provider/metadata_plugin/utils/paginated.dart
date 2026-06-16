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

    // Paginate until the provider stops returning NEW items, instead of
    // trusting hasMore/total. Spotify's pathfinder reports a capped totalCount
    // (~200) for large libraries/playlists yet still serves more rows when
    // asked, so a hasMore-driven loop truncated big collections at ~200. Dedup
    // by value so a stalled cursor (server re-serving a page) ends the loop
    // rather than spinning. The 1000-page cap is a hard runaway backstop.
    final all = <K>[...state.value!.items.cast<K>()];
    final seen = <K>{...all};
    final pageSize = max(state.value!.limit, 100);
    var offset = all.length;
    var pages = 0;

    while (pages++ < 1000) {
      try {
        final newState = await fetch(offset, pageSize)
            .catchError((e) => fetch(offset, 50))
            .catchError((e) async {
          await Future.delayed(const Duration(milliseconds: 500));
          return fetch(offset, pageSize);
        });

        final items = newState.items.cast<K>();
        if (items.isEmpty) break;

        final fresh = [
          for (final item in items)
            if (seen.add(item)) item,
        ];
        if (fresh.isEmpty) break;

        all.addAll(fresh);
        offset += items.length;
        state = AsyncData(newState.copyWith(items: List<K>.from(all)));
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
        break;
      }
    }

    return all;
  }
}

abstract class PaginatedAsyncNotifier<K>
    extends AsyncNotifier<SonolythPaginationResponseObject<K>>
    with PaginatedAsyncNotifierMixin<K>, MetadataPluginMixin<K> {}

abstract class AutoDisposePaginatedAsyncNotifier<K>
    extends AutoDisposeAsyncNotifier<SonolythPaginationResponseObject<K>>
    with PaginatedAsyncNotifierMixin<K>, MetadataPluginMixin<K> {}
