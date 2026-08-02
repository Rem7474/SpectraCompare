import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';
import 'package:spectra_compare/core/models/measurement.dart';
import 'package:spectra_compare/core/models/signal_config.dart';
import 'package:spectra_compare/core/storage/database.dart';
import 'package:spectra_compare/features/library/library_controller.dart';
import 'package:spectra_compare/features/library/library_screen.dart';
import 'package:spectra_compare/features/library/measurement_detail_screen.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets('shows an empty state with no measurements', (tester) async {
    final appDb = testAppDatabase();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LibraryController(measurementDao: MeasurementDao(appDb)),
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.text('Aucune mesure enregistrée.'), findsOneWidget);
  });

  testWidgets('lists a saved measurement and opens its detail screen on tap', (tester) async {
    final appDb = testAppDatabase();
    final dao = MeasurementDao(appDb);
    await dao.insert(
      Measurement(
        createdAt: DateTime(2026, 1, 1),
        speakerModel: 'Test Speaker',
        outputLevelDbfs: -20,
        signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
        sampleRate: 44100,
        frequencyResponse: const FrequencyResponse([FrequencyResponsePoint(1000, -1.0)]),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LibraryController(measurementDao: dao),
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Speaker'), findsOneWidget);

    await tester.tap(find.text('Test Speaker'));
    await tester.pumpAndSettle();

    expect(find.byType(MeasurementDetailScreen), findsOneWidget);
  });
}
