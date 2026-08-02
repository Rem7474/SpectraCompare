import 'package:flutter/foundation.dart';

import '../../core/models/measurement.dart';
import '../../core/storage/database.dart';

/// Backs the measurement library screen (README "Bibliothèque de mesures").
class LibraryController extends ChangeNotifier {
  final MeasurementDao measurementDao;

  LibraryController({required this.measurementDao});

  List<Measurement> measurements = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    measurements = await measurementDao.getAll();
    isLoading = false;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await measurementDao.delete(id);
    await load();
  }

  Set<String> get allTags => {
        for (final m in measurements) ...m.tags,
        for (final m in measurements)
          if (m.speakerModel != null && m.speakerModel!.isNotEmpty) m.speakerModel!,
      };
}
