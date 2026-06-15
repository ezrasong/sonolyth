import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:sonolyth/provider/server/routes/connect.dart';

final pipelineProvider = Provider((ref) {
  final connectRoutes = ref.watch(serverConnectRoutesProvider);

  var pipeline = const Pipeline();
  if (kDebugMode) {
    // Pipeline is immutable — addMiddleware returns a new pipeline.
    pipeline = pipeline.addMiddleware(logRequests());
  }
  pipeline = pipeline.addMiddleware(_connectAuthMiddleware(connectRoutes));
  return pipeline;
});

/// Gates the control + stream surface so a same-LAN host can't drive playback
/// or pull audio without first being accepted through the Connect handshake.
/// Loopback (the app's own player) and the handshake endpoints stay open;
/// everything else requires an allow-listed host.
Middleware _connectAuthMiddleware(ServerConnectRoutes connectRoutes) {
  return (Handler innerHandler) {
    return (Request request) {
      // shelf strips the leading slash: "/ws" -> "ws", "/stream/<id>" ->
      // "stream/<id>". /ws runs its own interactive accept/deny and /ping is a
      // harmless liveness probe, so both stay reachable for un-accepted hosts.
      final path = request.url.path;
      if (path == "ws" || path == "ping") {
        return innerHandler(request);
      }

      final info =
          request.context["shelf.io.connection_info"] as HttpConnectionInfo?;
      final remoteAddress = info?.remoteAddress;
      final allowed = (remoteAddress?.isLoopback ?? false) ||
          connectRoutes.isHostAllowed(remoteAddress?.host);
      if (!allowed) {
        return Response.forbidden("Connect authorization required");
      }
      return innerHandler(request);
    };
  };
}
