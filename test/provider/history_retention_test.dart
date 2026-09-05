import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sonolyth/models/database/database.dart';
import 'package:sonolyth/provider/history/retention.dart';
import 'package:test/test.dart';

/// `history_table` was the last unbounded thing in the app after §26 capped the
/// log file: a row per played track and per collection opened, each holding the
/// item's full JSON, and nothing ever removed one (CONTEXT item 40).
///
/// The policy is two years — the longest window the Stats page can *ask* for —
/// with a row cap behind it as a runaway guard. What these pin is the pair of
/// properties the choice rests on: **nothing inside the window is ever
/// touched**, because every named range in the UI is computed over this table
/// and a prune that ate into "this year" would silently change a figure the
/// user is reading; and **the cap trims the oldest**, because the recent end is
/// the half every screen actually shows.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// `created_at` is written explicitly here — the column's default is
  /// `currentDateAndTime`, which is exactly what a retention test cannot use.
  Future<void> seed(List<DateTime> timestamps) async {
    await db.batch((batch) {
      batch.insertAll(db.historyTable, [
        for (final (i, createdAt) in timestamps.indexed)
          HistoryTableCompanion.insert(
            type: HistoryEntryType.track,
            itemId: 'track-$i',
            data: {'durationMs': 210000},
            createdAt: Value(createdAt),
          ),
      ]);
    });
  }

  Future<int> rows() async => (await db.select(db.historyTable).get()).length;

  Future<List<String>> ids() async =>
      (await (db.select(db.historyTable)
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get())
          .map((r) => r.itemId)
          .toList();

  final now = DateTime.utc(2026, 9, 5);

  group('age', () {
    test('an empty table prunes nothing and reports nothing', () async {
      expect(await pruneHistory(db, now: now), 0);
    });

    test('keeps everything inside the two-year window', () async {
      // The oldest of these is one day inside the limit. Nothing in the UI's
      // longest range may be removed by housekeeping the user never asked for.
      await seed([
        now.subtract(const Duration(days: 1)),
        now.subtract(const Duration(days: 364)),
        now.subtract(historyRetention - const Duration(days: 1)),
      ]);

      expect(await pruneHistory(db, now: now), 0);
      expect(await rows(), 3);
    });

    test('removes what has fallen out of it', () async {
      await seed([
        now.subtract(historyRetention + const Duration(days: 1)),
        now.subtract(const Duration(days: 5000)),
        now.subtract(const Duration(days: 10)),
      ]);

      expect(await pruneHistory(db, now: now), 2);
      expect(await ids(), ['track-2']);
    });

    test('a row exactly at the cutoff stays', () async {
      // The boundary belongs to the window: "the last two years" including the
      // moment two years ago, not excluding it.
      await seed([now.subtract(historyRetention)]);

      expect(await pruneHistory(db, now: now), 0);
      expect(await rows(), 1);
    });
  });

  group('row cap', () {
    /// Small enough to run in a test, large enough to have an "oldest".
    const over = 12;

    test('trims the oldest rows down to the cap', () async {
      // Standing in for the pathological case the age limit cannot see: a
      // 30-second track on repeat writes a row every 30 seconds, and two years
      // of that is two million rows, every one of them inside the window.
      await seed([
        for (var i = 0; i < historyMaxRows + over; i++)
          now.subtract(Duration(minutes: historyMaxRows + over - i)),
      ]);

      expect(await pruneHistory(db, now: now), over);
      expect(await rows(), historyMaxRows);
    });

    test('what survives is the recent end', () async {
      await seed([
        for (var i = 0; i < historyMaxRows + over; i++)
          now.subtract(Duration(minutes: historyMaxRows + over - i)),
      ]);
      await pruneHistory(db, now: now);

      final surviving = await ids();
      expect(surviving.first, 'track-$over');
      expect(surviving.last, 'track-${historyMaxRows + over - 1}');
    });

    test('a table exactly at the cap is left alone', () async {
      await seed([
        for (var i = 0; i < historyMaxRows; i++)
          now.subtract(Duration(minutes: historyMaxRows - i)),
      ]);

      expect(await pruneHistory(db, now: now), 0);
      expect(await rows(), historyMaxRows);
    });
  });
}
