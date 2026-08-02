import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

class Spectrum {
  final Float64List freqsHz;
  final Float64List magnitudesDb;

  const Spectrum(this.freqsHz, this.magnitudesDb);
}

class FftUtils {
  static const double _epsilonDb = 1e-12;

  const FftUtils._();

  static int nextPowerOfTwo(int n) {
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  static double linearToDb(double linear) =>
      20 * (math.log(linear.clamp(_epsilonDb, double.infinity)) / math.ln10);

  static double powerToDb(double power) =>
      10 * (math.log(power.clamp(_epsilonDb, double.infinity)) / math.ln10);

  static double dbToLinear(double db) => math.pow(10, db / 20).toDouble();

  /// Computes the amplitude-normalized magnitude spectrum (in dB, 0dB ≈ a
  /// full-scale sinusoid) of a single [frame] of real samples.
  ///
  /// The frame is optionally Hann-windowed, zero-padded to [fftSize] (or the
  /// next power of two ≥ frame.length if omitted), and only the
  /// non-redundant half of the spectrum (DC..Nyquist) is returned.
  static Spectrum magnitudeSpectrum(
    List<double> frame,
    int sampleRate, {
    bool hannWindow = true,
    int? fftSize,
  }) {
    final n = fftSize ?? nextPowerOfTwo(frame.length);
    final fft = FFT(n);
    late final List<double> windowed;
    late final double windowSum;
    if (hannWindow) {
      final win = Window.hanning(frame.length);
      windowed = win.applyWindowReal(frame);
      windowSum = win.fold(0.0, (a, b) => a + b);
    } else {
      windowed = frame;
      windowSum = frame.length.toDouble();
    }
    // Zero-pad to `n` explicitly: `fft.realFft` alone would size the complex
    // array to `windowed.length`, not `n`, and throw if they differ.
    final complex = ComplexArray.fromRealArray(windowed, n);
    fft.inPlaceFft(complex);
    final mags = complex.magnitudes();
    final bins = n ~/ 2 + 1;
    final freqs = Float64List(bins);
    final db = Float64List(bins);
    // Normalizing by windowSum/2 makes a full-scale sinusoid read ~0dB,
    // regardless of window shape or FFT size — good enough for the relative
    // comparisons this app is built around (see README "Limites connues").
    final norm = windowSum / 2;
    for (int i = 0; i < bins; i++) {
      freqs[i] = fft.frequency(i, sampleRate.toDouble());
      db[i] = linearToDb(mags[i] / norm);
    }
    return Spectrum(freqs, db);
  }
}
