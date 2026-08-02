import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';
import 'package:spectra_compare/core/models/measurement.dart';
import 'package:spectra_compare/core/models/signal_config.dart';
import 'package:spectra_compare/core/storage/export_service.dart';

Measurement _measurement(String model, List<FrequencyResponsePoint> points) => Measurement(
      createdAt: DateTime.utc(2026, 1, 1),
      speakerModel: model,
      outputLevelDbfs: -20,
      signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
      sampleRate: 44100,
      frequencyResponse: FrequencyResponse(points),
    );

void main() {
  group('ExportService', () {
    test('frequencyResponseToCsv includes a header and one row per point', () {
      final csv = ExportService.frequencyResponseToCsv(
        const FrequencyResponse([
          FrequencyResponsePoint(100, -3.0),
          FrequencyResponsePoint(1000, 0.0),
        ]),
      );
      final lines = csv.trim().split('\r\n');
      expect(lines.first, 'freq_hz,magnitude_db');
      expect(lines.length, 3);
      expect(lines[1], '100.0,-3.0');
    });

    test('comparisonToCsv aligns measurements by frequency and leaves gaps blank', () {
      final a = _measurement('A', const [FrequencyResponsePoint(1000, 0.0)]);
      final b = _measurement('B', const [
        FrequencyResponsePoint(1000, -2.0),
        FrequencyResponsePoint(2000, -4.0),
      ]);
      final csv = ExportService.comparisonToCsv([a, b]);
      final lines = csv.trim().split('\r\n');
      expect(lines.first, 'freq_hz,A,B');
      expect(lines[1], '1000.0,0.0,-2.0');
      expect(lines[2], '2000.0,,-4.0'); // A has no point at 2000Hz
    });

    test('comparisonToCsv on an empty list returns an empty string', () {
      expect(ExportService.comparisonToCsv([]), '');
    });

    test('measurementToJson round-trips key fields', () {
      final m = _measurement('C', const [FrequencyResponsePoint(500, -1.5)]);
      final json = jsonDecode(ExportService.measurementToJson(m)) as Map<String, dynamic>;
      expect(json['speakerModel'], 'C');
      expect(json['outputLevelDbfs'], -20);
      expect(json['sampleRate'], 44100);
      expect((json['frequencyResponse'] as List).single['freqHz'], 500);
    });

    test('measurementsToJson produces a JSON array', () {
      final list = [_measurement('A', const []), _measurement('B', const [])];
      final json = jsonDecode(ExportService.measurementsToJson(list)) as List<dynamic>;
      expect(json.length, 2);
      expect(json[0]['speakerModel'], 'A');
      expect(json[1]['speakerModel'], 'B');
    });
  });
}
