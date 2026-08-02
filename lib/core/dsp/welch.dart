import 'dart:math' as math;

import '../models/frequency_response.dart';
import 'fft_utils.dart';

/// Averaged (Welch's method) power spectrum estimation, used for pink/white
/// noise measurements and the live analyzer view.
class Welch {
  const Welch._();

  static FrequencyResponse averagedSpectrum(
    List<double> samples,
    int sampleRate, {
    int segmentLength = 4096,
    double overlap = 0.5,
  }) {
    if (samples.isEmpty) return const FrequencyResponse([]);
    if (samples.length < segmentLength) {
      segmentLength = FftUtils.nextPowerOfTwo(samples.length);
    }
    final hop = (segmentLength * (1 - overlap)).round().clamp(1, segmentLength);

    final segments = <List<double>>[];
    for (int start = 0; start + segmentLength <= samples.length; start += hop) {
      segments.add(samples.sublist(start, start + segmentLength));
    }
    if (segments.isEmpty) {
      final padded = List<double>.from(samples)
        ..addAll(List.filled(segmentLength - samples.length, 0.0));
      segments.add(padded);
    }

    List<double>? freqs;
    List<double>? sumPower;
    for (final seg in segments) {
      final spec = FftUtils.magnitudeSpectrum(seg, sampleRate, hannWindow: true, fftSize: segmentLength);
      freqs ??= spec.freqsHz;
      sumPower ??= List<double>.filled(spec.magnitudesDb.length, 0);
      for (int i = 0; i < spec.magnitudesDb.length; i++) {
        sumPower[i] += math.pow(10, spec.magnitudesDb[i] / 10).toDouble();
      }
    }

    final n = segments.length;
    final points = <FrequencyResponsePoint>[];
    for (int i = 0; i < freqs!.length; i++) {
      final avgPower = sumPower![i] / n;
      points.add(FrequencyResponsePoint(freqs[i], FftUtils.powerToDb(avgPower)));
    }
    return FrequencyResponse(points);
  }
}
