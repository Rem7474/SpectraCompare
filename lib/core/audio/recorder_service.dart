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

    // List of candidate audio sources in order of preference for acoustic
    // measurement:
    // 1. `unprocessed` (API 24+): raw mic input without AEC, AGC, or noise
    //    suppression DSP filters.
    // 2. `camcorder`: tuned for environmental audio without telephony AEC.
    // 3. `mic`: universal fallback if hardware rejects unprocessed.
    const candidateSources = [
      rec.AndroidAudioSource.unprocessed,
      rec.AndroidAudioSource.camcorder,
      rec.AndroidAudioSource.mic,
    ];

    Object? lastError;
    for (final source in candidateSources) {
      try {
        await _recorder.start(
          rec.RecordConfig(
            encoder: rec.AudioEncoder.wav,
            sampleRate: sampleRate,
            numChannels: 1,
            androidConfig: rec.AndroidRecordConfig(
              audioSource: source,
              manageBluetooth: false,
            ),
            iosConfig: const rec.IosRecordConfig(
              categoryOptions: [
                rec.IosAudioCategoryOption.defaultToSpeaker,
                rec.IosAudioCategoryOption.allowBluetoothA2DP,
              ],
            ),
            echoCancel: false,
            noiseSuppress: false,
            autoGain: false,
          ),
          path: path,
        );
        return;
      } catch (e) {
        lastError = e;
        // Try next fallback audio source if start failed.
        continue;
      }
    }

    if (lastError != null) {
      throw StateError('Failed to start recorder on any audio source: $lastError');
    }
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
