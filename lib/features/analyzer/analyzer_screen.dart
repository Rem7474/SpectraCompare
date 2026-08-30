import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/frequency_response.dart';
import '../../widgets/frequency_response_chart.dart';
import 'analyzer_controller.dart';
import 'spectrogram_painter.dart';

class AnalyzerScreen extends StatelessWidget {
  const AnalyzerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final analyzer = context.watch<AnalyzerController>();
    final spectrum = analyzer.latestSpectrum;
    final peakSpectrum = analyzer.peakHoldSpectrum;

    final liveResponse = spectrum == null
        ? const FrequencyResponse([])
        : FrequencyResponse([
            for (int i = 0; i < spectrum.freqsHz.length; i++)
              FrequencyResponsePoint(
                spectrum.freqsHz[i],
                spectrum.magnitudesDb[i],
              ),
          ]);

    final peakResponse = peakSpectrum == null
        ? const FrequencyResponse([])
        : FrequencyResponse([
            for (int i = 0; i < peakSpectrum.freqsHz.length; i++)
              FrequencyResponsePoint(
                peakSpectrum.freqsHz[i],
                peakSpectrum.magnitudesDb[i],
              ),
          ]);

    final series = <FrequencyResponseSeries>[
      FrequencyResponseSeries(
        label: 'Live',
        response: liveResponse,
        color: Theme.of(context).colorScheme.primary,
      ),
      if (peakSpectrum != null)
        FrequencyResponseSeries(
          label: 'Peak Hold',
          response: peakResponse,
          color: Colors.amber.shade700,
          strokeWidth: 1.5,
          isDashed: true,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyseur'),
        actions: [
          if (analyzer.isRunning)
            IconButton(
              tooltip: 'Réinitialiser les crêtes (Peak Hold)',
              icon: const Icon(Icons.restart_alt),
              onPressed: analyzer.resetPeakHold,
            ),
          IconButton(
            icon: Icon(analyzer.isRunning ? Icons.stop : Icons.mic),
            onPressed: () =>
                analyzer.isRunning ? analyzer.stop() : analyzer.start(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Spectre 20Hz–20kHz',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: FrequencyResponseChart(
                  series: series,
                  showSmoothingSelector: false,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spectrogramme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (analyzer.isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: analyzer.isPaused
                            ? Colors.orange.withAlpha(40)
                            : Colors.green.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        analyzer.isPaused ? 'FIGÉ' : 'EN DIRECT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: analyzer.isPaused ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('20k', style: TextStyle(fontSize: 8, color: Colors.grey)),
                          Text('1k', style: TextStyle(fontSize: 8, color: Colors.grey)),
                          Text('20', style: TextStyle(fontSize: 8, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: CustomPaint(
                            painter: SpectrogramPainter(
                              columns: analyzer.spectrogramColumns,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!analyzer.isRunning)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Appuie sur le micro pour démarrer l\'analyse en direct.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: analyzer.isRunning ? Colors.red.shade700 : null,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(analyzer.isRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        analyzer.isRunning ? 'Arrêter' : 'Démarrer l\'analyse',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => analyzer.isRunning ? analyzer.stop() : analyzer.start(),
                    ),
                  ),
                  if (analyzer.isRunning) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(analyzer.isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(analyzer.isPaused ? 'Reprendre' : 'Figer'),
                        onPressed: analyzer.togglePause,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
