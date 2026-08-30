import 'dart:math' as math;

import '../models/frequency_response.dart';

enum SmoothingType {
  none('Brut', 0),
  octave1_24('1/24 oct', 24),
  octave1_12('1/12 oct', 12),
  octave1_6('1/6 oct', 6),
  octave1_3('1/3 oct', 3);

  final String label;
  final int fraction;

  const SmoothingType(this.label, this.fraction);
}

/// Applies standard fractional-octave smoothing to frequency responses.
class FrequencySmoothing {
  const FrequencySmoothing._();

  /// Smooths a given [response] using Gaussian weighting across fractional
  /// octave bandwidth $B = 1 / \text{fraction}$.
  static FrequencyResponse smooth(
    FrequencyResponse response,
    SmoothingType type,
  ) {
    if (type == SmoothingType.none || response.points.length < 3) {
      return response;
    }

    final points = response.points;
    final n = points.length;
    final smoothed = <FrequencyResponsePoint>[];

    final octWidth = 1.0 / type.fraction;

    for (int i = 0; i < n; i++) {
      final fCenter = points[i].freqHz;
      if (fCenter <= 0) {
        smoothed.add(points[i]);
        continue;
      }

      final logCenter = math.log(fCenter);
      final halfWidthLog = (octWidth / 2.0) * math.ln2;
      final minLog = logCenter - halfWidthLog * 2.5;
      final maxLog = logCenter + halfWidthLog * 2.5;

      double weightSum = 0.0;
      double weightedMagSum = 0.0;

      for (int j = 0; j < n; j++) {
        final f = points[j].freqHz;
        if (f <= 0) continue;
        final logF = math.log(f);
        if (logF < minLog || logF > maxLog) continue;

        final dist = (logF - logCenter) / halfWidthLog;
        final weight = math.exp(-0.5 * dist * dist);

        weightSum += weight;
        weightedMagSum += weight * points[j].magnitudeDb;
      }

      final mag =
          weightSum > 0 ? (weightedMagSum / weightSum) : points[i].magnitudeDb;
      smoothed.add(FrequencyResponsePoint(fCenter, mag));
    }

    return FrequencyResponse(smoothed);
  }
}
