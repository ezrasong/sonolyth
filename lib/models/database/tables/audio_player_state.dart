part of '../database.dart';

class AudioPlayerStateTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get playing => boolean()();
  TextColumn get loopMode => textEnum<PlaylistMode>()();
  BoolColumn get shuffled => boolean()();
  TextColumn get collections => text().map(const StringListConverter())();
  TextColumn get tracks => text()
      .map(const SonolythTrackObjectListConverter())
      .withDefault(const Constant("[]"))();
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
}

class SonolythTrackObjectListConverter
    extends TypeConverter<List<SonolythTrackObject>, String> {
  const SonolythTrackObjectListConverter();

  @override
  List<SonolythTrackObject> fromSql(String fromDb) {
    final raw = (jsonDecode(fromDb) as List).cast<Map>();

    return raw
        .map((e) => SonolythTrackObject.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  String toSql(List<SonolythTrackObject> value) {
    return jsonEncode(
      value.map((e) => e.toJson()).toList(),
    );
  }
}
