import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:spotube/utils/platform.dart';

class AndroidSystemAccent {
  static const _channel = MethodChannel('com.ezrasong.sonolyth/system_accent');

  static Future<Color?> getColor() async {
    if (!kIsAndroid) return null;

    final color = await _channel.invokeMethod<int?>('getAccentColor');
    if (color == null) return null;

    return Color(color);
  }
}
