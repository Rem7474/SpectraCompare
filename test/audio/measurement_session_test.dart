import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/measurement_session.dart';
import 'package:spectra_compare/core/audio/signal_generator.dart';
import 'package:spectra_compare/core/audio/wav_codec.dart';
import 'package:spectra_compare/core/models/signal_config.dart';

/// Shared state between the fake player and fake recorder, simulating a
/// physical playback→recording round trip: whatever the fake player "plays"
/// shows up in what the fake recorder "captures", shifted by a configurable
/// acoustic delay — without touching any real audio plugin.
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
  final int acousticDelaySamples;
  final int sampleRate;

  FakeRecorder(
    this.link, {
    this.acousticDelaySamples = 0,
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
    final pre = Float64List(acousticDelaySamples);
    final combined = Float64List(pre.length + decoded.samples.length);
    combined.setAll(0, pre);
    combined.setAll(pre.length, decoded.samples);
    return WavData(sampleRate: sampleRate, channels: 1, samples: combined);
  }
}

void main() {
  const sampleRate = 44100;
  // Minimal delays: correctness doesn't depend on real wall-clock timing, so
  // keep tests fast. `margin` stays small too — just enough to prove the
  // acoustic-delay shift ends up inside the returned segment.
  const fastTimings = (
    preroll: Duration(milliseconds: 50),
    warmUp: Duration.zero,
    tail: Duration(milliseconds: 10),
    margin: Duration(milliseconds: 100),
  );

  int samplesFor(Duration d) => (d.inMicroseconds * sampleRate / 1e6).round();

  test('run() returns a segment that contains the main signal even with an '
      'acoustic delay, without detecting the delay itself', () async {
    final link = FakeAudioLink();
    const acousticDelay = 400;
    final session = MeasurementSession(
      recorder: FakeRecorder(
        link,
        acousticDelaySamples: acousticDelay,
        sampleRate: sampleRate,
      ),
      player: FakePlayer(link),
      sampleRate: sampleRate,
      prerollSilence: fastTimings.preroll,
      warmUpDelay: fastTimings.warmUp,
      tailSilence: fastTimings.tail,
      latencyMargin: fastTimings.margin,
    );

    const signalConfig = SignalConfig(
      type: SignalType.sineSweepLog,
      startFreqHz: 20,
      endFreqHz: 20000,
      durationS: 1.0,
      levelDbfs: -20,
    );

    final result = await session.run(signalConfig);
    final expectedMainSignal = SignalGenerator.generate(
      signalConfig,
      sampleRate,
    );

    // The segment is a fixed window around the *expected* (undelayed)
    // position, padded by `latencyMargin` on both sides — so the true
    // signal start shifts inside it by exactly the acoustic delay.
    final expectedStart =
        samplesFor(fastTimings.warmUp) + samplesFor(fastTimings.preroll);
    final marginSamples = samplesFor(fastTimings.margin);
    final segmentStart = math.max(0, expectedStart - marginSamples);
    final trueMainStartInSegment = acousticDelay + expectedStart - segmentStart;

    expect(result.mainSignalSegment.length, greaterThan(0));
    expect(
      trueMainStartInSegment + expectedMainSignal.length,
      lessThanOrEqualTo(result.mainSignalSegment.length),
    );
    for (int i = 0; i < expectedMainSignal.length; i += 500) {
      expect(
        result.mainSignalSegment[trueMainStartInSegment + i],
        closeTo(expectedMainSignal[i], 1e-3),
      );
    }
  });

  test(
    'buildCombinedWav lays out [preroll][main][tail] at the expected sample positions',
    () {
      final session = MeasurementSession(
        recorder: FakeRecorder(FakeAudioLink()),
        player: FakePlayer(FakeAudioLink()),
        sampleRate: sampleRate,
        prerollSilence: fastTimings.preroll,
        tailSilence: fastTimings.tail,
      );
      const signalConfig = SignalConfig(
        type: SignalType.pureTone,
        frequencyHz: 1000,
        durationS: 0.2,
      );
      final bytes = session.buildCombinedWav(signalConfig);
      final decoded = WavDecoder.decode(bytes);

      final mainSignal = SignalGenerator.generate(signalConfig, sampleRate);
      final prerollSamples = samplesFor(fastTimings.preroll);
      final tailSamples = samplesFor(fastTimings.tail);

      final expectedLength = prerollSamples + mainSignal.length + tailSamples;
      expect(decoded.samples.length, expectedLength);

      // Preroll should be silence.
      for (int i = 0; i < prerollSamples; i += 100) {
        expect(decoded.samples[i], 0.0);
      }
    },
  );
}
