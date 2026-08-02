import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'fft_utils.dart';

class CorrelationResult {
  /// The sample index within the recorded/searched buffer at which
  /// [reference] most likely begins.
  final int offsetSamples;

  /// Normalized cross-correlation coefficient at the best offset, roughly in
  /// [0, 1] for clean signals (can exceed 1 slightly with constructive noise).
  /// Higher is a more confident match.
  final double confidence;

  const CorrelationResult(this.offsetSamples, this.confidence);
}

/// Locates a known [reference] signal (e.g. the calibration chirp) inside a
/// longer [recorded] buffer via FFT-based cross-correlation. This is the
/// mechanism the app uses to determine the real playback→recording latency
/// without relying on any platform-specific timestamp API (see README
/// "Synchronisation et gestion de la latence").
class CrossCorrelation {
  const CrossCorrelation._();

  static CorrelationResult findOffset(List<double> reference, List<double> recorded) {
    if (reference.isEmpty || recorded.isEmpty) {
      return const CorrelationResult(0, 0);
    }
    // Zero-pad enough to avoid circular-convolution wraparound aliasing.
    final n = FftUtils.nextPowerOfTwo(reference.length + recorded.length - 1);
    final fft = FFT(n);
    final ref = ComplexArray.fromRealArray(reference, n);
    final rec = ComplexArray.fromRealArray(recorded, n);
    fft.inPlaceFft(ref);
    fft.inPlaceFft(rec);

    // Cross-correlation via conj(FFT(ref)) * FFT(rec), then inverse FFT.
    for (int i = 0; i < n; i++) {
      final r = ref[i];
      final s = rec[i];
      final real = r.x * s.x + r.y * s.y;
      final imag = r.x * s.y - r.y * s.x;
      ref[i] = Float64x2(real, imag);
    }
    final corr = fft.realInverseFft(ref);

    // Only consider lags that place the whole reference within the recorded
    // buffer; larger indices are circular-wraparound artifacts of the padding.
    final maxLag = math.max(0, recorded.length - 1);
    int bestIndex = 0;
    double bestValue = corr[0];
    for (int i = 1; i <= maxLag && i < corr.length; i++) {
      if (corr[i] > bestValue) {
        bestValue = corr[i];
        bestIndex = i;
      }
    }

    final refEnergy = _energy(reference);
    final segEnd = math.min(recorded.length, bestIndex + reference.length);
    final recEnergy = _energy(recorded.sublist(math.min(bestIndex, recorded.length), segEnd));
    final denom = math.sqrt(refEnergy * recEnergy);
    final confidence = denom > 0 ? (bestValue / denom).clamp(0.0, 2.0) : 0.0;

    return CorrelationResult(bestIndex, confidence.toDouble());
  }

  static double _energy(List<double> samples) {
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    return sum;
  }
}
