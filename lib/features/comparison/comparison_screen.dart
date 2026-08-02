import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/dsp/octave_bands.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComparisonController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final comparison = context.watch<ComparisonController>();
    final selected = comparison.selectedMeasurements;
    final reference = comparison.reference;

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
                  for (final m in comparison.available)
                    CheckboxListTile(
                      value: comparison.selectedIds.contains(m.id),
                      onChanged: (_) => comparison.toggleSelected(m.id!),
                      title: Text(m.displayName),
                      subtitle: comparison.selectedIds.contains(m.id)
                          ? Row(
                              children: [
                                Radio<int>(
                                  value: m.id!,
                                  groupValue: comparison.referenceId,
                                  onChanged: (id) =>
                                      comparison.setReference(id!),
                                ),
                                const Text('Référence'),
                              ],
                            )
                          : null,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
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
                              series: [
                                for (int i = 0; i < selected.length; i++)
                                  FrequencyResponseSeries(
                                    label: selected[i].displayName,
                                    response: selected[i].frequencyResponse,
                                    color: _palette[i % _palette.length],
                                  ),
                              ],
                            ),
                          ),
                          if (reference != null && selected.length > 1) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Delta vs. ${reference.displayName}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            SizedBox(
                              height: 80,
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
