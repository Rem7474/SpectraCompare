import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spectra_compare/app.dart';
import 'package:spectra_compare/core/storage/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  testWidgets('SpectraCompareApp boots to the Measurer tab and can navigate to all others', (tester) async {
    final appDb = AppDatabase(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    await tester.pumpWidget(SpectraCompareApp(appDatabase: appDb));
    await tester.pumpAndSettle();

    expect(find.text('Mesurer'), findsWidgets);

    for (final label in ['Analyseur', 'Bibliothèque', 'Comparaison', 'Calibration']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsWidgets);
    }
  });
}
