import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/pcm_ring_buffer.dart';

Uint8List _pcm16Bytes(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (int i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('PcmRingBuffer', () {
    test('emits no frames until enough samples have accumulated', () {
      final buffer = PcmRingBuffer(frameSize: 8);
      final frames = buffer.addBytes(_pcm16Bytes(List.filled(5, 100)));
      expect(frames, isEmpty);
    });

    test(
      'emits a frame once frameSize samples accumulate, across irregular chunks',
      () {
        final buffer = PcmRingBuffer(frameSize: 8);
        var frames = buffer.addBytes(_pcm16Bytes(List.filled(3, 1000)));
        expect(frames, isEmpty);
        frames = buffer.addBytes(_pcm16Bytes(List.filled(2, 2000)));
        expect(frames, isEmpty);
        frames = buffer.addBytes(_pcm16Bytes(List.filled(10, 3000)));
        expect(
          frames.length,
          1,
        ); // 3+2+10=15 samples -> one 8-sample frame, 7 left buffered
        expect(frames.first.length, 8);
        expect(frames.first[0], closeTo(1000 / 32768.0, 1e-9));
      },
    );

    test('supports overlapping frames via hopSize < frameSize', () {
      final buffer = PcmRingBuffer(frameSize: 4, hopSize: 2);
      final samples = List<int>.generate(10, (i) => i * 100);
      final frames = buffer.addBytes(_pcm16Bytes(samples));
      // 10 samples, frameSize 4, hop 2 -> frames start at 0,2,4 (need 4 more for next => stop)
      expect(frames.length, 4);
      expect(
        frames[1][0],
        closeTo(200 / 32768.0, 1e-9),
      ); // second frame starts at sample index 2
    });

    test('reset clears buffered samples', () {
      final buffer = PcmRingBuffer(frameSize: 8);
      buffer.addBytes(_pcm16Bytes(List.filled(5, 100)));
      buffer.reset();
      final frames = buffer.addBytes(_pcm16Bytes(List.filled(5, 100)));
      expect(frames, isEmpty); // would need 8, only 5 present post-reset
    });
  });
}
