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
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow),
          label: Text(
            isBusy ? 'Mesure en cours…' : 'Lancer la mesure',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: isBusy
              ? null
              : () {
                  measurement.setCalibrationCurve(
                    context.read<CalibrationController>().selected,
                  );
                  measurement.runMeasurement(generator.config);
                },
        ),
        if (isBusy) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: measurement.progress > 0 ? measurement.progress : null,
              minHeight: 6,
            ),
          ),
        ],
        const SizedBox(height: 10),
        _StatusLine(
          phase: measurement.phase,
          errorMessage: measurement.errorMessage,
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final MeasurementPhase phase;
  final String? errorMessage;

  const _StatusLine({required this.phase, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (phase) {
      MeasurementPhase.idle => ('Prêt.', Colors.grey, Icons.info_outline),
      MeasurementPhase.permissionDenied => (
        'Permission micro refusée — active-la dans les réglages.',
        Colors.red,
        Icons.mic_off,
      ),
      MeasurementPhase.warmUp => (
        phase.description,
        Colors.blue,
        Icons.hourglass_top,
      ),
      MeasurementPhase.playingAndRecording => (
        phase.description,
        Colors.orange,
        Icons.graphic_eq,
      ),
      MeasurementPhase.analyzing => (
        phase.description,
        Colors.purple,
        Icons.analytics_outlined,
      ),
      MeasurementPhase.done => ('Mesure terminée avec succès.', Colors.green, Icons.check_circle_outline),
      MeasurementPhase.error => ('Erreur: ${errorMessage ?? "Inconnue"}', Colors.red, Icons.error_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Résultat', style: Theme.of(context).textTheme.titleMedium),
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
