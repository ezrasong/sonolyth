part of '../database.dart';

enum HistoryEntryType {
  playlist,
  album,
  track,
}

class HistoryTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get type => textEnum<HistoryEntryType>()();
  TextColumn get itemId => text()();
  TextColumn get data =>
      text().map(const MapTypeConverter<String, dynamic>())();
}

extension HistoryItemParseExtension on HistoryTableData {
  SonolythSimplePlaylistObject? get playlist =>
      type == HistoryEntryType.playlist && !data.containsKey("external_urls")
          ? SonolythSimplePlaylistObject.fromJson(data)
          : null;
  SonolythSimpleAlbumObject? get album =>
      type == HistoryEntryType.album && !data.containsKey("external_urls")
          ? SonolythSimpleAlbumObject.fromJson(data)
          : null;
  SonolythTrackObject? get track =>
      type == HistoryEntryType.track && !data.containsKey("external_urls")
          ? SonolythTrackObject.fromJson(data)
          : null;
}
