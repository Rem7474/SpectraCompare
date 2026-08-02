import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/measurement_session.dart';
import 'package:spectra_compare/core/audio/mic_test_session.dart';
import 'package:spectra_compare/core/audio/wav_codec.dart';

/// Shared state between the fake player and fake recorder — whatever the
/// fake player "plays" is exactly what the fake recorder "captures", with
/// no processing (unlike `measurement_session_test.dart`'s fakes, position
/// within the recording doesn't matter here, only the overall level).
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
  final int sampleRate;

  FakeRecorder(this.link, {this.sampleRate = 44100});

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
    return WavDecoder.decode(played);
  }
}

void main() {
  const fastTimings = (
    tone: Duration(milliseconds: 50),
    warmUp: Duration.zero,
    tail: Duration(milliseconds: 10),
  );

  test(
    'run() reports a healthy level when the played tone is captured back',
    () async {
      final link = FakeAudioLink();
      final session = MicTestSession(
        recorder: FakeRecorder(link),
        player: FakePlayer(link),
        toneDuration: fastTimings.tone,
        warmUpDelay: fastTimings.warmUp,
        tailMargin: fastTimings.tail,
      );

      final result = await session.run();

      // applyLevelDbfs(pureTone, -10) has an RMS around -13dBFS.
      expect(result.levelDbFs, greaterThan(-15));
      expect(result.levelDbFs, lessThan(-5));
    },
  );

  test('run() reports near-silence when nothing was captured', () async {
    final session = MicTestSession(
      recorder: FakeRecorder(FakeAudioLink()),
      player: FakePlayer(FakeAudioLink()),
      toneDuration: fastTimings.tone,
      warmUpDelay: fastTimings.warmUp,
      tailMargin: fastTimings.tail,
    );

    final result = await session.run();

    expect(result.levelDbFs, lessThan(-60));
  });
}
