import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/signal_config.dart';
import '../../widgets/frequency_response_chart.dart';
import '../calibration/calibration_controller.dart';
import '../generator/generator_controller.dart';
import '../generator/presets.dart';
import 'measurement_controller.dart';

class MeasurementScreen extends StatelessWidget {
  const MeasurementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesurer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _PresetPicker(),
              SizedBox(height: 12),
              _SignalParamsEditor(),
              SizedBox(height: 16),
              _MeasurementRunner(),
              SizedBox(height: 16),
              _ResultView(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetPicker extends StatelessWidget {
  const _PresetPicker();

  @override
  Widget build(BuildContext context) {
    final generator = context.watch<GeneratorController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Presets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in SignalPresets.all)
                  ChoiceChip(
                    label: Text(preset.name),
                    selected:
                        generator.config.type == preset.config.type &&
                        generator.config.durationS == preset.config.durationS,
                    onSelected: (_) => generator.selectPreset(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalParamsEditor extends StatelessWidget {
  const _SignalParamsEditor();

  @override
  Widget build(BuildContext context) {
    final generator = context.watch<GeneratorController>();
    final config = generator.config;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signal: ${_typeLabel(config.type)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (config.type == SignalType.sineSweepLog ||
                config.type == SignalType.sineSweepLinear) ...[
              Text(
                '${config.startFreqHz.round()}Hz – ${config.endFreqHz.round()}Hz',
              ),
            ],
            if (config.type == SignalType.pureTone ||
                config.type == SignalType.burst) ...[
              Text('Fréquence: ${config.frequencyHz.round()}Hz'),
            ],
            Text('Durée: ${config.durationS.toStringAsFixed(1)}s'),
            const SizedBox(height: 8),
            Text('Niveau de sortie: ${config.levelDbfs.round()}dBFS'),
            Slider(
              value: config.levelDbfs,
              min: -40,
              max: 0,
              divisions: 40,
              label: '${config.levelDbfs.round()}dBFS',
              onChanged: generator.setLevelDbfs,
            ),
            const Text(
              '⚠️ Niveau contrôlé pour protéger les enceintes et garder des comparaisons à niveau constant.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(SignalType type) => switch (type) {
    SignalType.sineSweepLog => 'Sweep logarithmique',
    SignalType.sineSweepLinear => 'Sweep linéaire',
    SignalType.pinkNoise => 'Bruit rose',
    SignalType.whiteNoise => 'Bruit blanc',
    SignalType.burst => 'Burst / rattle',
    SignalType.pureTone => 'Ton pur',
  };
}

class _MeasurementRunner extends StatelessWidget {
  const _MeasurementRunner();

  @override
  Widget build(BuildContext context) {
    final generator = context.watch<GeneratorController>();
    final measurement = context.watch<MeasurementController>();
    final isBusy =
        measurement.status == MeasurementStatus.measuring ||
        measurement.status == MeasurementStatus.analyzing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(isBusy ? 'Mesure en cours…' : 'Lancer la mesure'),
          onPressed: isBusy
              ? null
              : () {
                  measurement.setCalibrationCurve(
                    context.read<CalibrationController>().selected,
                  );
                  measurement.runMeasurement(generator.config);
                },
        ),
        const SizedBox(height: 8),
        _StatusLine(
          status: measurement.status,
          errorMessage: measurement.errorMessage,
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final MeasurementStatus status;
  final String? errorMessage;

  const _StatusLine({required this.status, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      MeasurementStatus.idle => ('Prêt.', Colors.grey),
      MeasurementStatus.permissionDenied => (
        'Permission micro refusée — active-la dans les réglages du téléphone.',
        Colors.red,
      ),
      MeasurementStatus.measuring => (
        'Un chirp de calibration puis le signal de test vont être joués et enregistrés…',
        Colors.blue,
      ),
      MeasurementStatus.analyzing => ('Analyse du signal…', Colors.blue),
      MeasurementStatus.done => ('Mesure terminée.', Colors.green),
      MeasurementStatus.error => ('Erreur: $errorMessage', Colors.red),
    };
    return Text(text, style: TextStyle(color: color));
  }
}

class _ResultView extends StatefulWidget {
  const _ResultView();

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  final _speakerModelCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _speakerModelCtrl.dispose();
    _positionCtrl.dispose();
    _distanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final measurement = context.watch<MeasurementController>();
    final response = measurement.lastFrequencyResponse;
    if (measurement.status != MeasurementStatus.done || response == null) {
      return const SizedBox.shrink();
    }
    final result = measurement.lastResult!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Résultat', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Confiance de synchronisation: ${(result.confidence * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: result.confidence > 0.5 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: FrequencyResponseChart(
                series: [
                  FrequencyResponseSeries(
                    label: 'Mesure',
                    response: response,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _speakerModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modèle d\'enceinte',
              ),
            ),
            TextField(
              controller: _positionCtrl,
              decoration: const InputDecoration(
                labelText: 'Position (ex: axe, 1m)',
              ),
            ),
            TextField(
              controller: _distanceCtrl,
              decoration: const InputDecoration(labelText: 'Distance (m)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Sauvegarder dans la bibliothèque'),
              onPressed: () async {
                final id = await measurement.saveToLibrary(
                  speakerModel: _speakerModelCtrl.text.trim().isEmpty
                      ? null
                      : _speakerModelCtrl.text.trim(),
                  position: _positionCtrl.text.trim().isEmpty
                      ? null
                      : _positionCtrl.text.trim(),
                  distanceM: double.tryParse(_distanceCtrl.text.trim()),
                  notes: _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim(),
                );
                if (id != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mesure sauvegardée.')),
                  );
                  measurement.reset();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
