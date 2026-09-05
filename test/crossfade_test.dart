import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonolyth/models/playback/crossfade.dart';
import 'package:sonolyth/services/audio_player/crossfade_engine.dart';

void main() {
  group('crossfade gain curves', () {
    for (final curve in CrossfadeCurve.values) {
      test('$curve starts silent and ends at full for the incoming track', () {
        expect(crossfadeInGain(curve, 0), closeTo(0, 1e-9));
        expect(crossfadeInGain(curve, 1), closeTo(1, 1e-9));
      });

      test('$curve starts full and ends silent for the outgoing track', () {
        expect(crossfadeOutGain(curve, 0), closeTo(1, 1e-9));
        expect(crossfadeOutGain(curve, 1), closeTo(0, 1e-9));
      });

      test('$curve is monotonic across the fade', () {
        var previousIn = -1.0;
        var previousOut = 2.0;
        for (var i = 0; i <= 100; i++) {
          final t = i / 100;
          final gainIn = crossfadeInGain(curve, t);
          final gainOut = crossfadeOutGain(curve, t);
          expect(gainIn, greaterThanOrEqualTo(previousIn));
          expect(gainOut, lessThanOrEqualTo(previousOut));
          previousIn = gainIn;
          previousOut = gainOut;
        }
      });

      test('$curve clamps progress outside 0..1', () {
        expect(crossfadeInGain(curve, -0.5), closeTo(0, 1e-9));
        expect(crossfadeInGain(curve, 1.5), closeTo(1, 1e-9));
        expect(crossfadeOutGain(curve, -0.5), closeTo(1, 1e-9));
        expect(crossfadeOutGain(curve, 1.5), closeTo(0, 1e-9));
      });
    }

    test('equal power holds summed power constant through the overlap', () {
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        final power =
            math.pow(crossfadeInGain(CrossfadeCurve.equalPower, t), 2) +
                math.pow(crossfadeOutGain(CrossfadeCurve.equalPower, t), 2);
        expect(power, closeTo(1, 1e-9));
      }
    });

    test('linear dips in power at the midpoint, which is why it is not the '
        'default', () {
      final power = math.pow(crossfadeInGain(CrossfadeCurve.linear, 0.5), 2) +
          math.pow(crossfadeOutGain(CrossfadeCurve.linear, 0.5), 2);
      expect(power, closeTo(0.5, 1e-9));
    });
  });

  group('effectiveCrossfade', () {
    const configured = Duration(seconds: 6);

    test('uses the configured fade when the track is long enough', () {
      expect(
        effectiveCrossfade(configured, const Duration(minutes: 4)),
        configured,
      );
    });

    test('never overlaps more than half the track', () {
      expect(
        effectiveCrossfade(configured, const Duration(seconds: 8)),
        const Duration(seconds: 4),
      );
    });

    test('disables itself on tracks too short for a meaningful fade', () {
      expect(
        effectiveCrossfade(configured, const Duration(milliseconds: 1500)),
        Duration.zero,
      );
    });

    test('is off when the setting is zero, whatever the track length', () {
      expect(
        effectiveCrossfade(Duration.zero, const Duration(minutes: 4)),
        Duration.zero,
      );
    });

    test('is off for an unknown track length', () {
      expect(effectiveCrossfade(configured, Duration.zero), Duration.zero);
    });

    test('handles the maximum setting', () {
      expect(
        effectiveCrossfade(
          const Duration(seconds: 12),
          const Duration(minutes: 3),
        ),
        const Duration(seconds: 12),
      );
    });
  });
}
