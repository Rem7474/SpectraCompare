import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import '../models/frequency_response.dart';
import 'fft_utils.dart';

/// Extracts a loudspeaker's frequency response from a captured exponential
/// (logarithmic) sine sweep recording, using Farina's ESS deconvolution
/// method — the same technique used by REW/ARTA.
///
/// The forward sweep `x(t) = sin(K·(exp(t/L) − 1))`, `L = T / ln(f1/f0)`, has
/// an amplitude spectrum that falls off at −3dB/octave. Its inverse filter is
/// the time-reversed sweep with a compensating envelope `exp(-t/L)`. Linearly
/// convolving a captured response with this inverse filter yields the
/// system's impulse response directly, with harmonic-distortion products
/// appearing before the main (linear) impulse peak.
class ExponentialSweepDeconvolver {
  final double f0;
  final double f1;
  final double durationS;
  final int sampleRate;

  const ExponentialSweepDeconvolver({
    required this.f0,
    required this.f1,
    required this.durationS,
    required this.sampleRate,
  });

  double get _l => durationS / math.log(f1 / f0);

  /// Builds the inverse filter for a sweep of the same params as this
  /// deconvolver, given the (ideal, generated) forward [sweep] samples.
  Float64List inverseFilter(List<double> sweep) {
    final n = sweep.length;
    final l = _l;
    final inv = Float64List(n);
    double maxAbs = 0;
    for (int i = 0; i < n; i++) {
      final t = i / sampleRate;
      final envelope = math.exp(-t / l);
      final v = sweep[n - 1 - i] * envelope;
      inv[i] = v;
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs > 0) {
      for (int i = 0; i < n; i++) {
        inv[i] /= maxAbs;
      }
    }
    return inv;
  }

  /// Linearly convolves [recorded] (the captured, possibly noisy response)
  /// with [inverseFilter] to produce the impulse response. Full linear
  /// convolution length (`recorded.length + inverseFilter.length - 1`),
  /// computed via zero-padded circular convolution (no wraparound aliasing).
  Float64List impulseResponse(
    List<double> recorded,
    List<double> inverseFilter,
  ) {
    final linearLength = recorded.length + inverseFilter.length - 1;
    final n = FftUtils.nextPowerOfTwo(linearLength);
    final fft = FFT(n);
    final a = ComplexArray.fromRealArray(recorded, n);
    final b = ComplexArray.fromRealArray(inverseFilter, n);
    fft
      ..inPlaceFft(a)
      ..inPlaceFft(b);
    a.complexMultiply(b);
    final full = fft.realInverseFft(a);
    return Float64List.sublistView(full, 0, linearLength);
  }

  /// Runs the full deconvolution pipeline: builds the inverse filter from the
  /// known [referenceSweep], convolves it with [recordedSegment], locates and
  /// windows the clean linear impulse response around its peak, and returns
  /// the resulting magnitude frequency response.
  FrequencyResponse frequencyResponseFrom(
    List<double> recordedSegment,
    List<double> referenceSweep, {
    double preMs = 5,
    double postMs = 400,
    double taperFraction = 0.1,
  }) {
    final inv = inverseFilter(referenceSweep);
    final ir = impulseResponse(recordedSegment, inv);

    int peakIndex = 0;
    double peakAbs = 0;
    for (int i = 0; i < ir.length; i++) {
      final a = ir[i].abs();
      if (a > peakAbs) {
        peakAbs = a;
        peakIndex = i;
      }
    }

    final preSamples = (preMs * sampleRate / 1000).round();
    final postSamples = (postMs * sampleRate / 1000).round();
    final start = math.max(0, peakIndex - preSamples);
    final end = math.min(ir.length, peakIndex + postSamples);
    final segment = Float64List.sublistView(ir, start, end);
    final relativePeakIndex = peakIndex - start;

    final window = _asymmetricWindow(
      length: segment.length,
      peakIndex: relativePeakIndex,
      rightTaperFraction: taperFraction,
    );
    final tapered = Float64List(segment.length);
    for (int i = 0; i < segment.length; i++) {
      tapered[i] = segment[i] * window[i];
    }

    final spectrum = FftUtils.magnitudeSpectrum(
      tapered,
      sampleRate,
      hannWindow: false,
    );

    final points = <FrequencyResponsePoint>[];
    for (int i = 0; i < spectrum.freqsHz.length; i++) {
      final f = spectrum.freqsHz[i];
      if (f < f0 || f > f1) continue;
      points.add(FrequencyResponsePoint(f, spectrum.magnitudesDb[i]));
    }
    return FrequencyResponse(points);
  }

  /// Builds an asymmetric acoustic measurement window around [peakIndex]
  /// in the impulse response segment.
  ///
  /// Unlike a symmetric Tukey window (which would attenuate the direct sound
  /// peak if pre and post window durations are asymmetrical), this preserves
  /// the direct acoustic arrival peak at unity gain (1.0), applies a smooth
  /// half-Hann fade-in on the pre-peak arrival, and a smooth fade-out on the
  /// post-peak room tail.
  static Float64List _asymmetricWindow({
    required int length,
    required int peakIndex,
    double rightTaperFraction = 0.2,
  }) {
    final w = Float64List(length)..fillRange(0, length, 1.0);
    if (length < 2) return w;

    // Left fade-in (pre-peak)
    if (peakIndex > 0) {
      for (int i = 0; i < peakIndex; i++) {
        w[i] = 0.5 * (1 - math.cos(math.pi * i / peakIndex));
      }
    }

    // Right fade-out (post-peak tail)
    final postSamples = length - 1 - peakIndex;
    if (postSamples > 0 && rightTaperFraction > 0) {
      final taperLen = math.max(1, (postSamples * rightTaperFraction).round());
      final taperStart = length - taperLen;
      for (int i = taperStart; i < length; i++) {
        final progress = (i - taperStart + 1) / (taperLen + 1);
        w[i] = 0.5 * (1 + math.cos(math.pi * progress));
      }
    }

    return w;
  }
}
