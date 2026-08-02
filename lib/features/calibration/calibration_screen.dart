import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/mic_test_session.dart';
import '../../core/audio/player_service.dart';
import '../../core/audio/recorder_service.dart';
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
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Colle le contenu du fichier de calibration (format REW/miniDSP: '
                'fréquence, dB par ligne).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TextField(
                controller: contentsCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '20 1.2\n100 0.5\n1000 0.0\n...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.importFromText(
                contentsCtrl.text,
                nameCtrl.text.trim(),
              );
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
            const _MicTestCard(),
            const Divider(height: 1),
            Expanded(
              child: RadioGroup<CalibrationCurve?>(
                groupValue: calibration.selected,
                onChanged: (value) => calibration.select(value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RadioListTile<CalibrationCurve?>(
                      value: null,
                      title: Text('Aucune (mesures relatives, non calibrées)'),
                    ),
                    if (calibration.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          calibration.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final curve in calibration.curves)
                            RadioListTile<CalibrationCurve?>(
                              value: curve,
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
            ),
          ],
        ),
      ),
    );
  }
}

enum _MicTestStatus { idle, running, done, error }

/// Standalone "does the mic actually pick up what we play" check — see
/// `MicTestSession`. Kept local to this screen (no app-wide state needed):
/// `RecorderService`/`PlayerService` are only constructed lazily on the
/// first test run, so simply rendering this card never touches real audio
/// plugins (safe for widget tests).
class _MicTestCard extends StatefulWidget {
  const _MicTestCard();

  @override
  State<_MicTestCard> createState() => _MicTestCardState();
}

class _MicTestCardState extends State<_MicTestCard> {
  RecorderService? _recorderService;
  PlayerService? _playerService;
  _MicTestStatus _status = _MicTestStatus.idle;
  double? _levelDbFs;
  String? _error;

  Future<void> _run() async {
    final recorder = _recorderService ??= RecorderService();
    final player = _playerService ??= PlayerService();

    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      setState(() {
        _status = _MicTestStatus.error;
        _error = 'Permission micro refusée.';
      });
      return;
    }

    setState(() {
      _status = _MicTestStatus.running;
      _error = null;
    });

    try {
      final result = await MicTestSession(
        recorder: recorder,
        player: player,
      ).run();
      if (!mounted) return;
      setState(() {
        _levelDbFs = result.levelDbFs;
        _status = _MicTestStatus.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = _MicTestStatus.error;
      });
    }
  }

  Color _levelColor(double dbFs) {
    if (!dbFs.isFinite || dbFs < -50) return Colors.red;
    if (dbFs < -30) return Colors.orange;
    return Colors.green;
  }

  @override
  void dispose() {
    _playerService?.dispose();
    _recorderService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _status == _MicTestStatus.running;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test micro rapide',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Joue un ton court et fort, puis affiche le niveau réellement capté '
            'par le micro — utile pour comparer des réglages audio (Bluetooth, '
            'position...) sans lancer une mesure complète.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (_status == _MicTestStatus.done && _levelDbFs != null)
            Text(
              'Niveau capté : ${_levelDbFs!.isFinite ? '${_levelDbFs!.toStringAsFixed(0)}dBFS' : 'silence'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _levelColor(_levelDbFs!),
              ),
            ),
          if (_status == _MicTestStatus.error && _error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: running ? null : _run,
            icon: running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mic),
            label: Text(running ? 'Test en cours…' : 'Lancer le test'),
          ),
        ],
      ),
    );
  }
}
