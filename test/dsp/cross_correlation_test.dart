import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/signal_generator.dart';
import 'package:spectra_compare/core/dsp/cross_correlation.dart';

void main() {
  const sampleRate = 44100;

  group('CrossCorrelation.findOffset', () {
    test('recovers exact offset of a chirp embedded in silence', () {
      final chirp = SignalGenerator.calibrationChirp(sampleRate: sampleRate);
      const offset = 3000;
      final recorded = <double>[...List.filled(offset, 0.0), ...chirp, ...List.filled(5000, 0.0)];

      final result = CrossCorrelation.findOffset(chirp, recorded);
      expect(result.offsetSamples, offset);
      expect(result.confidence, greaterThan(0.9));
    });

    test('is robust to additive noise and a gain change', () {
      final chirp = SignalGenerator.calibrationChirp(sampleRate: sampleRate);
      const offset = 5000;
      final rand = math.Random(7);
      final recorded = List<double>.generate(offset, (_) => (rand.nextDouble() - 0.5) * 0.05);
      recorded.addAll(chirp.map((s) => s * 0.6));
      recorded.addAll(List.generate(5000, (_) => (rand.nextDouble() - 0.5) * 0.05));

      final result = CrossCorrelation.findOffset(chirp, recorded);
      expect(result.offsetSamples, offset);
    });

    test('locates the main test signal after the calibration chirp in a combined buffer', () {
      final chirp = SignalGenerator.calibrationChirp(sampleRate: sampleRate);
      final mainSignal = SignalGenerator.sineSweep(
        f0: 20,
        f1: 20000,
        durationS: 1.0,
        sampleRate: sampleRate,
      );
      final preroll = List<double>.filled(2205, 0.0); // 50ms
      final gap = List<double>.filled(4410, 0.0); // 100ms
      final combined = <double>[...preroll, ...chirp, ...gap, ...mainSignal];

      final result = CrossCorrelation.findOffset(chirp, combined);
      expect(result.offsetSamples, preroll.length);

      final mainSignalStart = result.offsetSamples + chirp.length + gap.length;
      expect(mainSignalStart, preroll.length + chirp.length + gap.length);
    });
  });
}
