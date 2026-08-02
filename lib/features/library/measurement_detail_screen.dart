import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/measurement.dart';
import '../../core/storage/export_service.dart';
import '../../widgets/frequency_response_chart.dart';

class MeasurementDetailScreen extends StatelessWidget {
  final Measurement measurement;

  const MeasurementDetailScreen({super.key, required this.measurement});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(measurement.displayName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (choice) {
              if (choice == 'csv') {
                Share.share(
                  ExportService.frequencyResponseToCsv(measurement.frequencyResponse),
                  subject: '${measurement.displayName}.csv',
                );
              } else if (choice == 'json') {
                Share.share(
                  ExportService.measurementToJson(measurement),
                  subject: '${measurement.displayName}.json',
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'csv', child: Text('Exporter en CSV')),
              PopupMenuItem(value: 'json', child: Text('Exporter en JSON')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 260,
                child: FrequencyResponseChart(
                  series: [
                    FrequencyResponseSeries(
                      label: measurement.displayName,
                      response: measurement.frequencyResponse,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow('Enceinte', measurement.speakerModel ?? '—'),
              _InfoRow('Position', measurement.position ?? '—'),
              _InfoRow('Distance', measurement.distanceM != null ? '${measurement.distanceM}m' : '—'),
              _InfoRow('Niveau', '${measurement.outputLevelDbfs.round()}dBFS'),
              _InfoRow('Signal', measurement.signalConfig.type.name),
              _InfoRow(
                'Confiance sync',
                measurement.correlationConfidence != null
                    ? '${(measurement.correlationConfidence! * 100).clamp(0, 100).toStringAsFixed(0)}%'
                    : '—',
              ),
              _InfoRow('Date', measurement.createdAt.toString()),
              if (measurement.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    children: [for (final tag in measurement.tags) Chip(label: Text(tag))],
                  ),
                ),
              if (measurement.notes != null && measurement.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(measurement.notes!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
