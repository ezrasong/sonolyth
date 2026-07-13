import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/services/spotiflac/zarz_session.dart';

void main() {
  group('ZarzSession.computeSignature', () {
    // Golden vector cross-checked against an independent Python implementation
    // of the gateway's ZARZ-HMAC-V1 scheme (see PR notes). If the gateway ever
    // rejects signed requests, verify this still holds before touching the port.
    test('matches the known-good vector', () {
      final body = utf8.encode(
        '{"quality":"cd","upload_to_r2":false,"id":"284323799",'
        '"type":"track","url":"https://open.qobuz.com/track/284323799"}',
      );
      // 2026-07-13T14:30:00.123Z in epoch seconds.
      final epochSeconds =
          DateTime.utc(2026, 7, 13, 14, 30, 0, 123).millisecondsSinceEpoch ~/
              1000;

      final signed = ZarzSession.computeSignature(
        method: "POST",
        escapedPath: "/v2/dl/qbz",
        bodyBytes: body,
        ts: "2026-07-13T14:30:00.123Z",
        nonce: "0011223344556677",
        epochSeconds: epochSeconds,
        sessionId: "sess_ABC123",
        sessionSecret: "secret_XYZ789",
        appVersion: "qobuz-web@1.1.0",
      );

      expect(
        signed.bodyHash,
        "3bb2e988eef54603295d36174c1c8eaf3a0d89c9f31f027df9a7e3472a6f1082",
      );
      expect(signed.rollingKey, "NK7gA7pgW80KnksDI2sDgXbxHLlCxJFj3Ewmn1C36ks");
      expect(signed.signature, "UJzMvtw_UelzcSh2DuvRz_5Z8sf7IUBJ0iUTNWBrIRM");
    });

    test('rolling key changes across time windows', () {
      List<int> body = utf8.encode('{}');
      String sigFor(int epoch) => ZarzSession.computeSignature(
            method: "POST",
            escapedPath: "/v2/tickets",
            bodyBytes: body,
            ts: "2026-07-13T14:30:00.000Z",
            nonce: "abc",
            epochSeconds: epoch,
            sessionId: "s",
            sessionSecret: "secret",
            appVersion: "qobuz-web@1.1.0",
          ).rollingKey;

      // 1200 aligns to a 300s window boundary (1200..1499). Same window → same
      // rolling key; the next window (1500) → different.
      expect(sigFor(1200), sigFor(1499));
      expect(sigFor(1200) == sigFor(1500), isFalse);
    });
  });
}
