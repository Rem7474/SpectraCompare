import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/storage/database.dart';
import 'features/analyzer/analyzer_controller.dart';
import 'features/analyzer/analyzer_screen.dart';
import 'features/calibration/calibration_controller.dart';
import 'features/calibration/calibration_screen.dart';
import 'features/comparison/comparison_controller.dart';
import 'features/comparison/comparison_screen.dart';
import 'features/generator/generator_controller.dart';
import 'features/library/library_controller.dart';
import 'features/library/library_screen.dart';
import 'features/measurement/measurement_controller.dart';
import 'features/measurement/measurement_screen.dart';

class SpectraCompareApp extends StatelessWidget {
  final AppDatabase appDatabase;

  const SpectraCompareApp({super.key, required this.appDatabase});

  @override
  Widget build(BuildContext context) {
    final measurementDao = MeasurementDao(appDatabase);
    final calibrationCurveDao = CalibrationCurveDao(appDatabase);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GeneratorController()),
        ChangeNotifierProvider(create: (_) => MeasurementController(measurementDao: measurementDao)),
        ChangeNotifierProvider(create: (_) => AnalyzerController()),
        ChangeNotifierProvider(create: (_) => LibraryController(measurementDao: measurementDao)),
        ChangeNotifierProvider(create: (_) => ComparisonController(measurementDao: measurementDao)),
        ChangeNotifierProvider(create: (_) => CalibrationController(dao: calibrationCurveDao)),
      ],
      child: MaterialApp(
        title: 'SpectraCompare',
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    MeasurementScreen(),
    AnalyzerScreen(),
    LibraryScreen(),
    ComparisonScreen(),
    CalibrationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.graphic_eq), label: 'Mesurer'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Analyseur'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Bibliothèque'),
          NavigationDestination(icon: Icon(Icons.compare_arrows), label: 'Comparaison'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Calibration'),
        ],
      ),
    );
  }
}
