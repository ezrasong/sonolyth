part of '../database.dart';

class ColorConverter extends TypeConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromSql(int fromDb) {
    return Color(fromDb);
  }

  @override
  int toSql(Color value) {
    return value.toARGB32();
  }
}

class SonolythColorConverter extends TypeConverter<SonolythColor, String> {
  const SonolythColorConverter();

  @override
  SonolythColor fromSql(String fromDb) {
    return SonolythColor.fromString(fromDb);
  }

  @override
  String toSql(SonolythColor value) {
    return value.toString();
  }
}
