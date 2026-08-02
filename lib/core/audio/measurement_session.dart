import 'dart:math' as math;
import 'dart:typed_data';

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
  /// The full raw recording, kept for the measurement library / re-analysis.
  final WavData fullRecording;

  /// A window of [fullRecording], generously padded around where the main
  /// test signal is expected to be, ready for frequency-response analysis
  /// (deconvolution / Welch / single FFT, depending on signal type).
  final Float64List mainSignalSegment;

  const MeasurementResult({
    required this.fullRecording,
    required this.mainSignalSegment,
  });
}

/// Orchestrates a full measurement: plays `[preroll][main signal][tail]`
/// while recording, then hands back a generously-padded window around where
/// the signal is expected to land.
///
/// Earlier versions tried to pinpoint the exact playback→recording offset
/// with a calibration chirp + cross-correlation, since no platform exposes
/// reliable output-route timestamps (see README "Synchronisation et gestion
/// de la latence"). In practice that made the whole measurement depend on a
/// fragile, latency-sensitive detection step — most exposed over Bluetooth,
/// where output latency is exactly the thing that's unknowable. It also
/// turned out to be unnecessary: `ExponentialSweepDeconvolver` already
/// locates its own impulse-response peak inside whatever window it's given
/// (it's a matched filter for the sweep), and Welch/burst/tone analysis
/// don't need sample-accurate alignment at all — a window that generously
/// contains the signal is enough for all of them. So instead of detecting
/// the real offset, this just pads the analysis window on both sides of the
/// *expected* offset by [latencyMargin], wide enough to absorb typical
/// output-route latency without needing to measure it.
class MeasurementSession {
  final Recorder recorder;
  final Player player;
  final int sampleRate;
  final Duration prerollSilence;
  final Duration warmUpDelay;
  final Duration tailSilence;
  final Duration latencyMargin;

  const MeasurementSession({
    required this.recorder,
    required this.player,
    this.sampleRate = 44100,
    this.prerollSilence = const Duration(milliseconds: 500),
    this.warmUpDelay = const Duration(milliseconds: 400),
    // Bluetooth output latency (codec buffering, connection ramp-up) is not
    // reflected in `Player.play()`'s completion signal. This margin has to
    // absorb it, otherwise the recorder can stop before the tail of the
    // signal has actually been rendered acoustically.
    this.tailSilence = const Duration(milliseconds: 1500),
    this.latencyMargin = const Duration(milliseconds: 2000),
  });

  int _samplesFor(Duration d) =>
      (d.inMicroseconds * sampleRate / Duration.microsecondsPerSecond).round();

  /// Builds the combined playback WAV bytes for a measurement (exposed
  /// separately so tests / the analyzer can reuse the exact same layout
  /// without going through the recorder/player).
  Uint8List buildCombinedWav(SignalConfig signalConfig) {
    final mainSignal = SignalGenerator.generate(signalConfig, sampleRate);
    final combined = _buildCombinedSamples(mainSignal);
    return WavEncoder.encode(combined, sampleRate: sampleRate);
  }

  Float64List _buildCombinedSamples(Float64List mainSignal) {
    final preroll = Float64List(_samplesFor(prerollSilence));
    final tail = Float64List(_samplesFor(tailSilence));

    final combined = Float64List(
      preroll.length + mainSignal.length + tail.length,
    );
    int offset = 0;
    combined.setAll(offset, preroll);
    offset += preroll.length;
    combined.setAll(offset, mainSignal);
    offset += mainSignal.length;
    combined.setAll(offset, tail);
    return combined;
  }

  Future<MeasurementResult> run(SignalConfig signalConfig) async {
    final mainSignal = SignalGenerator.generate(signalConfig, sampleRate);
    final combined = _buildCombinedSamples(mainSignal);
    final wavBytes = WavEncoder.encode(combined, sampleRate: sampleRate);

    await recorder.start(sampleRate: sampleRate);
    // Safety margin so the mic pipeline is definitely capturing before
    // playback starts (mic warm-up latency is device-dependent and
    // otherwise unbounded).
    await Future.delayed(warmUpDelay);
    // Don't trust `player.play()`'s completion alone to know when it's safe
    // to stop recording (see class doc) — always wait at least the combined
    // WAV's own nominal duration plus `tailSilence`, regardless of how fast
    // player.play() resolves.
    final minPlaybackWait =
        Duration(
          microseconds:
              (combined.length * Duration.microsecondsPerSecond / sampleRate)
                  .round(),
        ) +
        tailSilence;
    await Future.wait([player.play(wavBytes), Future.delayed(minPlaybackWait)]);
    final recording = await recorder.stop();

    final expectedStart =
        _samplesFor(warmUpDelay) + _samplesFor(prerollSilence);
    final margin = _samplesFor(latencyMargin);
    final start = math.max(0, expectedStart - margin);
    final end = math.min(
      recording.samples.length,
      expectedStart + margin + mainSignal.length,
    );
    final segment = end > start
        ? Float64List.sublistView(recording.samples, start, end)
        : Float64List(0);

    return MeasurementResult(
      fullRecording: recording,
      mainSignalSegment: segment,
    );
  }
}
