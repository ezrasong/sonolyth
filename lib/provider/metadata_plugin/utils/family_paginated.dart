import 'dart:async';
import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/models/metadata/metadata.dart';
import 'package:sonolyth/provider/metadata_plugin/utils/common.dart';
import 'package:sonolyth/services/logger/logger.dart';

abstract class FamilyPaginatedAsyncNotifier<K, A>
    extends FamilyAsyncNotifier<SonolythPaginationResponseObject<K>, A>
    with MetadataPluginMixin<K> {
  Future<SonolythPaginationResponseObject<K>> fetch(int offset, int limit);

  Future<void> fetchMore() async {
    if (state.value == null || !state.value!.hasMore) return;

    final oldState = state.value;

    try {
      state = AsyncLoadingNext(state.asData!.value);

      final newState = await fetch(
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
    // (~200) for large playlists/libraries yet still serves more rows when
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

abstract class AutoDisposeFamilyPaginatedAsyncNotifier<K, A>
    extends AutoDisposeFamilyAsyncNotifier<SonolythPaginationResponseObject<K>,
        A> with MetadataPluginMixin<K> {
  Future<SonolythPaginationResponseObject<K>> fetch(int offset, int limit);

  Future<void> fetchMore() async {
    if (state.value == null || !state.value!.hasMore) return;
    final oldState = state.value;

    try {
      state = AsyncLoadingNext(state.value!);

      final newState = await fetch(
        state.value!.nextOffset!,
        state.value!.limit,
      );

      state = AsyncData(
        newState.copyWith(items: [
          ...state.value!.items.cast<K>(),
          ...newState.items.cast<K>(),
        ]),
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      state = AsyncData(oldState!);
    }
  }

  Future<List<K>> fetchAll() async {
    if (state.value == null) return [];
    if (!state.value!.hasMore) return state.value!.items.cast<K>();

    // Dedup across pages by value and stop as soon as a page adds nothing new:
    // a stalled server cursor or a query that caps its window (the large-
    // playlist "~200" symptom) otherwise either loops or silently truncates.
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
