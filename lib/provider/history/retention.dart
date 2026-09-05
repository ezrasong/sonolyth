import 'package:drift/drift.dart';
import 'package:sonolyth/models/database/database.dart';

/// How long a play stays in `history_table` (CONTEXT item 40).
///
/// **Why two years, and not a number picked to feel safe.** The Stats page
/// filters by `HistoryDuration`, and the longest *bounded* window it offers is
/// "Last 2 years". Keeping exactly that much means every named range the UI
/// can ask for is always complete — this week, this month, six months, this
/// year, two years — and the only figure this policy can shorten is
/// "All time", which in a listening app has always meant "as far back as we
/// kept". That is the trade the item was blocked on, and it is the smallest
/// one available: any shorter limit starts lying to a range the user can
/// actually select.
const historyRetention = Duration(days: 365 * 2);

/// A ceiling on rows, independent of age.
///
/// This is a runaway guard, not the policy. A row is written only after a real
/// listen — `subscribeToScrobbleChanged` waits for `min(duration / 2, 4min)`
/// — so ordinary use is nowhere near it: measured on the live database a row's
/// JSON averages **922 bytes** (63 rows, max 1724), and twenty plays a day for
/// the full two years is ~14,600 rows, about 14 MB. [historyMaxRows] is
/// reached only by 27 plays a day sustained for two years, or by the
/// pathological case the age limit cannot see — a 30-second track on repeat
/// writes a row every 30 seconds, 2,880 a day, and two years of that is two
/// million rows.
///
/// Rows are trimmed by `id`, not by `created_at`. The column is
/// `autoIncrement`, so id order *is* insertion order whatever the device clock
/// has been doing; the age limit has to read the clock because age is what it
/// means, but a count does not.
const historyMaxRows = 20000;

/// Enforces [historyRetention] and [historyMaxRows], returning how many rows
/// were removed.
///
/// Nothing calls this on a write path. It is launch-time housekeeping: the
/// table is append-only and grows by a handful of rows an hour at the very
/// most, so there is no state a frame could be waiting on.
///
/// [now] is injectable so the age limit can be tested without waiting two
/// years.
Future<int> pruneHistory(AppDatabase db, {DateTime? now}) async {
  final cutoff = (now ?? DateTime.now()).subtract(historyRetention);
  var removed = await (db.delete(db.historyTable)
        ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
      .go();

  final countExp = db.historyTable.id.count();
  final total = await (db.selectOnly(db.historyTable)..addColumns([countExp]))
      .map((row) => row.read(countExp) ?? 0)
      .getSingle();
  final excess = total - historyMaxRows;
  if (excess <= 0) return removed;

  // The id of the last row that has to go, found by offsetting into the table
  // rather than by listing every doomed id: `WHERE id IN (…)` with a hundred
  // thousand parameters is a different kind of unbounded.
  final boundary = await (db.select(db.historyTable)
        ..orderBy([(t) => OrderingTerm.asc(t.id)])
        ..limit(1, offset: excess - 1))
      .getSingleOrNull();
  if (boundary == null) return removed;

  removed += await (db.delete(db.historyTable)
        ..where((t) => t.id.isSmallerOrEqualValue(boundary.id)))
      .go();
  return removed;
}
