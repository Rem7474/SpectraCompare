import 'package:flutter/foundation.dart';

import '../../core/models/measurement.dart';
import '../../core/storage/database.dart';

/// Backs the multi-speaker comparison screen (README "Comparaison
/// multi-enceintes"): overlay curves, delta dB vs. one chosen reference
/// measurement, per 1/3-octave band.
class ComparisonController extends ChangeNotifier {
  final MeasurementDao measurementDao;

  ComparisonController({required this.measurementDao});

  List<Measurement> available = [];
  final Set<int> selectedIds = {};
  int? referenceId;

  Future<void> load() async {
    available = await measurementDao.getAll();
    notifyListeners();
  }

  void toggleSelected(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
      if (referenceId == id) referenceId = null;
    } else {
      selectedIds.add(id);
      referenceId ??= id;
    }
    notifyListeners();
  }

  void setReference(int id) {
    referenceId = id;
    notifyListeners();
  }

  List<Measurement> get selectedMeasurements => available.where((m) => selectedIds.contains(m.id)).toList();

  Measurement? get reference {
    final id = referenceId;
    if (id == null) return null;
    for (final m in available) {
      if (m.id == id) return m;
    }
    return null;
  }
}
