import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/dsp/octave_bands.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';

void main() {
  group('OctaveBands', () {
    test(
      'center frequencies span 20Hz-20kHz and are monotonically increasing',
      () {
        final centers = OctaveBands.thirdOctaveCenters;
        expect(centers.first, lessThan(25));
        expect(centers.last, greaterThan(15000));
        for (int i = 1; i < centers.length; i++) {
          expect(centers[i], greaterThan(centers[i - 1]));
        }
      },
    );

    test('resample averages a flat response to a flat band curve', () {
      final points = [
        for (double f = 20; f <= 20000; f *= 1.02)
          FrequencyResponsePoint(f, -5.0),
      ];
      final resampled = OctaveBands.resample(FrequencyResponse(points));
      expect(resampled.points, isNotEmpty);
      for (final p in resampled.points) {
        expect(p.magnitudeDb, closeTo(-5.0, 0.1));
      }
    });

    test('resample reflects a step change between low and high bands', () {
      final points = <FrequencyResponsePoint>[];
      for (double f = 20; f <= 20000; f *= 1.02) {
        points.add(FrequencyResponsePoint(f, f < 1000 ? 0.0 : -10.0));
      }
      final resampled = OctaveBands.resample(FrequencyResponse(points));
      final low = resampled.points.firstWhere((p) => p.freqHz < 500);
      final high = resampled.points.firstWhere((p) => p.freqHz > 5000);
      expect(low.magnitudeDb, closeTo(0.0, 1.0));
      expect(high.magnitudeDb, closeTo(-10.0, 1.0));
    });

    test('deltaVsReference computes per-band dB differences', () {
      const reference = FrequencyResponse([
        FrequencyResponsePoint(1000, -3.0),
        FrequencyResponsePoint(2000, -6.0),
      ]);
      const measurement = FrequencyResponse([
        FrequencyResponsePoint(1000, -1.0),
        FrequencyResponsePoint(2000, -9.0),
      ]);
      final delta = OctaveBands.deltaVsReference(measurement, reference);
      expect(delta[1000], closeTo(2.0, 1e-9));
      expect(delta[2000], closeTo(-3.0, 1e-9));
    });
  });

  test('spot-check: thirdOctaveCenters approx doubles every 3 bands', () {
    final centers = OctaveBands.thirdOctaveCenters;
    final i1000 = centers.indexWhere((c) => (c - 1000).abs() < 1);
    expect(i1000, greaterThanOrEqualTo(0));
    if (i1000 + 3 < centers.length) {
      expect(centers[i1000 + 3] / centers[i1000], closeTo(2.0, 0.05));
    }
    // sanity: log-spacing check
    expect(math.log(centers.last / centers.first) / math.ln2, greaterThan(9));
  });
}
