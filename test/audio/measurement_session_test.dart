import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/measurement_session.dart';
import 'package:spectra_compare/core/audio/signal_generator.dart';
import 'package:spectra_compare/core/audio/wav_codec.dart';
import 'package:spectra_compare/core/models/signal_config.dart';

/// Shared state between the fake player and fake recorder, simulating a
/// physical playback→recording round trip: whatever the fake player "plays"
/// becomes (a delayed, optionally noisy copy of) what the fake recorder
/// "captures" — without touching any real audio plugin.
class FakeAudioLink {
  Uint8List? playedBytes;
}

class FakePlayer implements Player {
  final FakeAudioLink link;
  FakePlayer(this.link);

  @override
  Future<void> play(Uint8List wavBytes) async {
    link.playedBytes = wavBytes;
  }
}

class FakeRecorder implements Recorder {
  final FakeAudioLink link;
  final int injectedOffsetSamples;
  final int sampleRate;

  FakeRecorder(
    this.link, {
    this.injectedOffsetSamples = 800,
    this.sampleRate = 44100,
  });

  @override
  Future<void> start({required int sampleRate}) async {}

  @override
  Future<WavData> stop() async {
    final played = link.playedBytes;
    if (played == null) {
      return WavData(
        sampleRate: sampleRate,
        channels: 1,
        samples: Float64List(0),
      );
    }
    final decoded = WavDecoder.decode(played);
    final pre = Float64List(injectedOffsetSamples);
    final post = Float64List(400);
    final combined = Float64List(
      pre.length + decoded.samples.length + post.length,
    );
    combined.setAll(0, pre);
    combined.setAll(pre.length, decoded.samples);
    return WavData(sampleRate: sampleRate, channels: 1, samples: combined);
  }
}

void main() {
  const sampleRate = 44100;
  // Minimal delays: correctness of the sync algorithm doesn't depend on
  // real wall-clock timing, so keep tests fast.
  const fastTimings = (
    preroll: Duration(milliseconds: 50),
    warmUp: Duration.zero,
    gap: Duration(milliseconds: 20),
    tail: Duration(milliseconds: 10),
  );

  test(
    'run() locates the chirp and extracts the main signal segment despite an injected acoustic delay',
    () async {
      final link = FakeAudioLink();
      const injectedOffset = 800;
      final session = MeasurementSession(
        recorder: FakeRecorder(
          link,
          injectedOffsetSamples: injectedOffset,
          sampleRate: sampleRate,
        ),
        player: FakePlayer(link),
        sampleRate: sampleRate,
        prerollSilence: fastTimings.preroll,
        warmUpDelay: fastTimings.warmUp,
        gapSilence: fastTimings.gap,
        tailSilence: fastTimings.tail,
      );

      const signalConfig = SignalConfig(
        type: SignalType.sineSweepLog,
        startFreqHz: 20,
        endFreqHz: 20000,
        durationS: 1.0,
        levelDbfs: -20,
      );

      final result = await session.run(signalConfig);

      final prerollSamples =
          (fastTimings.preroll.inMicroseconds * sampleRate / 1e6).round();
      expect(result.offsetSamples, injectedOffset + prerollSamples);
      expect(result.confidence, greaterThan(0.9));

      final expectedMainSignal = SignalGenerator.generate(
        signalConfig,
        sampleRate,
      );
      expect(result.mainSignalSegment.length, expectedMainSignal.length);
      for (int i = 0; i < expectedMainSignal.length; i += 500) {
        expect(
          result.mainSignalSegment[i],
          closeTo(expectedMainSignal[i], 1e-3),
        );
      }
    },
  );

  test(
    'buildCombinedWav lays out [preroll][chirp][gap][main][tail] at the expected sample positions',
    () {
      final session = MeasurementSession(
        recorder: FakeRecorder(FakeAudioLink()),
        player: FakePlayer(FakeAudioLink()),
        sampleRate: sampleRate,
        prerollSilence: fastTimings.preroll,
        gapSilence: fastTimings.gap,
        tailSilence: fastTimings.tail,
      );
      const signalConfig = SignalConfig(
        type: SignalType.pureTone,
        frequencyHz: 1000,
        durationS: 0.2,
      );
      final bytes = session.buildCombinedWav(signalConfig);
      final decoded = WavDecoder.decode(bytes);

      final chirp = SignalGenerator.calibrationChirp(sampleRate: sampleRate);
      final mainSignal = SignalGenerator.generate(signalConfig, sampleRate);
      final prerollSamples =
          (fastTimings.preroll.inMicroseconds * sampleRate / 1e6).round();
      final gapSamples = (fastTimings.gap.inMicroseconds * sampleRate / 1e6)
          .round();
      final tailSamples = (fastTimings.tail.inMicroseconds * sampleRate / 1e6)
          .round();

      final expectedLength =
          prerollSamples +
          chirp.length +
          gapSamples +
          mainSignal.length +
          tailSamples;
      expect(decoded.samples.length, expectedLength);

      // Preroll should be silence.
      for (int i = 0; i < prerollSamples; i += 100) {
        expect(decoded.samples[i], 0.0);
      }
    },
  );
}
