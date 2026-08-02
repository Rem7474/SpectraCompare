import 'dart:math' as math;

import '../models/frequency_response.dart';
import 'fft_utils.dart';

/// Resamples a raw frequency response onto standard 1/3-octave bands, used
/// for the multi-speaker comparison feature (delta dB per band).
class OctaveBands {
  const OctaveBands._();

  /// Standard base-10 1/3-octave band center frequencies, 20Hz–20kHz
  /// (`fc = 1000 * 10^(n/10)`), ~31 bands.
  static final List<double> thirdOctaveCenters = _generateCenters();

  static List<double> _generateCenters() {
    final centers = <double>[];
    for (int n = -17; n <= 13; n++) {
      final fc = 1000 * math.pow(10, n / 10);
      if (fc >= 19.5 && fc <= 20200) {
        centers.add(double.parse(fc.toStringAsFixed(fc < 100 ? 1 : 0)));
      }
    }
    return centers;
  }

  /// Averages (in linear power) all points of [raw] falling within each
  /// band's edges (`fc / 2^(1/6)` .. `fc * 2^(1/6)`). Bands with no points are
  /// omitted from the result.
  static FrequencyResponse resample(FrequencyResponse raw) {
    final points = <FrequencyResponsePoint>[];
    final bandEdge = math.pow(2, 1 / 6);
    for (final fc in thirdOctaveCenters) {
      final lower = fc / bandEdge;
      final upper = fc * bandEdge;
      final inBand = raw.points.where((p) => p.freqHz >= lower && p.freqHz < upper);
      if (inBand.isEmpty) continue;
      double sumPower = 0;
      int count = 0;
      for (final p in inBand) {
        sumPower += math.pow(10, p.magnitudeDb / 10).toDouble();
        count++;
      }
      points.add(FrequencyResponsePoint(fc, FftUtils.powerToDb(sumPower / count)));
    }
    return FrequencyResponse(points);
  }

  /// Computes delta dB per band between [measurement] and [reference],
  /// matched by band center frequency. Bands missing from either side are
  /// omitted.
  static Map<double, double> deltaVsReference(FrequencyResponse measurement, FrequencyResponse reference) {
    final refByFreq = {for (final p in reference.points) p.freqHz: p.magnitudeDb};
    final delta = <double, double>{};
    for (final p in measurement.points) {
      final refDb = refByFreq[p.freqHz];
      if (refDb != null) {
        delta[p.freqHz] = p.magnitudeDb - refDb;
      }
    }
    return delta;
  }
}
