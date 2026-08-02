import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/audio/audio_session_setup.dart';
import 'core/storage/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioSessionSetup.configure();

  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'spectra_compare.db');
  final appDatabase = AppDatabase(factory: databaseFactory, path: dbPath);

  runApp(SpectraCompareApp(appDatabase: appDatabase));
}
