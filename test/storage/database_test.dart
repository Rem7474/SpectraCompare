import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spectra_compare/core/models/calibration_curve.dart';
import 'package:spectra_compare/core/models/frequency_response.dart';
import 'package:spectra_compare/core/models/measurement.dart';
import 'package:spectra_compare/core/models/signal_config.dart';
import 'package:spectra_compare/core/storage/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDb;

  setUp(() {
    // In-memory DB, unique per test via a fresh AppDatabase instance.
    appDb = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await appDb.close();
  });

  Measurement sampleMeasurement({String speakerModel = 'JBL 305P'}) =>
      Measurement(
        createdAt: DateTime.utc(2026, 1, 1),
        speakerModel: speakerModel,
        position: 'axe, 1m',
        distanceM: 1.0,
        outputLevelDbfs: -20,
        signalConfig: SignalConfig.fromJson(const {
          'type': 'sineSweepLog',
          'startFreqHz': 20.0,
          'endFreqHz': 20000.0,
          'frequencyHz': 1000.0,
          'durationS': 10.0,
          'levelDbfs': -20.0,
        }),
        sampleRate: 44100,
        offsetSamples: 1234,
        correlationConfidence: 0.95,
        rawWavPath: '/tmp/rec.wav',
        frequencyResponse: const FrequencyResponse([
          FrequencyResponsePoint(100, -3.0),
          FrequencyResponsePoint(1000, 0.0),
          FrequencyResponsePoint(10000, -6.0),
        ]),
        tags: const ['bookshelf', 'nearfield'],
        notes: 'test note',
      );

  group('MeasurementDao', () {
    test('insert then getById round-trips all fields', () async {
      final dao = MeasurementDao(appDb);
      final id = await dao.insert(sampleMeasurement());
      final loaded = await dao.getById(id);

      expect(loaded, isNotNull);
      expect(loaded!.speakerModel, 'JBL 305P');
      expect(loaded.position, 'axe, 1m');
      expect(loaded.distanceM, 1.0);
      expect(loaded.outputLevelDbfs, -20);
      expect(loaded.signalConfig.type.name, 'sineSweepLog');
      expect(loaded.sampleRate, 44100);
      expect(loaded.offsetSamples, 1234);
      expect(loaded.correlationConfidence, 0.95);
      expect(loaded.rawWavPath, '/tmp/rec.wav');
      expect(loaded.frequencyResponse.points.length, 3);
      expect(loaded.frequencyResponse.points[1].magnitudeDb, 0.0);
      expect(loaded.tags, ['bookshelf', 'nearfield']);
      expect(loaded.notes, 'test note');
    });

    test('getAll returns measurements ordered by created_at desc', () async {
      final dao = MeasurementDao(appDb);
      await dao.insert(sampleMeasurement(speakerModel: 'Old').copyWith());
      final newer = Measurement(
        createdAt: DateTime.utc(2026, 6, 1),
        outputLevelDbfs: -20,
        signalConfig: sampleMeasurement().signalConfig,
        sampleRate: 44100,
        frequencyResponse: const FrequencyResponse([]),
        speakerModel: 'New',
      );
      await dao.insert(newer);

      final all = await dao.getAll();
      expect(all.length, 2);
      expect(all.first.speakerModel, 'New');
    });

    test('update modifies an existing row', () async {
      final dao = MeasurementDao(appDb);
      final id = await dao.insert(sampleMeasurement());
      final loaded = (await dao.getById(id))!;
      await dao.update(loaded.copyWith(id: id));

      // Update with a changed frequency response.
      final changed = loaded.copyWith(
        id: id,
        frequencyResponse: const FrequencyResponse([
          FrequencyResponsePoint(500, -1.0),
        ]),
      );
      await dao.update(changed);

      final reloaded = await dao.getById(id);
      expect(reloaded!.frequencyResponse.points.length, 1);
      expect(reloaded.frequencyResponse.points.first.freqHz, 500);
    });

    test('delete removes the row', () async {
      final dao = MeasurementDao(appDb);
      final id = await dao.insert(sampleMeasurement());
      await dao.delete(id);
      expect(await dao.getById(id), isNull);
    });
  });

  group('CalibrationCurveDao', () {
    test('insert then getById round-trips points', () async {
      final dao = CalibrationCurveDao(appDb);
      const curve = CalibrationCurve(
        name: 'UMIK-1',
        points: [
          CalibrationPoint(20, 1.5),
          CalibrationPoint(1000, 0.0),
          CalibrationPoint(20000, -2.3),
        ],
      );
      final id = await dao.insert(curve, sourceFilename: 'umik1.txt');
      final loaded = await dao.getById(id);

      expect(loaded, isNotNull);
      expect(loaded!.name, 'UMIK-1');
      expect(loaded.points.length, 3);
      expect(loaded.points[2].correctionDb, -2.3);
    });

    test('getAll and delete', () async {
      final dao = CalibrationCurveDao(appDb);
      const curve = CalibrationCurve(
        name: 'A',
        points: [CalibrationPoint(1000, 0.0)],
      );
      final id = await dao.insert(curve);
      expect((await dao.getAll()).length, 1);
      await dao.delete(id);
      expect((await dao.getAll()), isEmpty);
    });
  });
}
