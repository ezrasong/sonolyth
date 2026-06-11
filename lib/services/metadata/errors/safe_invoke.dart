import 'dart:async';

import 'package:hetu_script/values.dart';
import 'package:sonolyth/services/logger/logger.dart';

/// One predictable exception type for anything that goes wrong inside a
/// plugin endpoint call, so a buggy or hung plugin surfaces as a normal
/// async error instead of a raw Hetu error (or an indefinite hang) in
/// whatever UI triggered the fetch.
class PluginEndpointException implements Exception {
  final String method;
  final Object? cause;
  final bool timedOut;

  PluginEndpointException.failed(this.method, this.cause) : timedOut = false;
  PluginEndpointException.timeout(this.method)
      : cause = null,
        timedOut = true;

  @override
  String toString() => timedOut
      ? "PluginEndpointException: plugin call '$method' timed out"
      : "PluginEndpointException: plugin call '$method' failed: $cause";
}

extension SafeHetuInvoke on HTInstance {
  /// Upper bound for a single plugin call; generous because plugins retry
  /// rate-limited requests with backoff internally. Interactive flows
  /// (webview login) must NOT go through this wrapper.
  static const timeLimit = Duration(seconds: 90);

  Future<dynamic> safeInvoke(
    String method, {
    List<dynamic> positionalArgs = const [],
    Map<String, dynamic> namedArgs = const {},
  }) async {
    try {
      final result = invoke(
        method,
        positionalArgs: positionalArgs,
        namedArgs: namedArgs,
      );
      if (result is Future) {
        return await result.timeout(SafeHetuInvoke.timeLimit);
      }
      return result;
    } on TimeoutException catch (e, stack) {
      AppLogger.reportError(e, stack);
      throw PluginEndpointException.timeout(method);
    } catch (e, stack) {
      if (e is PluginEndpointException) rethrow;
      AppLogger.reportError(e, stack);
      throw PluginEndpointException.failed(method, e);
    }
  }
}
