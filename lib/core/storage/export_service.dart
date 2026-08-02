import 'dart:convert';

import 'package:csv/csv.dart';

import '../models/frequency_response.dart';
import '../models/measurement.dart';

/// CSV/JSON export for measurements (see README "Export des données").
class ExportService {
  const ExportService._();

  static String frequencyResponseToCsv(FrequencyResponse response) {
    final rows = <List<dynamic>>[
      ['freq_hz', 'magnitude_db'],
      for (final p in response.points) [p.freqHz, p.magnitudeDb],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Multi-measurement comparison CSV: one frequency column plus one
  /// magnitude column per measurement, matched by exact frequency value
  /// (typically after resampling all curves onto the same octave bands).
  static String comparisonToCsv(List<Measurement> measurements) {
    if (measurements.isEmpty) return '';
    final freqSet = <double>{};
    for (final m in measurements) {
      for (final p in m.frequencyResponse.points) {
        freqSet.add(p.freqHz);
      }
    }
    final freqs = freqSet.toList()..sort();
    final header = ['freq_hz', for (final m in measurements) m.displayName];
    final rows = <List<dynamic>>[header];
    for (final f in freqs) {
      final row = <dynamic>[f];
      for (final m in measurements) {
        final point = m.frequencyResponse.points.firstWhere(
          (p) => p.freqHz == f,
          orElse: () => const FrequencyResponsePoint(0, double.nan),
        );
        row.add(point.magnitudeDb.isNaN ? '' : point.magnitudeDb);
      }
      rows.add(row);
    }
    return const ListToCsvConverter().convert(rows);
  }

  static Map<String, dynamic> measurementToJsonMap(Measurement m) => {
    'id': m.id,
    'createdAt': m.createdAt.toIso8601String(),
    'speakerModel': m.speakerModel,
    'position': m.position,
    'distanceM': m.distanceM,
    'outputLevelDbfs': m.outputLevelDbfs,
    'signalConfig': m.signalConfig.toJson(),
    'sampleRate': m.sampleRate,
    'offsetSamples': m.offsetSamples,
    'correlationConfidence': m.correlationConfidence,
    'tags': m.tags,
    'notes': m.notes,
    'frequencyResponse': m.frequencyResponse.toJsonList(),
  };

  static String measurementToJson(Measurement m) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(measurementToJsonMap(m));
  }

  static String measurementsToJson(List<Measurement> measurements) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(measurements.map(measurementToJsonMap).toList());
  }
}
