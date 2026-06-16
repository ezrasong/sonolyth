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
    if (!state.value!.hasMore) return state.value!.items.cast<K>();

    // Dedup across pages by value: a server page cursor that stalls (re-serves
    // a page we've seen) or a query that caps its window would otherwise either
    // loop forever or silently inflate the count. We stop as soon as a page
    // contributes no new items.
    final seen = <K>{...state.value!.items.cast<K>()};

    bool hasMore = true;
    // Hard backstop so a misbehaving cursor can never spin indefinitely.
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
        // Cursor stalled or the provider capped the listing while still
        // reporting hasMore. Stop with what we have and record the shortfall
        // so it's visible on-device instead of looking like a clean finish.
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
