import 'dart:math' as math;
import 'dart:typed_data';

import '../models/signal_config.dart';

/// Generates PCM test signals (sweep, pink/white noise, burst, pure tone) as
/// `Float64List` samples normalized to `[-1.0, 1.0]` peak, before level
/// scaling. See README "Générateur de signaux".
class SignalGenerator {
  const SignalGenerator._();

  static Float64List generate(SignalConfig config, int sampleRate) {
    late Float64List raw;
    switch (config.type) {
      case SignalType.sineSweepLog:
        raw = sineSweep(
          f0: config.startFreqHz,
          f1: config.endFreqHz,
          durationS: config.durationS,
          sampleRate: sampleRate,
          logarithmic: true,
        );
      case SignalType.sineSweepLinear:
        raw = sineSweep(
          f0: config.startFreqHz,
          f1: config.endFreqHz,
          durationS: config.durationS,
          sampleRate: sampleRate,
          logarithmic: false,
        );
      case SignalType.pinkNoise:
        raw = pinkNoise((config.durationS * sampleRate).round());
      case SignalType.whiteNoise:
        raw = whiteNoise((config.durationS * sampleRate).round());
      case SignalType.burst:
        raw = burst(
          freq: config.frequencyHz,
          durationS: config.durationS,
          sampleRate: sampleRate,
        );
      case SignalType.pureTone:
        raw = pureTone(
          freq: config.frequencyHz,
          durationS: config.durationS,
          sampleRate: sampleRate,
        );
    }
    return applyLevelDbfs(raw, config.levelDbfs);
  }

  /// Sine sweep, 20Hz–20kHz-style, linear or exponential (logarithmic).
  ///
  /// The exponential form matches Farina's ESS convention used by
  /// `ExponentialSweepDeconvolver`: `x(t) = sin(K·(exp(t/L) − 1))`,
  /// `L = T / ln(f1/f0)`, `K = 2π·f0·L`.
  static Float64List sineSweep({
    required double f0,
    required double f1,
    required double durationS,
    required int sampleRate,
    bool logarithmic = true,
  }) {
    final n = (durationS * sampleRate).round();
    final out = Float64List(n);
    if (logarithmic) {
      final l = durationS / math.log(f1 / f0);
      final k = 2 * math.pi * f0 * l;
      for (int i = 0; i < n; i++) {
        final t = i / sampleRate;
        out[i] = math.sin(k * (math.exp(t / l) - 1));
      }
    } else {
      for (int i = 0; i < n; i++) {
        final t = i / sampleRate;
        // Instantaneous phase for a linear frequency ramp f(t) = f0 + (f1-f0)t/T
        final phase =
            2 * math.pi * (f0 * t + (f1 - f0) * t * t / (2 * durationS));
        out[i] = math.sin(phase);
      }
    }
    return _applyEdgeFade(out, sampleRate, fadeMs: 5);
  }

  /// Pink noise (~ -3dB/octave), via Paul Kellet's economy pink noise filter.
  static Float64List pinkNoise(int numSamples, {int? seed}) {
    final rand = math.Random(seed);
    final out = Float64List(numSamples);
    double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    for (int i = 0; i < numSamples; i++) {
      final white = rand.nextDouble() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      final pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
      b6 = white * 0.115926;
      out[i] = pink * 0.11;
    }
    return _normalizePeak(out);
  }

  static Float64List whiteNoise(int numSamples, {int? seed}) {
    final rand = math.Random(seed);
    final out = Float64List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      out[i] = rand.nextDouble() * 2 - 1;
    }
    return out;
  }

  /// Short tone burst (transient impulse for rattle/reactivity tests, and the
  /// calibration chirp uses this too when `freq` maps to a short log sweep —
  /// see `calibrationChirp`).
  static Float64List burst({
    required double freq,
    required double durationS,
    required int sampleRate,
  }) {
    final n = (durationS * sampleRate).round();
    final out = Float64List(n);
    for (int i = 0; i < n; i++) {
      final t = i / sampleRate;
      out[i] = math.sin(2 * math.pi * freq * t);
    }
    return _applyEdgeFade(
      out,
      sampleRate,
      fadeMs: math.min(5, durationS * 1000 / 4),
    );
  }

  static Float64List pureTone({
    required double freq,
    required double durationS,
    required int sampleRate,
  }) {
    final n = (durationS * sampleRate).round();
    final out = Float64List(n);
    for (int i = 0; i < n; i++) {
      final t = i / sampleRate;
      out[i] = math.sin(2 * math.pi * freq * t);
    }
    return _applyEdgeFade(out, sampleRate, fadeMs: 5);
  }

  static Float64List applyLevelDbfs(Float64List samples, double dBFS) {
    final gain = math.pow(10, dBFS / 20).toDouble();
    final out = Float64List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      out[i] = samples[i] * gain;
    }
    return out;
  }

  static Float64List _applyEdgeFade(
    Float64List samples,
    int sampleRate, {
    double fadeMs = 5,
  }) {
    final fadeSamples = math.min(
      samples.length ~/ 2,
      (fadeMs * sampleRate / 1000).round(),
    );
    if (fadeSamples <= 0) return samples;
    for (int i = 0; i < fadeSamples; i++) {
      final g = i / fadeSamples;
      samples[i] *= g;
      samples[samples.length - 1 - i] *= g;
    }
    return samples;
  }

  static Float64List _normalizePeak(Float64List samples) {
    double maxAbs = 0;
    for (final s in samples) {
      final a = s.abs();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs == 0) return samples;
    final out = Float64List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      out[i] = samples[i] / maxAbs;
    }
    return out;
  }
}
