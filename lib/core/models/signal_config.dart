enum SignalType { sineSweepLog, sineSweepLinear, pinkNoise, whiteNoise, burst, pureTone }

/// Configuration for a generated test signal (see `SignalGenerator`).
class SignalConfig {
  final SignalType type;
  final double startFreqHz;
  final double endFreqHz;
  final double frequencyHz;
  final double durationS;
  final double levelDbfs;

  const SignalConfig({
    required this.type,
    this.startFreqHz = 20,
    this.endFreqHz = 20000,
    this.frequencyHz = 1000,
    this.durationS = 10,
    this.levelDbfs = -20,
  });

  SignalConfig copyWith({
    SignalType? type,
    double? startFreqHz,
    double? endFreqHz,
    double? frequencyHz,
    double? durationS,
    double? levelDbfs,
  }) {
    return SignalConfig(
      type: type ?? this.type,
      startFreqHz: startFreqHz ?? this.startFreqHz,
      endFreqHz: endFreqHz ?? this.endFreqHz,
      frequencyHz: frequencyHz ?? this.frequencyHz,
      durationS: durationS ?? this.durationS,
      levelDbfs: levelDbfs ?? this.levelDbfs,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'startFreqHz': startFreqHz,
        'endFreqHz': endFreqHz,
        'frequencyHz': frequencyHz,
        'durationS': durationS,
        'levelDbfs': levelDbfs,
      };

  factory SignalConfig.fromJson(Map<String, dynamic> json) => SignalConfig(
        type: SignalType.values.firstWhere((e) => e.name == json['type']),
        startFreqHz: (json['startFreqHz'] as num).toDouble(),
        endFreqHz: (json['endFreqHz'] as num).toDouble(),
        frequencyHz: (json['frequencyHz'] as num).toDouble(),
        durationS: (json['durationS'] as num).toDouble(),
        levelDbfs: (json['levelDbfs'] as num).toDouble(),
      );
}
