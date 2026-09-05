import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

/// Scripted stand-in for the zarz v2 gateway.
///
/// Response shapes are the real ones, probed live against `api.zarz.moe`
/// (2026-08-30): a rejected signed request answers
/// `{"error":...,"code":"SESSION_INVALID","origin":"gateway",
///   "action":"bootstrap_session"}`, and `/bootstrap` hands back a
/// `challenge_id` + `turnstile_site_key` rather than a session.
class _FakeGateway implements HttpClientAdapter {
  _FakeGateway({
    required this.currentSession,
    this.refreshSucceeds = false,
    this.bootstrapGrants = 0,
    this.ticketStatusWhenStale = 401,
    this.ticketBodyWhenStale = const {
      "error": "Unauthorized",
      "code": "SESSION_INVALID",
      "origin": "gateway",
      "action": "bootstrap_session",
    },
  });

  /// The one session id the gateway will accept on `/tickets` right now.
  String currentSession;
  final bool refreshSucceeds;

  /// How many times `/bootstrap` hands back a session with no human check
  /// before falling back to a Turnstile challenge.
  int bootstrapGrants;

  final int ticketStatusWhenStale;
  final Map<String, dynamic> ticketBodyWhenStale;

  final List<String> calls = [];
  int _issued = 0;

  /// Held open so several `/tickets` calls are genuinely in flight at once —
  /// the whole point of the concurrency test.
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    calls.add(path);

    ResponseBody json(int status, Map<String, dynamic> body) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: ["application/json"],
          },
        );

    Map<String, dynamic> grant() {
      currentSession = "s${++_issued}";
      return {
        "session_id": currentSession,
        "session_secret": "secret-$currentSession",
        "expires_at": DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
      };
    }

    if (path.endsWith("/bootstrap")) {
      if (bootstrapGrants > 0) {
        bootstrapGrants--;
        return json(200, grant());
      }
      return json(200, {
        "challenge_id": "chl_fake",
        "server_nonce": "nonce",
        "expires_in": 300,
        "turnstile_site_key": "0x0",
      });
    }

    if (path.endsWith("/session/refresh")) {
      if (!refreshSucceeds) return json(401, ticketBodyWhenStale);
      return json(200, grant());
    }

    // /tickets - accepted only when signed with the session the gateway holds.
    if (gate != null) await gate!.future;
    final presented = options.headers["X-Zarz-Session"]?.toString();
    if (presented == currentSession) {
      return json(200, {"ticket_id": "tkt-$presented"});
    }
    return json(ticketStatusWhenStale, ticketBodyWhenStale);
  }

  @override
  void close({bool force = false}) {}
}

ZarzSession _sessionWith(_FakeGateway gateway) {
  final dio = Dio()..httpClientAdapter = gateway;
  return ZarzSession(
    appVersion: "test-app@1.0.0",
    stateId: "test",
    dio: dio,
  );
}

void _seedStoredSession(String sessionId) {
  SharedPreferences.setMockInitialValues({
    "zarz_session_test-app@1.0.0": jsonEncode({
      "install_id": "aabbccddeeff0011",
      "session_id": sessionId,
      "session_secret": "secret-$sessionId",
      "expires_at":
          DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
    }),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('signed-request recovery (CONTEXT 16g)', () {
    test(
        'a concurrent rejection does not clear the session the other '
        'request just established', () async {
      // The observed failure: two /tickets calls signed with a stale session
      // both get rejected. The first recovers via bootstrap and stores a good
      // session; the second, still running its own ladder, reaches the end and
      // CLEARS it - costing a Turnstile on the next launch.
      _seedStoredSession("s0");
      final gateway = _FakeGateway(currentSession: "s0", bootstrapGrants: 1);
      final session = _sessionWith(gateway);

      // Rotate the gateway out from under both requests, then let them fly
      // together.
      gateway.currentSession = "stale-now";
      gateway.gate = Completer<void>();
      final a = session.mintTicket("qobuz", "track", "1");
      final b = session.mintTicket("qobuz", "track", "2");
      gateway.gate!.complete();

      final tickets = await Future.wait([a, b]);

      expect(tickets, everyElement(startsWith("tkt-")));
      expect(
        await session.isAuthenticated(),
        isTrue,
        reason: 'the recovered session must survive the concurrent ladder',
      );
    });

    test('a 428 leaves the session alone', () async {
      // 428 is `Precondition Required` - a fact about the request, not a
      // verdict on the credentials. Live probing shows the gateway says
      // SESSION_INVALID/bootstrap_session when it means the session is dead.
      _seedStoredSession("s0");
      final gateway = _FakeGateway(
        currentSession: "unreachable",
        ticketStatusWhenStale: 428,
        ticketBodyWhenStale: const {
          "error": "Precondition Required",
          "code": "TICKET_PRECONDITION",
          "origin": "gateway",
        },
      );
      final session = _sessionWith(gateway);

      await expectLater(
        session.mintTicket("qobuz", "track", "1"),
        throwsA(isA<ZarzVerificationRequiredException>()),
      );
      expect(
        await session.isAuthenticated(),
        isTrue,
        reason: '428 must not cost the user a Turnstile',
      );
      expect(gateway.calls.where((c) => c.endsWith("/bootstrap")), isEmpty);
    });

    test('a 401 the gateway attributes to the session still clears it',
        () async {
      // The guard must not become so lenient that a genuinely dead session
      // sticks around and every track silently fails.
      _seedStoredSession("s0");
      final gateway = _FakeGateway(currentSession: "unreachable");
      final session = _sessionWith(gateway);

      await expectLater(
        session.mintTicket("qobuz", "track", "1"),
        throwsA(isA<ZarzVerificationRequiredException>()),
      );
      expect(await session.isAuthenticated(), isFalse);
    });

    test('a refresh that rotates the session is retried, not cleared',
        () async {
      _seedStoredSession("s0");
      final gateway = _FakeGateway(
        currentSession: "unreachable",
        refreshSucceeds: true,
      );
      final session = _sessionWith(gateway);

      expect(
          await session.mintTicket("qobuz", "track", "1"), startsWith("tkt-"));
      expect(await session.isAuthenticated(), isTrue);
    });
  });
}
