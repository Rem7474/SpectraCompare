import 'dart:math' as math;

class CalibrationPoint {
  final double freqHz;
  final double correctionDb;

  const CalibrationPoint(this.freqHz, this.correctionDb);
}

/// A microphone calibration correction curve, as imported from a REW- or
/// miniDSP-style text file (see `CalibrationFileParser`).
class CalibrationCurve {
  final int? id;
  final String name;
  final List<CalibrationPoint> points; // must be sorted by freqHz ascending

  const CalibrationCurve({this.id, required this.name, required this.points});

  /// Correction in dB at [freqHz], via linear interpolation in log-frequency
  /// space between the two nearest calibration points. Clamps to the nearest
  /// edge point outside the curve's range.
  double correctionAt(double freqHz) {
    if (points.isEmpty) return 0;
    if (points.length == 1) return points.first.correctionDb;
    if (freqHz <= points.first.freqHz) return points.first.correctionDb;
    if (freqHz >= points.last.freqHz) return points.last.correctionDb;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (freqHz >= a.freqHz && freqHz <= b.freqHz) {
        if (a.freqHz == b.freqHz) return a.correctionDb;
        final logF = math.log(freqHz);
        final logA = math.log(a.freqHz);
        final logB = math.log(b.freqHz);
        final t = (logF - logA) / (logB - logA);
        return a.correctionDb + t * (b.correctionDb - a.correctionDb);
      }
    }
    return 0;
  }
}
