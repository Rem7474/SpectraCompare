import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/calibration_curve.dart';
import '../models/frequency_response.dart';
import '../models/measurement.dart';
import '../models/signal_config.dart';

/// Opens (and owns) the app's sqlite database. Pass a `databaseFactoryFfi`
/// in tests (host-runnable, no device needed) and the default mobile
/// `databaseFactory` in the real app.
class AppDatabase {
  final DatabaseFactory factory;
  final String path;
  Database? _db;

  AppDatabase({required this.factory, required this.path});

  Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE measurements (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              created_at TEXT NOT NULL,
              speaker_model TEXT,
              position TEXT,
              distance_m REAL,
              output_level_dbfs REAL,
              signal_type TEXT NOT NULL,
              signal_params_json TEXT NOT NULL,
              sample_rate INTEGER NOT NULL,
              offset_samples INTEGER,
              correlation_confidence REAL,
              raw_wav_path TEXT,
              frequency_response_json TEXT,
              calibration_curve_id INTEGER REFERENCES calibration_curves(id),
              tags_json TEXT,
              notes TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE calibration_curves (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              created_at TEXT,
              source_filename TEXT,
              points_json TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    _db = db;
    return db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class MeasurementDao {
  final AppDatabase appDb;

  const MeasurementDao(this.appDb);

  Future<int> insert(Measurement m) async {
    final db = await appDb.open();
    return db.insert('measurements', _toRow(m));
  }

  Future<void> update(Measurement m) async {
    assert(m.id != null, 'Cannot update a Measurement without an id');
    final db = await appDb.open();
    await db.update('measurements', _toRow(m), where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> delete(int id) async {
    final db = await appDb.open();
    await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }

  Future<Measurement?> getById(int id) async {
    final db = await appDb.open();
    final rows = await db.query('measurements', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<Measurement>> getAll() async {
    final db = await appDb.open();
    final rows = await db.query('measurements', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  Map<String, Object?> _toRow(Measurement m) => {
        if (m.id != null) 'id': m.id,
        'created_at': m.createdAt.toIso8601String(),
        'speaker_model': m.speakerModel,
        'position': m.position,
        'distance_m': m.distanceM,
        'output_level_dbfs': m.outputLevelDbfs,
        'signal_type': m.signalConfig.type.name,
        'signal_params_json': jsonEncode(m.signalConfig.toJson()),
        'sample_rate': m.sampleRate,
        'offset_samples': m.offsetSamples,
        'correlation_confidence': m.correlationConfidence,
        'raw_wav_path': m.rawWavPath,
        'frequency_response_json': jsonEncode(m.frequencyResponse.toJsonList()),
        'calibration_curve_id': m.calibrationCurveId,
        'tags_json': jsonEncode(m.tags),
        'notes': m.notes,
      };

  Measurement _fromRow(Map<String, Object?> row) => Measurement(
        id: row['id'] as int?,
        createdAt: DateTime.parse(row['created_at'] as String),
        speakerModel: row['speaker_model'] as String?,
        position: row['position'] as String?,
        distanceM: (row['distance_m'] as num?)?.toDouble(),
        outputLevelDbfs: (row['output_level_dbfs'] as num?)?.toDouble() ?? 0,
        signalConfig: SignalConfig.fromJson(
          jsonDecode(row['signal_params_json'] as String) as Map<String, dynamic>,
        ),
        sampleRate: row['sample_rate'] as int,
        offsetSamples: row['offset_samples'] as int?,
        correlationConfidence: (row['correlation_confidence'] as num?)?.toDouble(),
        rawWavPath: row['raw_wav_path'] as String?,
        frequencyResponse: FrequencyResponse.fromJsonList(
          jsonDecode(row['frequency_response_json'] as String? ?? '[]') as List<dynamic>,
        ),
        calibrationCurveId: row['calibration_curve_id'] as int?,
        tags: List<String>.from(jsonDecode(row['tags_json'] as String? ?? '[]') as List<dynamic>),
        notes: row['notes'] as String?,
      );
}

class CalibrationCurveDao {
  final AppDatabase appDb;

  const CalibrationCurveDao(this.appDb);

  Future<int> insert(CalibrationCurve c, {String? sourceFilename}) async {
    final db = await appDb.open();
    return db.insert('calibration_curves', {
      'name': c.name,
      'created_at': DateTime.now().toIso8601String(),
      'source_filename': sourceFilename,
      'points_json': jsonEncode(c.points.map((p) => [p.freqHz, p.correctionDb]).toList()),
    });
  }

  Future<void> delete(int id) async {
    final db = await appDb.open();
    await db.delete('calibration_curves', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CalibrationCurve>> getAll() async {
    final db = await appDb.open();
    final rows = await db.query('calibration_curves', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<CalibrationCurve?> getById(int id) async {
    final db = await appDb.open();
    final rows = await db.query('calibration_curves', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  CalibrationCurve _fromRow(Map<String, Object?> row) {
    final raw = jsonDecode(row['points_json'] as String) as List<dynamic>;
    return CalibrationCurve(
      id: row['id'] as int?,
      name: row['name'] as String? ?? '',
      points: raw
          .map((e) => CalibrationPoint((e[0] as num).toDouble(), (e[1] as num).toDouble()))
          .toList(),
    );
  }
}
