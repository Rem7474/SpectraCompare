import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/calibration_curve.dart';
import 'calibration_controller.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalibrationController>().load();
    });
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = context.read<CalibrationController>();
    final nameCtrl = TextEditingController(text: 'Ma calibration');
    final contentsCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importer une calibration'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 8),
              const Text(
                'Colle le contenu du fichier de calibration (format REW/miniDSP: '
                'fréquence, dB par ligne).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TextField(
                controller: contentsCtrl,
                maxLines: 8,
                decoration: const InputDecoration(hintText: '20 1.2\n100 0.5\n1000 0.0\n...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              await controller.importFromText(contentsCtrl.text, nameCtrl.text.trim());
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calibration = context.watch<CalibrationController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration micro')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showImportDialog(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioListTile<CalibrationCurve?>(
              value: null,
              groupValue: calibration.selected,
              onChanged: (_) => calibration.select(null),
              title: const Text('Aucune (mesures relatives, non calibrées)'),
            ),
            if (calibration.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(calibration.errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final curve in calibration.curves)
                    RadioListTile<CalibrationCurve?>(
                      value: curve,
                      groupValue: calibration.selected,
                      onChanged: (_) => calibration.select(curve),
                      title: Text(curve.name),
                      subtitle: Text('${curve.points.length} points'),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => calibration.delete(curve.id!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
