import '../../core/models/signal_config.dart';

class SignalPreset {
  final String name;
  final String description;
  final SignalConfig config;

  const SignalPreset({
    required this.name,
    required this.description,
    required this.config,
  });
}

/// The presets called out in README "Générateur de signaux" ("Presets
/// enregistrement rapide").
class SignalPresets {
  const SignalPresets._();

  static const sweepStandard = SignalPreset(
    name: 'Sweep standard',
    description:
        'Balayage logarithmique 20Hz–20kHz, 10s — mesure de réponse en fréquence',
    config: SignalConfig(
      type: SignalType.sineSweepLog,
      startFreqHz: 20,
      endFreqHz: 20000,
      durationS: 10,
      levelDbfs: -20,
    ),
  );

  static const calibrationPinkNoise = SignalPreset(
    name: 'Calibration pink noise',
    description: 'Bruit rose, 10s — calibration et analyse RTA',
    config: SignalConfig(
      type: SignalType.pinkNoise,
      durationS: 10,
      levelDbfs: -20,
    ),
  );

  static const testRattleBurst = SignalPreset(
    name: 'Test rattle/burst',
    description:
        'Impulsion courte basse fréquence — détection de vibrations/rattle',
    config: SignalConfig(
      type: SignalType.burst,
      frequencyHz: 80,
      durationS: 0.3,
      levelDbfs: -20,
    ),
  );

  static const all = [sweepStandard, calibrationPinkNoise, testRattleBurst];
}
