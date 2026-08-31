import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:spectra_compare/core/dsp/fft_utils.dart';
import 'package:spectra_compare/core/models/calibration_curve.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';
import 'package:spectra_compare/core/models/measurement.dart';
import 'package:spectra_compare/core/models/signal_config.dart';
import 'package:spectra_compare/core/storage/database.dart';
import 'package:spectra_compare/features/analyzer/analyzer_controller.dart';
import 'package:spectra_compare/features/analyzer/analyzer_screen.dart';
import 'package:spectra_compare/features/calibration/calibration_controller.dart';
import 'package:spectra_compare/features/calibration/calibration_screen.dart';
import 'package:spectra_compare/features/comparison/comparison_controller.dart';
import 'package:spectra_compare/features/comparison/comparison_screen.dart';
import 'package:spectra_compare/features/generator/generator_controller.dart';
import 'package:spectra_compare/features/library/library_controller.dart';
import 'package:spectra_compare/features/library/library_screen.dart';
import 'package:spectra_compare/features/measurement/measurement_controller.dart';
import 'package:spectra_compare/features/measurement/measurement_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'widgets/test_helpers.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await loadAppFonts();
  });

  Widget wrapScreen(Widget child, {int tabIndex = 0}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.graphic_eq),
              label: 'Mesurer',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart),
              label: 'Analyseur',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              label: 'Bibliothèque',
            ),
            NavigationDestination(
              icon: Icon(Icons.compare_arrows),
              label: 'Comparaison',
            ),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Calibration'),
          ],
        ),
      ),
    );
  }

  FrequencyResponse generateMockResponse({
    double bassBoost = 3.0,
    double trebleRollOff = -4.0,
    double dipFreq = 3000,
    double dipDepth = -6.0,
  }) {
    final points = <FrequencyResponsePoint>[];
    const numPoints = 120;
    final logMin = math.log(20);
    final logMax = math.log(20000);

    for (int i = 0; i < numPoints; i++) {
      final f = math.exp(logMin + (logMax - logMin) * i / (numPoints - 1));
      double mag = 0.0;
      if (f < 80) {
        mag += bassBoost - (80 - f) * 0.15;
      } else if (f < 200) {
        mag += bassBoost * (1.0 - (f - 80) / 120);
      }
      mag += 1.5 * math.sin(f / 300.0);
      final dipDist = (math.log(f) - math.log(dipFreq)).abs();
      if (dipDist < 0.5) {
        mag += dipDepth * (1.0 - dipDist / 0.5);
      }
      if (f > 10000) {
        mag += trebleRollOff * ((f - 10000) / 10000);
      }
      points.add(FrequencyResponsePoint(f, mag));
    }
    return FrequencyResponse(points);
  }

  testWidgets('Generate Screenshot - 01_Mesure.png', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = testAppDatabase();
    final mDao = MeasurementDao(db);
    final cDao = CalibrationCurveDao(db);

    final genCtrl = GeneratorController();
    final measCtrl = MeasurementController(measurementDao: mDao);
    final calCtrl = CalibrationController(dao: cDao);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: genCtrl),
          ChangeNotifierProvider.value(value: measCtrl),
          ChangeNotifierProvider.value(value: calCtrl),
        ],
        child: wrapScreen(const MeasurementScreen(), tabIndex: 0),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshot/01_Mesure.png'),
    );
  });

  testWidgets('Generate Screenshot - 02_Analyseur.png', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockRecorder = MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});

    final analyzer = AnalyzerController(recorder: mockRecorder);
    analyzer.isRunning = true;

    final freqs = Float64List(256);
    final liveMags = Float64List(256);
    final peakMags = Float64List(256);

    for (int i = 0; i < 256; i++) {
      final f = 20.0 + (20000.0 - 20.0) * i / 255.0;
      freqs[i] = f;
      final base = -45.0 + 15.0 * math.sin(i / 15.0) - (i / 10.0);
      liveMags[i] = base + 5.0 * math.cos(i / 5.0);
      peakMags[i] = liveMags[i] + 6.0;
    }

    analyzer.latestSpectrum = Spectrum(freqs, liveMags);
    analyzer.peakHoldSpectrum = Spectrum(freqs, peakMags);

    for (int c = 0; c < 60; c++) {
      final col = Float64List(80);
      for (int r = 0; r < 80; r++) {
        col[r] = -60.0 + (r * 0.5) + 10.0 * math.sin((c + r) / 8.0);
      }
      analyzer.spectrogramColumns.add(col);
    }

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: analyzer,
        child: wrapScreen(const AnalyzerScreen(), tabIndex: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshot/02_Analyseur.png'),
    );
  });

  testWidgets('Generate Screenshot - 03_Comparaison.png', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = testAppDatabase();
    final mDao = MeasurementDao(db);

    final m1 = Measurement(
      createdAt: DateTime(2026, 8, 28, 14, 30),
      speakerModel: 'Yamaha HS5 (Nearfield)',
      position: 'Bureau gauche 1m',
      distanceM: 1.0,
      outputLevelDbfs: -20,
      signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
      sampleRate: 44100,
      frequencyResponse: generateMockResponse(
        bassBoost: 1.0,
        trebleRollOff: -2.0,
        dipFreq: 2500,
        dipDepth: -4.0,
      ),
      tags: ['Studio', 'HS5', 'Bureau'],
    );

    final m2 = Measurement(
      createdAt: DateTime(2026, 8, 29, 10, 15),
      speakerModel: 'Focal Alpha 65 Evo',
      position: 'Salon canapé 2.5m',
      distanceM: 2.5,
      outputLevelDbfs: -20,
      signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
      sampleRate: 44100,
      frequencyResponse: generateMockResponse(
        bassBoost: 5.5,
        trebleRollOff: -1.0,
        dipFreq: 4000,
        dipDepth: -2.5,
      ),
      tags: ['Salon', 'Focal', 'Alpha65'],
    );

    final id1 = await mDao.insert(m1);
    final id2 = await mDao.insert(m2);

    final compCtrl = ComparisonController(measurementDao: mDao);
    await compCtrl.load();
    compCtrl.toggleSelected(id1);
    compCtrl.toggleSelected(id2);
    compCtrl.setReference(id1);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: compCtrl,
        child: wrapScreen(const ComparisonScreen(), tabIndex: 3),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshot/03_Comparaison.png'),
    );
  });

  testWidgets('Generate Screenshot - 04_Bibliotheque.png', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = testAppDatabase();
    final mDao = MeasurementDao(db);

    await mDao.insert(
      Measurement(
        createdAt: DateTime(2026, 8, 30, 16, 45),
        speakerModel: 'Yamaha HS5 (Nearfield)',
        position: 'Bureau gauche 1m',
        distanceM: 1.0,
        outputLevelDbfs: -20,
        signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
        sampleRate: 44100,
        frequencyResponse: generateMockResponse(),
        tags: ['Studio', 'Reference'],
      ),
    );

    await mDao.insert(
      Measurement(
        createdAt: DateTime(2026, 8, 29, 14, 20),
        speakerModel: 'Focal Alpha 65 Evo',
        position: 'Salon canapé 2.5m',
        distanceM: 2.5,
        outputLevelDbfs: -18,
        signalConfig: const SignalConfig(type: SignalType.sineSweepLog),
        sampleRate: 44100,
        frequencyResponse: generateMockResponse(bassBoost: 6.0),
        tags: ['Salon', 'Focal'],
      ),
    );

    await mDao.insert(
      Measurement(
        createdAt: DateTime(2026, 8, 27, 19, 10),
        speakerModel: 'JBL Flip 6 (Nomade)',
        position: 'Extérieur terrasse',
        distanceM: 1.5,
        outputLevelDbfs: -20,
        signalConfig: const SignalConfig(type: SignalType.pinkNoise),
        sampleRate: 44100,
        frequencyResponse: generateMockResponse(
          bassBoost: -3.0,
          trebleRollOff: -8.0,
        ),
        tags: ['Nomade', 'Bluetooth'],
      ),
    );

    final libCtrl = LibraryController(measurementDao: mDao);
    await libCtrl.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: libCtrl,
        child: wrapScreen(const LibraryScreen(), tabIndex: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshot/04_Bibliotheque.png'),
    );
  });

  testWidgets('Generate Screenshot - 05_Calibration.png', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = testAppDatabase();
    final cDao = CalibrationCurveDao(db);

    await cDao.insert(
      const CalibrationCurve(
        name: 'miniDSP UMIK-1 (90deg calibration)',
        points: [
          CalibrationPoint(20, -1.2),
          CalibrationPoint(100, -0.4),
          CalibrationPoint(1000, 0.0),
          CalibrationPoint(10000, 0.8),
          CalibrationPoint(20000, -2.1),
        ],
      ),
    );

    final calCtrl = CalibrationController(dao: cDao);
    await calCtrl.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: calCtrl,
        child: wrapScreen(const CalibrationScreen(), tabIndex: 4),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshot/05_Calibration.png'),
    );
  });
}
