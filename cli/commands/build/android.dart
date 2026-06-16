import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart';

import '../../core/env.dart';
import 'common.dart';

class AndroidBuildCommand extends Command with BuildCommandCommonSteps {
  @override
  String get description => "Build for android";

  @override
  String get name => "android";

  @override
  FutureOr? run() async {
    await bootstrap();

    // `--arch=arm64` builds a single-ABI APK (arm64-v8a) for fast dev cycles:
    // it skips the armeabi-v7a + x86_64 native compiles, which is most of the
    // Rust/NDK build time. The default ("all"/"x86") still ships the fat APK
    // that covers every device. arm64 is fine for modern phones (e.g. the
    // physical test device), just not for release distribution.
    final archFlag = architecture == "arm64"
        ? " --target-platform android-arm64"
        : "";

    await shell.run(
      "flutter build apk --flavor ${CliEnv.channel.name}$archFlag",
    );

    final ogApkFile = File(
      join(
        "build",
        "app",
        "outputs",
        "flutter-apk",
        "app-${CliEnv.channel.name}-release.apk",
      ),
    );

    await ogApkFile.copy(
      join(cwd.path, "build", "Sonolyth-android-all-arch.apk"),
    );

    stdout.writeln("✅ Built Android Apk and Appbundle");
  }
}
