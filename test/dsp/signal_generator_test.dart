import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/signal_generator.dart';
import 'package:spectra_compare/core/dsp/welch.dart';

/// Estimates the average frequency over `samples[start:start+length]` via
/// zero-crossing rate — an independent (non-circular) way to sanity-check the
/// sweep math.
double _zeroCrossingFreq(
  List<double> samples,
  int start,
  int length,
  int sampleRate,
) {
  int crossings = 0;
  for (int i = start + 1; i < start + length; i++) {
    if ((samples[i - 1] < 0) != (samples[i] < 0)) crossings++;
  }
  final durationS = length / sampleRate;
  return crossings / 2 / durationS;
}

/// Analytically-correct average frequency of a log sweep over `[t1, t2]`:
/// `(phase(t2) - phase(t1)) / (2π(t2 - t1))`.
double _expectedAvgFreqLog(
  double f0,
  double f1,
  double durationS,
  double t1,
  double t2,
) {
  final l = durationS / math.log(f1 / f0);
  final k = 2 * math.pi * f0 * l;
  double phase(double t) => k * (math.exp(t / l) - 1);
  return (phase(t2) - phase(t1)) / (2 * math.pi * (t2 - t1));
}

/// Analytically-correct average frequency of a linear sweep over `[t1, t2]`.
double _expectedAvgFreqLinear(
  double f0,
  double f1,
  double durationS,
  double t1,
  double t2,
) {
  double phase(double t) =>
      2 * math.pi * (f0 * t + (f1 - f0) * t * t / (2 * durationS));
  return (phase(t2) - phase(t1)) / (2 * math.pi * (t2 - t1));
}

/// Ordinary least-squares slope of [ys] vs [xs].
double _slope(List<double> xs, List<double> ys) {
  final n = xs.length;
  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;
  double num = 0, den = 0;
  for (int i = 0; i < n; i++) {
    num += (xs[i] - meanX) * (ys[i] - meanY);
    den += (xs[i] - meanX) * (xs[i] - meanX);
  }
  return num / den;
}

void main() {
  const sampleRate = 44100;

  group('SignalGenerator.sineSweep', () {
    test(
      'log sweep instantaneous frequency matches the analytic sweep law',
      () {
        const f0 = 100.0, f1 = 8000.0, duration = 2.0;
        final s = SignalGenerator.sineSweep(
          f0: f0,
          f1: f1,
          durationS: duration,
          sampleRate: sampleRate,
        );
        // Skip the fade region at both ends. The start window needs to be much
        // longer than the end window: zero-crossing frequency estimation needs
        // several full cycles to be accurate, and f0 is much lower than f1, so
        // a short window at the low end would only contain ~1 cycle.
        const startOffset = 500,
            startWindowLen = 4410; // ~10 cycles at f0=100Hz
        final measuredStart = _zeroCrossingFreq(
          s,
          startOffset,
          startWindowLen,
          sampleRate,
        );
        final expectedStart = _expectedAvgFreqLog(
          f0,
          f1,
          duration,
          startOffset / sampleRate,
          (startOffset + startWindowLen) / sampleRate,
        );
        expect(measuredStart, closeTo(expectedStart, expectedStart * 0.1));

        const windowLen = 512;
        final endOffset = s.length - 500 - windowLen;
        final measuredEnd = _zeroCrossingFreq(
          s,
          endOffset,
          windowLen,
          sampleRate,
        );
        final expectedEnd = _expectedAvgFreqLog(
          f0,
          f1,
          duration,
          endOffset / sampleRate,
          (endOffset + windowLen) / sampleRate,
        );
        expect(measuredEnd, closeTo(expectedEnd, expectedEnd * 0.1));
      },
    );

    test(
      'linear sweep instantaneous frequency matches the analytic sweep law',
      () {
        const f0 = 100.0, f1 = 4000.0, duration = 2.0;
        final s = SignalGenerator.sineSweep(
          f0: f0,
          f1: f1,
          durationS: duration,
          sampleRate: sampleRate,
          logarithmic: false,
        );
        const startOffset = 500, windowLen = 512;
        final measuredStart = _zeroCrossingFreq(
          s,
          startOffset,
          windowLen,
          sampleRate,
        );
        final expectedStart = _expectedAvgFreqLinear(
          f0,
          f1,
          duration,
          startOffset / sampleRate,
          (startOffset + windowLen) / sampleRate,
        );
        expect(measuredStart, closeTo(expectedStart, expectedStart * 0.1));

        final endOffset = s.length - 500 - windowLen;
        final measuredEnd = _zeroCrossingFreq(
          s,
          endOffset,
          windowLen,
          sampleRate,
        );
        final expectedEnd = _expectedAvgFreqLinear(
          f0,
          f1,
          duration,
          endOffset / sampleRate,
          (endOffset + windowLen) / sampleRate,
        );
        expect(measuredEnd, closeTo(expectedEnd, expectedEnd * 0.1));
      },
    );
  });

  group('SignalGenerator noise', () {
    test('pink noise has ~ -3dB/octave spectral slope', () {
      final samples = SignalGenerator.pinkNoise(1 << 17, seed: 42);
      final spectrum = Welch.averagedSpectrum(
        samples,
        sampleRate,
        segmentLength: 4096,
      );
      final band = spectrum.points
          .where((p) => p.freqHz >= 100 && p.freqHz <= 8000)
          .toList();
      final xs = band.map((p) => math.log(p.freqHz) / math.ln2).toList();
      final ys = band.map((p) => p.magnitudeDb).toList();
      final slope = _slope(xs, ys);
      expect(slope, closeTo(-3.0, 1.5));
    });

    test('white noise has ~flat spectral slope', () {
      final samples = SignalGenerator.whiteNoise(1 << 17, seed: 42);
      final spectrum = Welch.averagedSpectrum(
        samples,
        sampleRate,
        segmentLength: 4096,
      );
      final band = spectrum.points
          .where((p) => p.freqHz >= 100 && p.freqHz <= 8000)
          .toList();
      final xs = band.map((p) => math.log(p.freqHz) / math.ln2).toList();
      final ys = band.map((p) => p.magnitudeDb).toList();
      final slope = _slope(xs, ys);
      expect(slope, closeTo(0.0, 1.5));
    });
  });

  group('SignalGenerator.applyLevelDbfs', () {
    test('scales peak amplitude to the configured dBFS level', () {
      final tone = SignalGenerator.pureTone(
        freq: 1000,
        durationS: 0.1,
        sampleRate: sampleRate,
      );
      final scaled = SignalGenerator.applyLevelDbfs(tone, -6.0);
      final peak = scaled.map((s) => s.abs()).reduce(math.max);
      final expectedPeak = math.pow(10, -6.0 / 20).toDouble();
      // pureTone itself has a small fade so its true pre-scale peak is <1;
      // check the achieved gain ratio instead of an absolute peak value.
      final tonePeak = tone.map((s) => s.abs()).reduce(math.max);
      expect(peak / tonePeak, closeTo(expectedPeak, 1e-6));
    });
  });
}
