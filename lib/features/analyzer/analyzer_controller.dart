import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart' as rec;

import '../../core/audio/pcm_ring_buffer.dart';
import '../../core/dsp/fft_utils.dart';

/// Drives the live FFT spectrum + spectrogram view (README "Analyse FFT
/// temps réel" / "Spectrogramme"). Independent from `MeasurementSession` —
/// this is just a live listen/analyze loop, no playback or chirp sync.
class AnalyzerController extends ChangeNotifier {
  final rec.AudioRecorder _recorder;
  final int sampleRate;
  final int frameSize;
  final int spectrogramHistory;
  final int spectrogramBands;

  AnalyzerController({
    rec.AudioRecorder? recorder,
    this.sampleRate = 44100,
    this.frameSize = 2048,
    this.spectrogramHistory = 120,
    this.spectrogramBands = 80,
  }) : _recorder = recorder ?? rec.AudioRecorder();

  StreamSubscription<Uint8List>? _sub;
  PcmRingBuffer? _ringBuffer;
  late final List<double> _spectrogramFreqs = _logSpacedFreqs(20, 20000, spectrogramBands);

  bool isRunning = false;
  Spectrum? latestSpectrum;
  final List<Float64List> spectrogramColumns = [];

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (isRunning) return;
    final granted = await _recorder.hasPermission();
    if (!granted) return;

    _ringBuffer = PcmRingBuffer(frameSize: frameSize, hopSize: frameSize ~/ 2);
    final stream = await _recorder.startStream(
      rec.RecordConfig(encoder: rec.AudioEncoder.pcm16bits, sampleRate: sampleRate, numChannels: 1),
    );
    isRunning = true;
    notifyListeners();
    _sub = stream.listen(_onData);
  }

  void _onData(Uint8List bytes) {
    final ring = _ringBuffer;
    if (ring == null) return;
    final frames = ring.addBytes(bytes);
    for (final frame in frames) {
      final spectrum = FftUtils.magnitudeSpectrum(frame, sampleRate);
      latestSpectrum = spectrum;
      spectrogramColumns.add(_downsampleLog(spectrum));
      if (spectrogramColumns.length > spectrogramHistory) {
        spectrogramColumns.removeAt(0);
      }
    }
    if (frames.isNotEmpty) notifyListeners();
  }

  Float64List _downsampleLog(Spectrum spectrum) {
    final out = Float64List(_spectrogramFreqs.length);
    for (int i = 0; i < _spectrogramFreqs.length; i++) {
      out[i] = _nearestDb(spectrum, _spectrogramFreqs[i]);
    }
    return out;
  }

  double _nearestDb(Spectrum spectrum, double freq) {
    int lo = 0, hi = spectrum.freqsHz.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (spectrum.freqsHz[mid] < freq) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return spectrum.magnitudesDb[lo];
  }

  static List<double> _logSpacedFreqs(double f0, double f1, int count) {
    final logF0 = math.log(f0), logF1 = math.log(f1);
    return List.generate(count, (i) => math.exp(logF0 + (logF1 - logF0) * i / (count - 1)));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
