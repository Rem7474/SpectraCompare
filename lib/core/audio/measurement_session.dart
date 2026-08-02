import 'dart:math' as math;
import 'dart:typed_data';

import '../dsp/cross_correlation.dart';
import '../models/signal_config.dart';
import 'signal_generator.dart';
import 'wav_codec.dart';

/// Captures mic audio to a buffer, returned by [stop] as decoded [WavData].
/// Implemented by a thin adapter over the `record` plugin in the real app;
/// implemented by a fake over a synthetic buffer in tests (see
/// `measurement_session_test.dart`).
abstract class Recorder {
  Future<void> start({required int sampleRate});
  Future<WavData> stop();
}

/// Plays a WAV byte buffer and completes when playback finishes. Implemented
/// by a thin adapter over `just_audio` in the real app (writing the bytes to
/// a temp file, since `just_audio` needs a file/URI source).
abstract class Player {
  Future<void> play(Uint8List wavBytes);
}

class MeasurementResult {
  /// The full raw recording (preroll + chirp + gap + main signal + tail),
  /// kept for the measurement library / re-analysis.
  final WavData fullRecording;

  /// Sample offset within [fullRecording] at which the calibration chirp was
  /// found to actually start (see README "Synchronisation et gestion de la
  /// latence").
  final int offsetSamples;

  /// Cross-correlation confidence of the chirp match (see
  /// `CorrelationResult.confidence`). Low values suggest the mic didn't pick
  /// up a clean chirp (e.g. recording started too late, or excessive noise).
  final double confidence;

  /// The main test signal's captured segment, ready for frequency-response
  /// analysis (deconvolution / Welch / single FFT, depending on signal type).
  final Float64List mainSignalSegment;

  const MeasurementResult({
    required this.fullRecording,
    required this.offsetSamples,
    required this.confidence,
    required this.mainSignalSegment,
  });
}

/// Orchestrates a full measurement: builds a single combined WAV
/// (`[preroll][calibration chirp][gap][main signal][tail]`), records while
/// playing it, then locates the chirp in the recording via cross-correlation
/// to determine the real playback→recording offset — without needing any
/// platform-specific timestamp API. See README "Synchronisation et gestion
/// de la latence" and the plan's "Core technical design".
class MeasurementSession {
  final Recorder recorder;
  final Player player;
  final int sampleRate;
  final Duration prerollSilence;
  final Duration warmUpDelay;
  final Duration gapSilence;
  final Duration tailSilence;

  const MeasurementSession({
    required this.recorder,
    required this.player,
    this.sampleRate = 44100,
    this.prerollSilence = const Duration(milliseconds: 500),
    this.warmUpDelay = const Duration(milliseconds: 400),
    this.gapSilence = const Duration(milliseconds: 200),
    // Bluetooth output latency (codec buffering, connection ramp-up) is not
    // reflected in `Player.play()`'s completion signal (see README
    // "Synchronisation et gestion de la latence" — no platform exposes it
    // reliably). This margin has to absorb it, otherwise the recorder can
    // stop before the tail of the signal has actually been rendered
    // acoustically, truncating (or emptying) the captured segment.
    this.tailSilence = const Duration(milliseconds: 1500),
  });

  int _samplesFor(Duration d) =>
      (d.inMicroseconds * sampleRate / Duration.microsecondsPerSecond).round();

  /// Builds the combined playback WAV bytes for a measurement (exposed
  /// separately so tests / the analyzer can reuse the exact same chirp+main
  /// signal layout without going through the recorder/player).
  Uint8List buildCombinedWav(SignalConfig signalConfig) {
    final chirp = SignalGenerator.calibrationChirp(sampleRate: sampleRate);
    final mainSignal = SignalGenerator.generate(signalConfig, sampleRate);
    final combined = _buildCombinedSamples(chirp, mainSignal);
    return WavEncoder.encode(combined, sampleRate: sampleRate);
  }

  Float64List _buildCombinedSamples(Float64List chirp, Float64List mainSignal) {
    final preroll = Float64List(_samplesFor(prerollSilence));
    final gap = Float64List(_samplesFor(gapSilence));
    final tail = Float64List(_samplesFor(tailSilence));

    final combined = Float64List(
      preroll.length +
          chirp.length +
          gap.length +
          mainSignal.length +
          tail.length,
    );
    int offset = 0;
    combined.setAll(offset, preroll);
    offset += preroll.length;
    combined.setAll(offset, chirp);
    offset += chirp.length;
    combined.setAll(offset, gap);
    offset += gap.length;
    combined.setAll(offset, mainSignal);
    offset += mainSignal.length;
    combined.setAll(offset, tail);
    return combined;
  }

  Future<MeasurementResult> run(SignalConfig signalConfig) async {
    final chirp = SignalGenerator.calibrationChirp(sampleRate: sampleRate);
    final mainSignal = SignalGenerator.generate(signalConfig, sampleRate);
    final combined = _buildCombinedSamples(chirp, mainSignal);
    final wavBytes = WavEncoder.encode(combined, sampleRate: sampleRate);

    await recorder.start(sampleRate: sampleRate);
    // Two layers of sync safety margin: preroll baked into the WAV itself,
    // plus this explicit warm-up so the mic pipeline is definitely capturing
    // before the chirp is emitted (mic warm-up latency is device-dependent
    // and otherwise unbounded).
    await Future.delayed(warmUpDelay);
    // Don't trust `player.play()`'s completion alone to know when it's safe
    // to stop recording: on some routes (observed on Bluetooth) the plugin
    // can report completion before the audio has actually finished playing
    // out, which would truncate — or entirely empty — the captured segment.
    // Always wait at least the combined WAV's own nominal duration plus
    // `tailSilence`, regardless of how fast `player.play()` resolves.
    final minPlaybackWait =
        Duration(
          microseconds:
              (combined.length * Duration.microsecondsPerSecond / sampleRate)
                  .round(),
        ) +
        tailSilence;
    await Future.wait([player.play(wavBytes), Future.delayed(minPlaybackWait)]);
    final recording = await recorder.stop();

    final correlation = CrossCorrelation.findOffset(chirp, recording.samples);
    final mainStart =
        correlation.offsetSamples + chirp.length + _samplesFor(gapSilence);
    final mainEnd = math.min(
      recording.samples.length,
      mainStart + mainSignal.length,
    );
    final segment = mainEnd > mainStart
        ? Float64List.sublistView(recording.samples, mainStart, mainEnd)
        : Float64List(0);

    return MeasurementResult(
      fullRecording: recording,
      offsetSamples: correlation.offsetSamples,
      confidence: correlation.confidence,
      mainSignalSegment: segment,
    );
  }
}
