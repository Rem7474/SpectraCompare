import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/signal_generator.dart';
import 'package:spectra_compare/core/dsp/deconvolution.dart';
import 'package:spectra_compare/core/dsp/fft_utils.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';

/// Naive (non-FFT) linear convolution, used only to build the synthetic
/// "recording" for this test — deliberately independent from the FFT-based
/// convolution used inside `ExponentialSweepDeconvolver`.
List<double> _naiveConvolve(List<double> a, List<double> b) {
  final out = List<double>.filled(a.length + b.length - 1, 0.0);
  for (int i = 0; i < a.length; i++) {
    if (a[i] == 0) continue;
    for (int j = 0; j < b.length; j++) {
      out[i + j] += a[i] * b[j];
    }
  }
  return out;
}

double _dbAtNearestFreq(FrequencyResponse response, double targetFreq) {
  var best = response.points.first;
  var bestDist = (best.freqHz - targetFreq).abs();
  for (final p in response.points) {
    final dist = (p.freqHz - targetFreq).abs();
    if (dist < bestDist) {
      best = p;
      bestDist = dist;
    }
  }
  return best.magnitudeDb;
}

void main() {
  test(
    'deconvolution recovers the relative frequency response of a known FIR "speaker"',
    () {
      const sampleRate = 44100;
      const f0 = 100.0, f1 = 10000.0, duration = 2.0;

      // A simple 3-tap smoothing (lowpass-leaning) FIR standing in for a
      // "fake speaker" with known, non-flat frequency response.
      const fir = [1.0, 0.7, 0.3];

      final sweep = SignalGenerator.sineSweep(
        f0: f0,
        f1: f1,
        durationS: duration,
        sampleRate: sampleRate,
      );
      final recorded = _naiveConvolve(sweep, fir);

      final deconvolver = const ExponentialSweepDeconvolver(
        f0: f0,
        f1: f1,
        durationS: duration,
        sampleRate: sampleRate,
      );
      final recovered = deconvolver.frequencyResponseFrom(recorded, sweep);

      // Independently compute the FIR's true frequency response via a direct
      // FFT of its taps (zero-padded).
      final expected = FftUtils.magnitudeSpectrum(
        fir,
        sampleRate,
        hannWindow: false,
        fftSize: 65536,
      );
      final expectedResponse = FrequencyResponse([
        for (int i = 0; i < expected.freqsHz.length; i++)
          FrequencyResponsePoint(expected.freqsHz[i], expected.magnitudesDb[i]),
      ]);

      // Deconvolution only guarantees the *relative* response shape (absolute
      // level depends on inverse-filter normalization) — so compare each curve
      // relative to its value at 1000Hz.
      const refFreq = 1000.0;
      final expectedRef = _dbAtNearestFreq(expectedResponse, refFreq);
      final recoveredRef = _dbAtNearestFreq(recovered, refFreq);

      for (final testFreq in [300.0, 1000.0, 2000.0, 4000.0, 8000.0]) {
        final expectedRel =
            _dbAtNearestFreq(expectedResponse, testFreq) - expectedRef;
        final recoveredRel =
            _dbAtNearestFreq(recovered, testFreq) - recoveredRef;
        expect(
          recoveredRel,
          closeTo(expectedRel, 3.0),
          reason:
              'at ${testFreq}Hz: expected ${expectedRel}dB relative, got ${recoveredRel}dB relative',
        );
      }
    },
  );
}
