import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;

import 'measurement_session.dart' show Recorder;
import 'wav_codec.dart';

/// Thin adapter over the `record` plugin. Kept nearly logic-free (the
/// orchestration logic lives in `MeasurementSession`), since this class
/// touches real platform audio I/O and can't be exercised without a device —
/// see plan's sandbox verification limits.
class RecorderService implements Recorder {
  final rec.AudioRecorder _recorder;
  String? _currentPath;

  RecorderService({rec.AudioRecorder? recorder})
    : _recorder = recorder ?? rec.AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start({required int sampleRate}) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/spectracompare_rec_${DateTime.now().microsecondsSinceEpoch}.wav';
    _currentPath = path;
    await _recorder.start(
      rec.RecordConfig(
        encoder: rec.AudioEncoder.wav,
        sampleRate: sampleRate,
        numChannels: 1,
        // Prefer an unprocessed source where available: default mic sources
        // can silently apply AGC/noise-suppression/echo-cancellation, which
        // would corrupt frequency-response measurements.
        androidConfig: const rec.AndroidRecordConfig(
          audioSource: rec.AndroidAudioSource.unprocessed,
        ),
        echoCancel: false,
        noiseSuppress: false,
        autoGain: false,
      ),
      path: path,
    );
  }

  @override
  Future<WavData> stop() async {
    final path = await _recorder.stop() ?? _currentPath;
    if (path == null) {
      throw StateError('RecorderService.stop() called without a prior start()');
    }
    final bytes = await File(path).readAsBytes();
    return WavDecoder.decode(Uint8List.fromList(bytes));
  }

  Future<void> dispose() => _recorder.dispose();
}
