import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/dsp/smoothing.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';

void main() {
  group('FrequencySmoothing', () {
    test('none returns the identical response', () {
      const original = FrequencyResponse([
        FrequencyResponsePoint(100, -10),
        FrequencyResponsePoint(1000, 0),
        FrequencyResponsePoint(10000, -20),
      ]);
      final smoothed = FrequencySmoothing.smooth(original, SmoothingType.none);
      expect(smoothed.points.length, original.points.length);
      for (int i = 0; i < original.points.length; i++) {
        expect(smoothed.points[i].freqHz, original.points[i].freqHz);
        expect(smoothed.points[i].magnitudeDb, original.points[i].magnitudeDb);
      }
    });

    test('fractional smoothing attenuates sharp notch/peak artifacts', () {
      final points = <FrequencyResponsePoint>[];
      for (double f = 100; f <= 10000; f *= 1.05) {
        // Flat 0 dB with a sharp 20 dB notch at 1000 Hz
        final isNotch = (f - 1000).abs() < 30;
        points.add(FrequencyResponsePoint(f, isNotch ? -20.0 : 0.0));
      }
      final raw = FrequencyResponse(points);
      final smoothed1_3 = FrequencySmoothing.smooth(
        raw,
        SmoothingType.octave1_3,
      );

      final notchPointRaw = raw.points.firstWhere(
        (p) => (p.freqHz - 1000).abs() < 30,
      );
      final notchPointSmoothed = smoothed1_3.points.firstWhere(
        (p) => (p.freqHz - 1000).abs() < 30,
      );

      expect(notchPointRaw.magnitudeDb, -20.0);
      // Smoothed notch should be substantially raised towards 0 dB
      expect(notchPointSmoothed.magnitudeDb, greaterThan(-10.0));
    });
  });
}
