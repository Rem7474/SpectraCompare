import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spectra_compare/core/storage/database.dart';
import 'package:spectra_compare/features/calibration/calibration_controller.dart';
import 'package:spectra_compare/features/calibration/calibration_screen.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets('renders the "no calibration" option and an import button', (
    tester,
  ) async {
    final appDb = testAppDatabase();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CalibrationController(dao: CalibrationCurveDao(appDb)),
        child: const MaterialApp(home: CalibrationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calibration micro'), findsOneWidget);
    expect(
      find.text('Aucune (mesures relatives, non calibrées)'),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('importing valid pasted calibration text adds it to the list', (
    tester,
  ) async {
    final appDb = testAppDatabase();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CalibrationController(dao: CalibrationCurveDao(appDb)),
        child: const MaterialApp(home: CalibrationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Two text fields in the import dialog: name (index 0) and pasted
    // calibration contents (index 1).
    await tester.enterText(
      find.byType(TextField).at(1),
      '20 1.0\n1000 0.0\n20000 -2.0\n',
    );
    await tester.tap(find.text('Importer'));
    await tester.pumpAndSettle();

    expect(find.text('Ma calibration'), findsOneWidget);
    expect(find.text('3 points'), findsOneWidget);
  });
}
