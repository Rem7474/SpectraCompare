import 'dart:convert';
import 'dart:typed_data';

/// Decoded WAV data: mono or multi-channel PCM samples normalized to
/// `[-1.0, 1.0]`, interleaved if `channels > 1`.
class WavData {
  final int sampleRate;
  final int channels;
  final Float64List samples;

  const WavData({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });
}

/// Minimal 16-bit PCM WAV encoder/decoder. This app always works with mono,
/// 16-bit PCM, 44100Hz WAV files (see plan's "WAV format assumptions").
class WavEncoder {
  const WavEncoder._();

  static Uint8List encode(
    List<double> samples, {
    int sampleRate = 44100,
    int channels = 1,
  }) {
    final dataLength = samples.length * 2; // 16-bit = 2 bytes/sample
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final buffer = BytesBuilder();

    void writeAscii(String s) => buffer.add(ascii.encode(s));
    void writeUint32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      buffer.add(b.buffer.asUint8List());
    }

    void writeUint16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      buffer.add(b.buffer.asUint8List());
    }

    writeAscii('RIFF');
    writeUint32(36 + dataLength);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeUint32(16); // PCM fmt chunk size
    writeUint16(1); // audio format: PCM
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(16); // bits per sample
    writeAscii('data');
    writeUint32(dataLength);

    final pcm = ByteData(dataLength);
    for (int i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final intSample = (clamped * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 2, intSample, Endian.little);
    }
    buffer.add(pcm.buffer.asUint8List());

    return buffer.toBytes();
  }
}

class WavDecoder {
  const WavDecoder._();

  static WavData decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 44 ||
        ascii.decode(bytes.sublist(0, 4)) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12)) != 'WAVE') {
      throw const FormatException('Not a valid RIFF/WAVE file');
    }

    int offset = 12;
    int? sampleRate;
    int? channels;
    int? bitsPerSample;
    int? audioFormat;
    int? dataOffset;
    int? dataLength;

    while (offset + 8 <= bytes.length) {
      final chunkId = ascii.decode(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;
      if (chunkId == 'fmt ') {
        audioFormat = data.getUint16(chunkDataStart, Endian.little);
        channels = data.getUint16(chunkDataStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkDataStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataStart;
        dataLength = chunkSize;
      }
      offset = chunkDataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (sampleRate == null ||
        channels == null ||
        dataOffset == null ||
        dataLength == null) {
      throw const FormatException('Missing fmt or data chunk');
    }
    if (audioFormat != 1 || bitsPerSample != 16) {
      throw FormatException(
        'Unsupported WAV format (audioFormat=$audioFormat, bitsPerSample=$bitsPerSample); only 16-bit PCM is supported',
      );
    }

    final sampleCount = dataLength ~/ 2;
    final samples = Float64List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      final s = data.getInt16(dataOffset + i * 2, Endian.little);
      samples[i] = s / 32768.0;
    }

    return WavData(
      sampleRate: sampleRate,
      channels: channels,
      samples: samples,
    );
  }
}
