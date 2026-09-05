part of '../database.dart';

/// One cached match per `(trackId, sourceType)` — that is what every reader
/// assumes and what every writer already tried to maintain by hand.
///
/// The original `uniq_track_match` covered `(track_id, source_id, source_type)`
/// and was dropped at schema 10 along with the `source_id` column, leaving the
/// invariant enforced only by delete-then-insert inside a transaction. It is a
/// real index again from schema 13 (`from12To13` de-duplicates first), so the
/// writers can upsert instead.
@TableIndex(
  name: "uniq_track_match",
  unique: true,
  columns: {#trackId, #sourceType},
)
class SourceMatchTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  TextColumn get sourceInfo => text().withDefault(const Constant("{}"))();
  TextColumn get sourceType => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
