import 'package:flutter/foundation.dart';

import '../../core/models/calibration_curve.dart';
import '../../core/storage/calibration_file_parser.dart';
import '../../core/storage/database.dart';

/// Backs the mic calibration screen (README "Mode calibration micro" —
/// compatible REW/miniDSP correction files).
class CalibrationController extends ChangeNotifier {
  final CalibrationCurveDao dao;

  CalibrationController({required this.dao});

  List<CalibrationCurve> curves = [];
  CalibrationCurve? selected;
  String? errorMessage;

  Future<void> load() async {
    curves = await dao.getAll();
    notifyListeners();
  }

  Future<void> importFromText(String contents, String name) async {
    errorMessage = null;
    try {
      final curve = CalibrationFileParser.parse(contents, name: name);
      await dao.insert(curve, sourceFilename: name);
      await load();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> delete(int id) async {
    await dao.delete(id);
    if (selected?.id == id) selected = null;
    await load();
  }

  void select(CalibrationCurve? curve) {
    selected = curve;
    notifyListeners();
  }
}
