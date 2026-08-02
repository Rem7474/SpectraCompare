import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/dsp/welch.dart';

void main() {
  group('Welch.averagedSpectrum', () {
    const sampleRate = 44100;

    test('finds a spectral peak at the frequency of a pure sine', () {
      final samples = List<double>.generate(
        sampleRate * 2,
        (i) => math.sin(2 * math.pi * 1000 * i / sampleRate),
      );
      final spectrum = Welch.averagedSpectrum(
        samples,
        sampleRate,
        segmentLength: 4096,
      );
      var peak = spectrum.points.first;
      for (final p in spectrum.points) {
        if (p.magnitudeDb > peak.magnitudeDb) peak = p;
      }
      expect(peak.freqHz, closeTo(1000, 20));
    });

    test('handles input shorter than the segment length without throwing', () {
      final samples = List<double>.generate(
        500,
        (i) => math.sin(2 * math.pi * 440 * i / sampleRate),
      );
      final spectrum = Welch.averagedSpectrum(
        samples,
        sampleRate,
        segmentLength: 4096,
      );
      expect(spectrum.points, isNotEmpty);
    });

    test('returns empty response for empty input', () {
      final spectrum = Welch.averagedSpectrum(const [], sampleRate);
      expect(spectrum.points, isEmpty);
    });
  });
}
