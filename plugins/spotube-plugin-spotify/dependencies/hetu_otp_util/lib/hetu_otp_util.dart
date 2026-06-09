import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hetu_script/hetu/hetu.dart';
import 'package:path/path.dart';

abstract class HetuOtpUtilLoader {
  static Future<void> loadBytecodePureDart(
    Hetu hetu,
    String packagePath,
  ) async {
    final byteCodeFile = File(
      join(packagePath, 'lib/assets/bytecode/otp_util.out'),
    );
    final byteCode = await byteCodeFile.readAsBytes();

    hetu.loadBytecode(bytes: byteCode, moduleName: 'otp_util');
  }

  /// Loads the bytecode for the OTP utility from the Flutter asset bundle.
  /// Add following to your `pubspec.yaml`:
  /// 
  /// ```yaml
  /// flutter:
  ///   assets:
  ///     - packages/hetu_otp_util/assets/bytecode/otp_util.out
  /// ```
  static Future<void> loadBytecodeFlutter(Hetu hetu) async {
    final byteCodeFile = await rootBundle.load(
      'packages/hetu_otp_util/assets/bytecode/otp_util.out',
    );
    final byteCode = byteCodeFile.buffer.asUint8List();

    hetu.loadBytecode(bytes: byteCode, moduleName: 'otp_util');
  }
}
