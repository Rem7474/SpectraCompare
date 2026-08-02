import '../models/calibration_curve.dart';

/// Parses REW/miniDSP-style microphone calibration text files: whitespace-
/// or tab-delimited `freq db [phase]` rows, one per line, with `#`/`*`/`;`
/// comment lines skipped. This covers the common calibration file variant;
/// unsupported formats raise a `FormatException` rather than silently
/// mis-parsing (see plan's "Ambiguities / recommended descopes").
class CalibrationFileParser {
  const CalibrationFileParser._();

  static CalibrationCurve parse(String contents, {String name = 'Calibration'}) {
    final points = <CalibrationPoint>[];
    for (final rawLine in contents.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('*') || line.startsWith(';')) {
        continue;
      }
      final parts = line.split(RegExp(r'[\s,\t]+'));
      if (parts.length < 2) continue;
      final freq = double.tryParse(parts[0]);
      final db = double.tryParse(parts[1]);
      if (freq == null || db == null) continue;
      points.add(CalibrationPoint(freq, db));
    }
    if (points.isEmpty) {
      throw const FormatException('No valid frequency/dB rows found in calibration file');
    }
    points.sort((a, b) => a.freqHz.compareTo(b.freqHz));
    return CalibrationCurve(name: name, points: points);
  }
}
