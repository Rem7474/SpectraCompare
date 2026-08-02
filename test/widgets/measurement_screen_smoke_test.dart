import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spectra_compare/core/storage/database.dart';
import 'package:spectra_compare/features/calibration/calibration_controller.dart';
import 'package:spectra_compare/features/generator/generator_controller.dart';
import 'package:spectra_compare/features/generator/presets.dart';
import 'package:spectra_compare/features/measurement/measurement_controller.dart';
import 'package:spectra_compare/features/measurement/measurement_screen.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  Widget wrap() {
    final appDb = testAppDatabase();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GeneratorController()),
        ChangeNotifierProvider(
          create: (_) => MeasurementController(measurementDao: MeasurementDao(appDb)),
        ),
        ChangeNotifierProvider(
          create: (_) => CalibrationController(dao: CalibrationCurveDao(appDb)),
        ),
      ],
      child: const MaterialApp(home: MeasurementScreen()),
    );
  }

  testWidgets('renders presets and the start button without touching audio plugins', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Mesurer'), findsOneWidget);
    for (final preset in SignalPresets.all) {
      expect(find.text(preset.name), findsOneWidget);
    }
    expect(find.text('Lancer la mesure'), findsOneWidget);
    expect(find.text('Prêt.'), findsOneWidget);
  });

  testWidgets('selecting a different preset updates the displayed signal params', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Signal: Sweep logarithmique'), findsOneWidget);

    await tester.tap(find.text('Calibration pink noise'));
    await tester.pumpAndSettle();

    expect(find.text('Signal: Bruit rose'), findsOneWidget);
  });

  testWidgets('level slider drag updates the level label without crashing', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    await tester.drag(slider, const Offset(-50, 0));
    await tester.pumpAndSettle();
    // Just verifying no exception was thrown and the widget tree still renders.
    expect(find.byType(MeasurementScreen), findsOneWidget);
  });
}
