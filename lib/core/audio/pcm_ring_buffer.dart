import 'dart:typed_data';

/// Accumulates irregularly-sized, little-endian PCM16 mono byte chunks (as
/// delivered by `record`'s live `startStream()`) into fixed-size
/// `Float64List` frames for FFT analysis, used by the live analyzer screen.
class PcmRingBuffer {
  final int frameSize;
  final int hopSize;
  final List<double> _buffer = [];

  PcmRingBuffer({required this.frameSize, int? hopSize}) : hopSize = hopSize ?? frameSize;

  /// Feeds a chunk of PCM16 bytes, returning zero or more complete (possibly
  /// overlapping, if `hopSize < frameSize`) frames ready for FFT.
  List<Float64List> addBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    for (int i = 0; i < sampleCount; i++) {
      _buffer.add(data.getInt16(i * 2, Endian.little) / 32768.0);
    }
    final frames = <Float64List>[];
    while (_buffer.length >= frameSize) {
      frames.add(Float64List.fromList(_buffer.sublist(0, frameSize)));
      _buffer.removeRange(0, hopSize);
    }
    return frames;
  }

  void reset() => _buffer.clear();
}
