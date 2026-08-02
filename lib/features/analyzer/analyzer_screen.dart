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
    final response = spectrum == null
        ? const FrequencyResponse([])
        : FrequencyResponse([
            for (int i = 0; i < spectrum.freqsHz.length; i++)
              FrequencyResponsePoint(
                spectrum.freqsHz[i],
                spectrum.magnitudesDb[i],
              ),
          ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyseur'),
        actions: [
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
                  series: [
                    FrequencyResponseSeries(
                      label: 'Live',
                      response: response,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Spectrogramme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: CustomPaint(
                    painter: SpectrogramPainter(
                      columns: analyzer.spectrogramColumns,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!analyzer.isRunning)
                const Text(
                  'Appuie sur le micro pour démarrer l\'analyse en direct.',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
