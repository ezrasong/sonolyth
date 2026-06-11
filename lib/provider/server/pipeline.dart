import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';

final pipelineProvider = Provider((ref) {
  var pipeline = const Pipeline();
  if (kDebugMode) {
    // Pipeline is immutable — addMiddleware returns a new pipeline.
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline;
});
