class FrequencyResponsePoint {
  final double freqHz;
  final double magnitudeDb;

  const FrequencyResponsePoint(this.freqHz, this.magnitudeDb);

  Map<String, dynamic> toJson() => {'freqHz': freqHz, 'magnitudeDb': magnitudeDb};

  factory FrequencyResponsePoint.fromJson(Map<String, dynamic> json) =>
      FrequencyResponsePoint(
        (json['freqHz'] as num).toDouble(),
        (json['magnitudeDb'] as num).toDouble(),
      );
}

/// A frequency response curve: a series of (frequency, magnitude) points,
/// typically either a raw FFT-bin resolution curve or a 1/3-octave-band
/// resampled curve (see `OctaveBands.resample`).
class FrequencyResponse {
  final List<FrequencyResponsePoint> points;

  const FrequencyResponse(this.points);

  List<Map<String, dynamic>> toJsonList() => points.map((p) => p.toJson()).toList();

  factory FrequencyResponse.fromJsonList(List<dynamic> list) => FrequencyResponse(
        list.map((e) => FrequencyResponsePoint.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );

  /// Applies a mic calibration correction curve to every point, returning a
  /// new corrected `FrequencyResponse`.
  FrequencyResponse withCorrection(double Function(double freqHz) correctionAt) {
    return FrequencyResponse(
      points.map((p) => FrequencyResponsePoint(p.freqHz, p.magnitudeDb + correctionAt(p.freqHz))).toList(),
    );
  }
}
