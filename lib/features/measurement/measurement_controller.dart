import 'package:flutter/foundation.dart';

import '../../core/audio/measurement_session.dart';
import '../../core/audio/player_service.dart';
import '../../core/audio/recorder_service.dart';
import '../../core/audio/signal_generator.dart';
import '../../core/dsp/deconvolution.dart';
import '../../core/dsp/fft_utils.dart';
import '../../core/dsp/octave_bands.dart';
import '../../core/dsp/welch.dart';
import '../../core/models/calibration_curve.dart';
import '../../core/models/frequency_response.dart';
import '../../core/models/measurement.dart';
import '../../core/models/signal_config.dart';
import '../../core/storage/database.dart';

enum MeasurementStatus {
  idle,
  permissionDenied,
  measuring,
  analyzing,
  done,
  error,
}

/// Drives the "lancer une mesure" flow (README "Utilisation"): runs a
/// `MeasurementSession`, extracts a frequency response appropriate to the
/// signal type, applies an optional mic calibration curve, and can persist
/// the result to the measurement library.
class MeasurementController extends ChangeNotifier {
  final MeasurementDao measurementDao;
  final int sampleRate;

  MeasurementController({
    required this.measurementDao,
    this.sampleRate = 44100,
  });

  MeasurementStatus status = MeasurementStatus.idle;
  String? errorMessage;
  MeasurementResult? lastResult;
  FrequencyResponse? lastFrequencyResponse;
  CalibrationCurve? calibrationCurve;
  SignalConfig? _lastSignalConfig;

  RecorderService? _recorderService;
  PlayerService? _playerService;

  void setCalibrationCurve(CalibrationCurve? curve) {
    calibrationCurve = curve;
    notifyListeners();
  }

  Future<void> runMeasurement(SignalConfig signalConfig) async {
    errorMessage = null;
    lastResult = null;
    lastFrequencyResponse = null;
    _lastSignalConfig = signalConfig;

    final recorder = _recorderService ??= RecorderService();
    final player = _playerService ??= PlayerService();

    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      status = MeasurementStatus.permissionDenied;
      notifyListeners();
      return;
    }

    status = MeasurementStatus.measuring;
    notifyListeners();

    try {
      final session = MeasurementSession(
        recorder: recorder,
        player: player,
        sampleRate: sampleRate,
      );
      final result = await session.run(signalConfig);
      lastResult = result;

      status = MeasurementStatus.analyzing;
      notifyListeners();

      var response = _analyze(signalConfig, result);
      final curve = calibrationCurve;
      if (curve != null) {
        response = response.withCorrection(curve.correctionAt);
      }
      lastFrequencyResponse = OctaveBands.resample(response);
      status = MeasurementStatus.done;
    } catch (e) {
      errorMessage = e.toString();
      status = MeasurementStatus.error;
    }
    notifyListeners();
  }

  FrequencyResponse _analyze(SignalConfig config, MeasurementResult result) {
    switch (config.type) {
      case SignalType.sineSweepLog:
      case SignalType.sineSweepLinear:
        // Deconvolution (ESS/Farina method) needs the exponential sweep law;
        // linear sweeps fall back to a plain windowed FFT of the segment.
        if (config.type == SignalType.sineSweepLog) {
          final referenceSweep = SignalGenerator.generate(config, sampleRate);
          final deconvolver = ExponentialSweepDeconvolver(
            f0: config.startFreqHz,
            f1: config.endFreqHz,
            durationS: config.durationS,
            sampleRate: sampleRate,
          );
          return deconvolver.frequencyResponseFrom(
            result.mainSignalSegment,
            referenceSweep,
          );
        }
        return _singleFft(result.mainSignalSegment);
      case SignalType.pinkNoise:
      case SignalType.whiteNoise:
        return Welch.averagedSpectrum(result.mainSignalSegment, sampleRate);
      case SignalType.burst:
      case SignalType.pureTone:
        return _singleFft(result.mainSignalSegment);
    }
  }

  FrequencyResponse _singleFft(List<double> segment) {
    if (segment.isEmpty) return const FrequencyResponse([]);
    final spectrum = FftUtils.magnitudeSpectrum(segment, sampleRate);
    return FrequencyResponse([
      for (int i = 0; i < spectrum.freqsHz.length; i++)
        FrequencyResponsePoint(spectrum.freqsHz[i], spectrum.magnitudesDb[i]),
    ]);
  }

  Future<int?> saveToLibrary({
    String? speakerModel,
    String? position,
    double? distanceM,
    List<String> tags = const [],
    String? notes,
  }) async {
    final result = lastResult;
    final response = lastFrequencyResponse;
    final config = _lastSignalConfig;
    if (result == null || response == null || config == null) return null;

    final measurement = Measurement(
      createdAt: DateTime.now(),
      speakerModel: speakerModel,
      position: position,
      distanceM: distanceM,
      outputLevelDbfs: config.levelDbfs,
      signalConfig: config,
      sampleRate: sampleRate,
      offsetSamples: result.offsetSamples,
      correlationConfidence: result.confidence,
      frequencyResponse: response,
      calibrationCurveId: calibrationCurve?.id,
      tags: tags,
      notes: notes,
    );
    return measurementDao.insert(measurement);
  }

  void reset() {
    status = MeasurementStatus.idle;
    errorMessage = null;
    lastResult = null;
    lastFrequencyResponse = null;
    notifyListeners();
  }
}
