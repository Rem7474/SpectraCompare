import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/models/frequency_response.dart';

class FrequencyResponseSeries {
  final String label;
  final FrequencyResponse response;
  final Color color;

  const FrequencyResponseSeries({required this.label, required this.response, required this.color});
}

/// Plots one or more frequency response curves, x-axis in log10(Hz) so a
/// 20Hz–20kHz sweep reads like a conventional (log-frequency) speaker
/// response chart, without needing a true log-scale axis from `fl_chart`.
class FrequencyResponseChart extends StatelessWidget {
  final List<FrequencyResponseSeries> series;

  const FrequencyResponseChart({super.key, required this.series});

  static double _log10(double x) => x <= 0 ? 0 : (math.log(x) / math.ln10);
  static double _fromLog10(double x) => math.pow(10, x).toDouble();

  static String _formatFreq(double hz) {
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k';
    return hz.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final nonEmpty = series.where((s) => s.response.points.isNotEmpty).toList();
    if (nonEmpty.isEmpty) {
      return const Center(child: Text('Aucune donnée'));
    }

    double minY = double.infinity, maxY = double.negativeInfinity;
    double minX = double.infinity, maxX = double.negativeInfinity;
    final bars = <LineChartBarData>[];
    for (final s in nonEmpty) {
      final spots = <FlSpot>[];
      for (final p in s.response.points) {
        final x = _log10(p.freqHz);
        spots.add(FlSpot(x, p.magnitudeDb));
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, p.magnitudeDb);
        maxY = math.max(maxY, p.magnitudeDb);
      }
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: s.color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    final yPad = math.max((maxY - minY).abs() * 0.1, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nonEmpty.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 12,
              children: [
                for (final s in nonEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, color: s.color),
                      const SizedBox(width: 4),
                      Text(s.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY - yPad,
              maxY: maxY + yPad,
              lineBarsData: bars,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: math.max((maxX - minX) / 5, 0.001),
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_formatFreq(_fromLog10(value)), style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
