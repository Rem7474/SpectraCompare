import '../dsp/spl.dart';
import 'measurement_session.dart' show Recorder, Player;
import 'signal_generator.dart';
import 'wav_codec.dart';

class MicTestResult {
  /// RMS level of the whole capture, in dBFS.
  final double levelDbFs;

  const MicTestResult(this.levelDbFs);
}

/// Quick, standalone "does the mic actually pick up what we play" check —
/// plays a short loud tone through the exact same `Recorder`/`Player`
/// pipeline a real measurement uses, and reports the captured RMS level.
///
/// Useful to isolate audio-routing/processing issues (Bluetooth SCO
/// conflicts, aggressive echo cancellation — see README "Synchronisation et
/// gestion de la latence") in a couple of seconds, instead of waiting
/// through a full sweep measurement each time a setting changes.
class MicTestSession {
  final Recorder recorder;
  final Player player;
  final int sampleRate;
  final Duration toneDuration;
  final Duration warmUpDelay;
  final Duration tailMargin;

  const MicTestSession({
    required this.recorder,
    required this.player,
    this.sampleRate = 44100,
    this.toneDuration = const Duration(milliseconds: 1500),
    this.warmUpDelay = const Duration(milliseconds: 300),
    this.tailMargin = const Duration(milliseconds: 800),
  });

  Future<MicTestResult> run() async {
    final tone = SignalGenerator.applyLevelDbfs(
      SignalGenerator.pureTone(
        freq: 1000,
        durationS: toneDuration.inMilliseconds / 1000,
        sampleRate: sampleRate,
      ),
      -10,
    );
    final wavBytes = WavEncoder.encode(tone, sampleRate: sampleRate);

    await recorder.start(sampleRate: sampleRate);
    await Future.delayed(warmUpDelay);
    final minWait = toneDuration + tailMargin;
    await Future.wait([player.play(wavBytes), Future.delayed(minWait)]);
    final recording = await recorder.stop();

    return MicTestResult(Spl.rmsDbFs(recording.samples));
  }
}
