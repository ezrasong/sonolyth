import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// The whole of `.spotube_logs` as one string.
///
/// This used to be a `StreamProvider` that yielded every decoded chunk of
/// `openRead()` as its own value, so the Logs page rendered only the file's
/// last ~64 KB and the copy button copied a single chunk. Reading it whole
/// is safe now that the file is capped (see `log_file_trimmer.dart`).
///
/// Throws [StateError] for an empty file — the page shows its "no logs"
/// state on that.
final logsProvider = FutureProvider.autoDispose<String>((ref) async {
  final file = await AppLogger.getLogsPath();

  if (await file.length() == 0) {
    throw StateError("Logs file is empty or non-existent");
  }

  return file.readAsString();
});
