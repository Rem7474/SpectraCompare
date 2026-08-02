import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/audio/wav_codec.dart';

void main() {
  group('WavEncoder/WavDecoder', () {
    test('round-trips samples within 16-bit quantization error', () {
      const sampleRate = 44100;
      final samples = Float64List(1000);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = math.sin(2 * math.pi * 440 * i / sampleRate) * 0.8;
      }

      final bytes = WavEncoder.encode(samples, sampleRate: sampleRate);
      final decoded = WavDecoder.decode(bytes);

      expect(decoded.sampleRate, sampleRate);
      expect(decoded.channels, 1);
      expect(decoded.samples.length, samples.length);
      for (int i = 0; i < samples.length; i++) {
        expect(decoded.samples[i], closeTo(samples[i], 2 / 32767));
      }
    });

    test('header byte counts are correct', () {
      final samples = Float64List(100);
      final bytes = WavEncoder.encode(samples, sampleRate: 48000);
      // 44-byte header + 2 bytes/sample * 100 samples.
      expect(bytes.length, 44 + 200);
      final data = ByteData.sublistView(bytes);
      expect(data.getUint32(4, Endian.little), 36 + 200); // RIFF chunk size
      expect(data.getUint32(24, Endian.little), 48000); // sample rate
      expect(data.getUint32(40, Endian.little), 200); // data chunk size
    });

    test('clamps out-of-range samples instead of overflowing', () {
      final samples = Float64List.fromList([2.0, -2.0, 0.0]);
      final bytes = WavEncoder.encode(samples);
      final decoded = WavDecoder.decode(bytes);
      expect(decoded.samples[0], closeTo(1.0, 1e-4));
      expect(decoded.samples[1], closeTo(-1.0, 1e-4));
      expect(decoded.samples[2], closeTo(0.0, 1e-4));
    });

    test('rejects non-PCM16 formats', () {
      final bytes = WavEncoder.encode(Float64List(10));
      // Corrupt bitsPerSample field (offset 34) to 8 bits.
      final mutable = Uint8List.fromList(bytes);
      ByteData.sublistView(mutable).setUint16(34, 8, Endian.little);
      expect(() => WavDecoder.decode(mutable), throwsFormatException);
    });
  });
}
