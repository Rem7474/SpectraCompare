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
        androidConfig: const rec.AndroidRecordConfig(
          // `unprocessed` (AudioSource.UNPROCESSED, API 24+) is only
          // guaranteed to exist on devices declaring FEATURE_AUDIO_PRO;
          // on unsupported hardware it can silently capture near-total
          // silence instead of throwing. `mic` is universally supported and,
          // combined with the echoCancel/noiseSuppress/autoGain flags below
          // (applied via AudioEffect independently of the source), gives the
          // same "don't process the signal" intent far more reliably.
          audioSource: rec.AndroidAudioSource.mic,
          // `record` defaults this to true, which makes it actively try to
          // open a Bluetooth SCO connection for the mic input whenever one
          // is available. SCO routes capture through the *Bluetooth
          // device's* mic (meant for call headsets) instead of the phone's
          // own mic, and fights with the A2DP route `just_audio` is using
          // for playback. We always want the phone's own mic, regardless of
          // where playback is routed.
          manageBluetooth: false,
          // The live Analyzer tab (record-only, no concurrent playback)
          // captures fine on the reported device, but a measurement — which
          // records *while* just_audio is simultaneously playing — captures
          // near-total silence. `record` and `just_audio` each manage the
          // native audio session independently; `modeInCommunication` is
          // the plugin's documented knob for concurrent record+playback
          // AEC/routing issues on affected devices. Trade-off: some devices
          // apply telephony-style (narrowband) processing in this mode,
          // which could clip the measured bandwidth — worth revisiting if
          // that turns out to be the case, but no capture at all is worse.
          audioManagerMode: rec.AudioManagerMode.modeInCommunication,
        ),
        // Mirror the same "phone mic regardless of BT output" intent on iOS:
        // default `allowBluetooth` enables Bluetooth Hands-Free routing,
        // which has the same SCO-vs-A2DP conflict as Android above.
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
