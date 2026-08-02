import 'frequency_response.dart';
import 'signal_config.dart';

/// A single saved speaker measurement: its test signal config, the raw
/// recording, the computed frequency response, and the tags used to
/// distinguish it in the library / comparison screens.
class Measurement {
  final int? id;
  final DateTime createdAt;
  final String? speakerModel;
  final String? position;
  final double? distanceM;
  final double outputLevelDbfs;
  final SignalConfig signalConfig;
  final int sampleRate;
  final int? offsetSamples;
  final double? correlationConfidence;
  final String? rawWavPath;
  final FrequencyResponse frequencyResponse;
  final int? calibrationCurveId;
  final List<String> tags;
  final String? notes;

  const Measurement({
    this.id,
    required this.createdAt,
    this.speakerModel,
    this.position,
    this.distanceM,
    required this.outputLevelDbfs,
    required this.signalConfig,
    required this.sampleRate,
    this.offsetSamples,
    this.correlationConfidence,
    this.rawWavPath,
    required this.frequencyResponse,
    this.calibrationCurveId,
    this.tags = const [],
    this.notes,
  });

  Measurement copyWith({int? id, FrequencyResponse? frequencyResponse}) {
    return Measurement(
      id: id ?? this.id,
      createdAt: createdAt,
      speakerModel: speakerModel,
      position: position,
      distanceM: distanceM,
      outputLevelDbfs: outputLevelDbfs,
      signalConfig: signalConfig,
      sampleRate: sampleRate,
      offsetSamples: offsetSamples,
      correlationConfidence: correlationConfidence,
      rawWavPath: rawWavPath,
      frequencyResponse: frequencyResponse ?? this.frequencyResponse,
      calibrationCurveId: calibrationCurveId,
      tags: tags,
      notes: notes,
    );
  }

  /// A short, human-readable label for lists (e.g. "JBL 305P — 1m, sweep").
  String get displayName {
    final parts = <String>[
      if (speakerModel != null && speakerModel!.isNotEmpty)
        speakerModel!
      else
        'Mesure',
      if (position != null && position!.isNotEmpty) position!,
    ];
    return parts.join(' — ');
  }
}
