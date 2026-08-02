import 'dart:math' as math;

/// Sound-level helpers. Phone microphones are uncalibrated by default, so all
/// values are relative (dBFS) unless a user-supplied single-point
/// calibration offset is provided (see README "Limites connues").
class Spl {
  const Spl._();

  static double rmsDbFs(List<double> samples) {
    if (samples.isEmpty) return double.negativeInfinity;
    double sumSq = 0;
    for (final s in samples) {
      sumSq += s * s;
    }
    final rms = math.sqrt(sumSq / samples.length);
    return 20 * (math.log(rms.clamp(1e-12, double.infinity)) / math.ln10);
  }

  /// Estimated SPL given a relative [dbFs] level and a [calibrationOffsetDb]
  /// obtained by the user (e.g. measured against a known SPL reference tone).
  /// Without calibration, pass `0` and treat the result as relative-only.
  static double estimateSpl(double dbFs, double calibrationOffsetDb) => dbFs + calibrationOffsetDb;
}
