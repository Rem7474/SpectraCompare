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

  String _levelAssessment(double dbFs) {
    if (!dbFs.isFinite || dbFs < -50) return 'Signal trop faible / Silence (Vérifier micro)';
    if (dbFs < -35) return 'Niveau faible (Rapprocher le micro ou monter le volume)';
    if (dbFs < -10) return 'Niveau optimal pour la mesure';
    if (dbFs < -2) return 'Niveau fort (Attention aux réflexions)';
    return 'Risque de saturation (Baisser le volume)';
  }

  Color _levelColor(double dbFs) {
    if (!dbFs.isFinite || dbFs < -50) return Colors.red;
    if (dbFs < -35) return Colors.orange;
    if (dbFs < -10) return Colors.green;
    if (dbFs < -2) return Colors.amber;
    return Colors.red;
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
    final level = _levelDbFs;
    // Map -60 dBFS .. 0 dBFS to 0.0 .. 1.0 for the visual meter
    final meterFraction = level != null && level.isFinite
        ? ((level + 60) / 60).clamp(0.0, 1.0)
        : 0.0;

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
            'par le micro — utile pour vérifier l\'absence d\'AEC et calibrer '
            'la distance sans lancer une mesure complète.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          if (_status == _MicTestStatus.done && level != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Niveau : ${level.isFinite ? '${level.toStringAsFixed(1)} dBFS' : 'Silence'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _levelColor(level),
                        ),
                      ),
                      Text(
                        _levelAssessment(level),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _levelColor(level),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          Container(color: Colors.grey.withAlpha(60)),
                          FractionallySizedBox(
                            widthFactor: meterFraction,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue,
                                    Colors.green,
                                    if (meterFraction > 0.7) Colors.amber,
                                    if (meterFraction > 0.9) Colors.red,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-60 dB', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text('-30 dB', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text('-10 dB', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text('0 dB', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_status == _MicTestStatus.error && _error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: running ? null : _run,
            icon: running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mic),
            label: Text(running ? 'Test en cours…' : 'Lancer le test micro'),
          ),
        ],
      ),
    );
  }
}
