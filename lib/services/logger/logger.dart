import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide join;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonolyth/services/logger/log_file_trimmer.dart';
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

  /// `.spotube_logs`, once [getLogsPath] has resolved. Null before that, so
  /// an early error or diag line is dropped rather than tripping a late-init
  /// error inside the error handler itself.
  static File? _logFile;

  /// Running byte count of [_logFile], maintained by [_append] so the size
  /// cap ([kLogFileMaxBytes]) is enforced without a stat per line. Seeded
  /// from the real length on attach and re-read after every trim.
  static int _approxLogBytes = 0;

  /// Gates [diag] writes. A deliberate dev instrument: source/playback
  /// resolution is otherwise silent (`catch (_)`), so failures and timings
  /// never reach `.spotube_logs`.
  ///
  /// **On in debug, off in release.** It used to be a hard `false`, which
  /// meant every `diag` call in the app — including the `[zarz:…]` session
  /// diagnostics that exist precisely so a captcha loop can be diagnosed —
  /// was dead code that had to be re-enabled by editing this line and
  /// rebuilding. Tying it to [kDebugMode] keeps the original intent (no log
  /// growth and no per-line overhead in a distribution build) while making a
  /// debug build actually observable. Set it to `true` here to keep the
  /// tracing in a release build when testing on a physical device.
  static bool diagnostics = kDebugMode;

  /// Serializes every write to `.spotube_logs` — diag lines, release error
  /// blocks, the startup trim and [clearLogs] — so parallel prefetch resolves
  /// don't interleave half-lines and a trim never races an append.
  static Future<void> _writeTail = Future.value();

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
          // `reportError` forwards only `details.exception`, which throws away
          // `details.context` and `informationCollector` — the part of a layout
          // error (overflow, unbounded constraints) naming the offending
          // widget: "The relevant error-causing widget was ...". Without it an
          // overflow report is untraceable.
          //
          // Flutter's own `presentError` would print that tree, but it goes
          // through `debugPrint`, which throttles at 12KB/s and drops a dump
          // this size on Android. Render it and emit it with plain `print`.
          if (kDebugMode) _dumpDiagnostics(details);
          reportError(details.exception, details.stack ?? StackTrace.current);
        };

        PlatformDispatcher.instance.onError = (error, stackTrace) {
          reportError(error, stackTrace);
          return true;
        };

        Isolate.current.addErrorListener(
          RawReceivePort((pair) async {
            final isolateError = pair as List<dynamic>;
            reportError(
              isolateError.first.toString(),
              isolateError.last,
            );
          }).sendPort,
        );

        _initInternalPackageLoggers();

        getLogsPath().then(_attachLogFile);

        return body();
      },
      (error, stackTrace) {
        reportError(error, stackTrace);
      },
    );
  }

  /// Debug-only: the full diagnostics tree for [details], one `print` per
  /// line so nothing is throttled away. Guarded because a badly-behaved
  /// `informationCollector` must not turn one error into two.
  static void _dumpDiagnostics(FlutterErrorDetails details) {
    try {
      final tree = details
          .toDiagnosticsNode(style: DiagnosticsTreeStyle.error)
          .toStringDeep();
      for (final line in tree.split("\n")) {
        // ignore: avoid_print
        print("[flutter-error] $line");
      }
    } catch (_) {
      // ignore: avoid_print
      print("[flutter-error] ${details.exception} (diagnostics unavailable)");
    }
  }

  static Future<File> getLogsPath() async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    if (kIsAndroid) {
      dir = (await getExternalStorageDirectory())?.path ?? "";
    }

    final file = File(join(dir, ".spotube_logs"));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  /// Binds the log file and trims it if a previous run let it grow past the
  /// cap. Runs on the write chain so nothing logged during the trim is lost:
  /// appends queue behind it and land in the trimmed file.
  static void _attachLogFile(File file) {
    _writeTail = _writeTail.then((_) async {
      _logFile = file;
      try {
        _approxLogBytes = await trimLogFile(file);
      } catch (_) {
        _approxLogBytes = 0;
      }
    });
  }

  /// Appends [text] to `.spotube_logs` on the serialized write chain and
  /// trims the file once the running size passes [kLogFileMaxBytes]. Never
  /// throws: a log line is never worth surfacing an error for, and this is
  /// called from inside the error handlers.
  static Future<void> _append(String text) {
    return _writeTail = _writeTail.then((_) async {
      final file = _logFile;
      if (file == null) return;
      try {
        await file.writeAsString(text, mode: FileMode.writeOnlyAppend);
        // UTF-16 length under-counts multi-byte text slightly; the cap is
        // a ceiling, not a contract, and the trim re-reads the true size.
        _approxLogBytes += text.length;
        if (_approxLogBytes > kLogFileMaxBytes) {
          _approxLogBytes = await trimLogFile(file);
        }
      } catch (_) {
        // The write or the trim failed — drop the line, keep the app.
      }
    });
  }

  /// Empties `.spotube_logs` (the Logs page's trash button). Goes through
  /// the write chain so an in-flight append can't resurrect old content, and
  /// resets the size accounting.
  static Future<void> clearLogs() {
    return _writeTail = _writeTail.then((_) async {
      final file = _logFile ?? await getLogsPath();
      try {
        await file.writeAsString("");
      } catch (_) {}
      _approxLogBytes = 0;
    });
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
    _append("[${DateTime.now()}] $message\n");
  }

  static Future<void> reportError(
    dynamic error, [
    StackTrace? stackTrace,
    message = "",
  ]) async {
    log.e(message, error: error, stackTrace: stackTrace);

    if (kReleaseMode) {
      await _append(
        "[${DateTime.now()}]---------------------\n"
        "$error\n$stackTrace\n"
        "----------------------------------------\n",
      );
    }
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
