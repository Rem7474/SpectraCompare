import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/dsp/octave_bands.dart';
import '../../core/models/frequency_response.dart';
import '../../core/storage/export_service.dart';
import '../../widgets/frequency_response_chart.dart';
import 'comparison_controller.dart';

const _palette = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
];

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  bool _isDeltaMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComparisonController>().load();
    });
  }

  FrequencyResponse _calculateDelta(
    FrequencyResponse target,
    FrequencyResponse reference,
  ) {
    if (target.points.isEmpty || reference.points.isEmpty) {
      return const FrequencyResponse([]);
    }

    final deltaPoints = <FrequencyResponsePoint>[];
    for (final refPoint in reference.points) {
      // Find closest point in target
      var best = target.points.first;
      var bestDist = (best.freqHz - refPoint.freqHz).abs();
      for (final p in target.points) {
        final dist = (p.freqHz - refPoint.freqHz).abs();
        if (dist < bestDist) {
          best = p;
          bestDist = dist;
        }
      }
      // If within 10% frequency tolerance, compute delta
      if (bestDist / refPoint.freqHz < 0.15) {
        deltaPoints.add(
          FrequencyResponsePoint(
            refPoint.freqHz,
            best.magnitudeDb - refPoint.magnitudeDb,
          ),
        );
      }
    }
    return FrequencyResponse(deltaPoints);
  }

  @override
  Widget build(BuildContext context) {
    final comparison = context.watch<ComparisonController>();
    final selected = comparison.selectedMeasurements;
    final reference = comparison.reference;

    final chartSeries = <FrequencyResponseSeries>[];
    if (!_isDeltaMode || reference == null) {
      for (int i = 0; i < selected.length; i++) {
        chartSeries.add(
          FrequencyResponseSeries(
            label: selected[i].displayName,
            response: selected[i].frequencyResponse,
            color: _palette[i % _palette.length],
          ),
        );
      }
    } else {
      // Delta mode: Reference is 0 dB reference line
      chartSeries.add(
        FrequencyResponseSeries(
          label: '${reference.displayName} (Réf 0 dB)',
          response: FrequencyResponse([
            for (final p in reference.frequencyResponse.points)
              FrequencyResponsePoint(p.freqHz, 0.0),
          ]),
          color: Colors.cyanAccent,
          strokeWidth: 2.0,
          isDashed: true,
        ),
      );

      for (int i = 0; i < selected.length; i++) {
        final m = selected[i];
        if (m.id == reference.id) continue;
        final deltaResponse = _calculateDelta(
          m.frequencyResponse,
          reference.frequencyResponse,
        );
        chartSeries.add(
          FrequencyResponseSeries(
            label: 'Δ ${m.displayName}',
            response: deltaResponse,
            color: _palette[i % _palette.length],
            strokeWidth: 2.2,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparaison'),
        actions: [
          if (selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () => Share.share(
                ExportService.comparisonToCsv(selected),
                subject: 'comparaison.csv',
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: ListView(
                children: [
                  for (int i = 0; i < comparison.available.length; i++)
                    Builder(
                      builder: (context) {
                        final m = comparison.available[i];
                        final isSelected = comparison.selectedIds.contains(
                          m.id,
                        );
                        final color = isSelected
                            ? _palette[selected.indexWhere(
                                    (s) => s.id == m.id,
                                  ) %
                                  _palette.length]
                            : Colors.grey;

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => comparison.toggleSelected(m.id!),
                          secondary: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            m.displayName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: isSelected
                              ? RadioGroup<int>(
                                  groupValue: comparison.referenceId,
                                  onChanged: (id) =>
                                      comparison.setReference(id!),
                                  child: Row(
                                    children: [
                                      Radio<int>(value: m.id!),
                                      const Text('Référence'),
                                    ],
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (selected.length > 1 && reference != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Superposition'),
                      icon: Icon(Icons.layers_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Delta (vs Réf 0dB)'),
                      icon: Icon(Icons.compare),
                    ),
                  ],
                  selected: {_isDeltaMode},
                  onSelectionChanged: (s) =>
                      setState(() => _isDeltaMode = s.first),
                ),
              ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: selected.isEmpty
                    ? const Center(
                        child: Text('Sélectionne au moins une mesure.'),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: FrequencyResponseChart(
                              series: chartSeries,
                              zeroReferenceLine: _isDeltaMode ? 0.0 : null,
                            ),
                          ),
                          if (reference != null &&
                              selected.length > 1 &&
                              !_isDeltaMode) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Delta vs. ${reference.displayName}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            SizedBox(
                              height: 85,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final m in selected)
                                    if (m.id != reference.id)
                                      _DeltaSummary(
                                        label: m.displayName,
                                        deltaByBand:
                                            OctaveBands.deltaVsReference(
                                              m.frequencyResponse,
                                              reference.frequencyResponse,
                                            ),
                                      ),
                                ],
                              ),
                            ),
                          ],
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

class _DeltaSummary extends StatelessWidget {
  final String label;
  final Map<double, double> deltaByBand;

  const _DeltaSummary({required this.label, required this.deltaByBand});

  @override
  Widget build(BuildContext context) {
    if (deltaByBand.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Text('$label: aucune bande commune'),
      );
    }
    final avg = deltaByBand.values.reduce((a, b) => a + b) / deltaByBand.length;
    final maxAbs = deltaByBand.values
        .map((v) => v.abs())
        .reduce((a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Δ moyen: ${avg.toStringAsFixed(1)}dB'),
          Text('Δ max: ${maxAbs.toStringAsFixed(1)}dB'),
        ],
      ),
    );
  }
}
