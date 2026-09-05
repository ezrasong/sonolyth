part of '../database.dart';

/// Measured lead-in / lead-out silence for a local audio file, so playback can
/// start at the first sample of actual music and end at the last one.
///
/// Keyed by the absolute file path the measurement was taken from. That is the
/// only binding that is unambiguously correct: a row applies exactly when the
/// player is about to open that same file. Streamed tracks deliberately have
/// no rows — their media URI points at the in-app proxy, whose bytes depend on
/// which source the track currently resolves to, so a stored measurement
/// could not be proven to describe them.
class TrackTrimTable extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Absolute path of the scanned file.
  TextColumn get filePath => text().unique()();

  /// Size of the file when scanned; a changed size means different audio and
  /// invalidates the measurement.
  IntColumn get fileSize => integer()();

  /// Milliseconds of digital silence to skip at each edge. Either may be 0.
  IntColumn get leadMs => integer().withDefault(const Constant(0))();
  IntColumn get tailMs => integer().withDefault(const Constant(0))();

  /// Full decoded length of the scanned file, so the tail trim can be turned
  /// back into an absolute end position.
  IntColumn get durationMs => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
