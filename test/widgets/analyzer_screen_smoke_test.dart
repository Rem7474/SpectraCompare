import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spectra_compare/features/analyzer/analyzer_controller.dart';
import 'package:spectra_compare/features/analyzer/analyzer_screen.dart';

void main() {
  testWidgets(
    'AnalyzerScreen renders spectrum, spectrogram and mic toggle without starting the mic',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AnalyzerController(),
          child: const MaterialApp(home: AnalyzerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analyseur'), findsOneWidget);
      expect(find.text('Spectre 20Hz–20kHz'), findsOneWidget);
      expect(find.text('Spectrogramme'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(
        find.text('Appuie sur le micro pour démarrer l\'analyse en direct.'),
        findsOneWidget,
      );
    },
  );
}
