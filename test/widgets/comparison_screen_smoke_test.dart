import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';
import 'package:spectra_compare/core/models/measurement.dart';
import 'package:spectra_compare/core/models/signal_config.dart';
import 'package:spectra_compare/core/storage/database.dart';
import 'package:spectra_compare/features/comparison/comparison_controller.dart';
import 'package:spectra_compare/features/comparison/comparison_screen.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets('selecting two measurements shows an overlay chart and a delta summary', (tester) async {
    final appDb = testAppDatabase();
    final dao = MeasurementDao(appDb);
    await dao.insert(
      Measurement(
        createdAt: DateTime(2026, 1, 1),
        speakerModel: 'Speaker A',
        outputLevelDbfs: -20,
        signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
        sampleRate: 44100,
        frequencyResponse: const FrequencyResponse([
          FrequencyResponsePoint(1000, 0.0),
          FrequencyResponsePoint(2000, -1.0),
        ]),
      ),
    );
    await dao.insert(
      Measurement(
        createdAt: DateTime(2026, 1, 2),
        speakerModel: 'Speaker B',
        outputLevelDbfs: -20,
        signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
        sampleRate: 44100,
        frequencyResponse: const FrequencyResponse([
          FrequencyResponsePoint(1000, -2.0),
          FrequencyResponsePoint(2000, -3.0),
        ]),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ComparisonController(measurementDao: dao),
        child: const MaterialApp(home: ComparisonScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speaker A'), findsOneWidget);
    expect(find.text('Speaker B'), findsOneWidget);
    expect(find.text('Sélectionne au moins une mesure.'), findsOneWidget);

    await tester.tap(find.text('Speaker A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speaker B'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Delta vs.'), findsOneWidget);
  });
}
