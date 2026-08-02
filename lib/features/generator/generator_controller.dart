import 'package:flutter/foundation.dart';

import '../../core/models/signal_config.dart';
import 'presets.dart';

/// Owns the currently-configured test signal (preset or manually adjusted).
class GeneratorController extends ChangeNotifier {
  SignalConfig _config = SignalPresets.sweepStandard.config;

  SignalConfig get config => _config;

  void selectPreset(SignalPreset preset) {
    _config = preset.config;
    notifyListeners();
  }

  void setType(SignalType type) {
    _config = _config.copyWith(type: type);
    notifyListeners();
  }

  void setStartFreq(double hz) {
    _config = _config.copyWith(startFreqHz: hz);
    notifyListeners();
  }

  void setEndFreq(double hz) {
    _config = _config.copyWith(endFreqHz: hz);
    notifyListeners();
  }

  void setToneFreq(double hz) {
    _config = _config.copyWith(frequencyHz: hz);
    notifyListeners();
  }

  void setDuration(double seconds) {
    _config = _config.copyWith(durationS: seconds);
    notifyListeners();
  }

  /// Output level in dBFS. Defaults to -20dBFS to protect speakers and keep
  /// comparisons level-matched (see README warning).
  void setLevelDbfs(double dbfs) {
    _config = _config.copyWith(levelDbfs: dbfs);
    notifyListeners();
  }
}
