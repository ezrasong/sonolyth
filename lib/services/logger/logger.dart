import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide join;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonolyth/utils/platform.dart';
import 'package:logging/logging.dart' as logging;

final _loggingToLoggerLevel = {
  logging.Level.ALL: Level.all,
  logging.Level.FINEST: Level.trace,
  logging.Level.FINER: Level.debug,
  logging.Level.FINE: Level.info,
  logging.Level.CONFIG: Level.info,
  logging.Level.INFO: Level.info,
  logging.Level.WARNING: Level.warning,
  logging.Level.SEVERE: Level.error,
  logging.Level.SHOUT: Level.fatal,
  logging.Level.OFF: Level.off,
};

class AppLogger {
  static late final Logger log;
  static late final File logFile;

  /// Gates [diag] file writes. A deliberate dev instrument: source/playback
  /// resolution is otherwise silent (`catch (_)`), so failures and timings
  /// never reach `.spotube_logs`. Leave on while tuning the Qobuz/skip path;
  /// flip off (or gate on verbose) before a distribution release to avoid
  /// unbounded log growth.
  static bool diagnostics = true;

  /// Serializes diag appends so parallel prefetch resolves don't interleave
  /// half-lines in the file.
  static Future<void> _diagTail = Future.value();

  static initialize(bool verbose) {
    log = Logger(
      level: kDebugMode || (verbose && kReleaseMode) ? Level.all : Level.info,
      // methodCount: 0 — don't walk/format a stack trace on every info/debug
      // line. The default PrettyPrinter captures 2 stack frames per call, which
      // is a real main-isolate jank source when logging frequently (the
      // per-track resolve/prefetch and per-stream-request lines). Errors still
      // keep a stack (errorMethodCount default).
      printer: PrettyPrinter(methodCount: 0),
    );
  }

  static void _initInternalPackageLoggers() {
    if (!kDebugMode) return;
    logging.hierarchicalLoggingEnabled = true;
    logging.Logger('YoutubeExplode.StreamsClient')
      ..level = logging.Level.SEVERE
      ..onRecord.listen(
        (record) {
          log.log(
            _loggingToLoggerLevel[record.level] ?? Level.info,
            record.message,
            error: record.error,
            stackTrace: record.stackTrace,
            time: record.time,
          );
        },
      );
  }

  static R? runZoned<R>(R Function() body) {
    return runZonedGuarded<R>(
      () {
        WidgetsFlutterBinding.ensureInitialized();

        FlutterError.onError = (details) {
          reportError(details.exception, details.stack ?? StackTrace.current);
        };

        PlatformDispatcher.instance.onError = (error, stackTrace) {
          reportError(error, stackTrace);
          return true;
        };

        if (!kIsWeb) {
          Isolate.current.addErrorListener(
            RawReceivePort((pair) async {
              final isolateError = pair as List<dynamic>;
              reportError(
                isolateError.first.toString(),
                isolateError.last,
              );
            }).sendPort,
          );
        }

        _initInternalPackageLoggers();

        getLogsPath().then((value) => logFile = value);

        return body();
      },
      (error, stackTrace) {
        reportError(error, stackTrace);
      },
    );
  }

  static Future<File> getLogsPath() async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    if (kIsAndroid) {
      dir = (await getExternalStorageDirectory())?.path ?? "";
    }

    if (kIsMacOS) {
      dir = join((await getLibraryDirectory()).path, "Logs");
    }

    if (kIsLinux) {
      dir = join(_getXdgStateHome(), "spotube");
    }

    final file = File(join(dir, ".spotube_logs"));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  /// Low-volume, non-blocking diagnostic line (timings, source decisions).
  /// Prints to the console (visible under `flutter run`) and, when
  /// [diagnostics] is on, appends to `.spotube_logs` so a release build on a
  /// device still surfaces what the resolve path decided. Fire-and-forget:
  /// never awaits the file I/O, so it can't slow a resolve.
  static void diag(String message) {
    if (!diagnostics) return;
    // Deliberately NOT routed through `log` (PrettyPrinter) — that would add
    // synchronous main-isolate formatting on the hot resolve/prefetch path.
    // Console only in debug (cheap); the file append is async, off the UI
    // thread, and is what we read back via the logs page / adb.
    if (kDebugMode) debugPrint("[diag] $message");
    final line = "[${DateTime.now()}] $message\n";
    _diagTail = _diagTail.then((_) async {
      try {
        await logFile.writeAsString(line, mode: FileMode.writeOnlyAppend);
      } catch (_) {
        // logFile may not be initialized yet, or the write may fail — a
        // diagnostic line is never worth surfacing an error for.
      }
    });
  }

  static Future<void> reportError(
    dynamic error, [
    StackTrace? stackTrace,
    message = "",
  ]) async {
    log.e(message, error: error, stackTrace: stackTrace);

    if (kReleaseMode) {
      await logFile.writeAsString(
        "[${DateTime.now()}]---------------------\n"
        "$error\n$stackTrace\n"
        "----------------------------------------\n",
        mode: FileMode.writeOnlyAppend,
      );
    }
  }

  static String _getXdgStateHome() {
    // path_provider seems does not support XDG_STATE_HOME,
    // which is the specification to store application logs on Linux.
    // See https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
    // TODO: Use path_provider once it supports XDG_STATE_HOME
    if (const bool.hasEnvironment("XDG_STATE_HOME")) {
      String xdgStateHomeRaw = Platform.environment["XDG_STATE_HOME"] ?? "";
      if (xdgStateHomeRaw.isNotEmpty) {
        return xdgStateHomeRaw;
      }
    }
    return join(Platform.environment["HOME"] ?? "", ".local", "state");
  }
}

class AppLoggerProviderObserver extends ProviderObserver {
  const AppLoggerProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    AppLogger.reportError(error, stackTrace);
  }
}
