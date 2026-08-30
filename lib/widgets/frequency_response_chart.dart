import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/dsp/smoothing.dart';
import '../core/models/frequency_response.dart';

class FrequencyResponseSeries {
  final String label;
  final FrequencyResponse response;
  final Color color;
  final double strokeWidth;
  final bool isDashed;

  const FrequencyResponseSeries({
    required this.label,
    required this.response,
    required this.color,
    this.strokeWidth = 2.0,
    this.isDashed = false,
  });
}

/// Plots one or more frequency response curves, x-axis in log10(Hz).
/// Features interactive smoothing selector, note tooltips, and reference lines.
class FrequencyResponseChart extends StatefulWidget {
  final List<FrequencyResponseSeries> series;
  final bool showSmoothingSelector;
  final double? zeroReferenceLine;

  const FrequencyResponseChart({
    super.key,
    required this.series,
    this.showSmoothingSelector = true,
    this.zeroReferenceLine,
  });

  @override
  State<FrequencyResponseChart> createState() => _FrequencyResponseChartState();
}

class _FrequencyResponseChartState extends State<FrequencyResponseChart> {
  SmoothingType _smoothing = SmoothingType.none;

  static double _log10(double x) => x <= 0 ? 0 : (math.log(x) / math.ln10);
  static double _fromLog10(double x) => math.pow(10, x).toDouble();

  static String _formatFreq(double hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k';
    }
    return hz.toStringAsFixed(0);
  }

  static String _freqToMusicalNote(double freqHz) {
    if (freqHz < 20 || freqHz > 20000) return '';
    const noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    // MIDI note number: 69 is A4 (440 Hz)
    final midi = 69 + 12 * (math.log(freqHz / 440.0) / math.ln2);
    final roundedMidi = midi.round();
    final noteIndex = (roundedMidi % 12 + 12) % 12;
    final octave = (roundedMidi ~/ 12) - 1;
    return ' (${noteNames[noteIndex]}$octave)';
  }

  @override
  Widget build(BuildContext context) {
    final nonEmpty = widget.series
        .where((s) => s.response.points.isNotEmpty)
        .toList();
    if (nonEmpty.isEmpty) {
      return const Center(child: Text('Aucune donnée'));
    }

    double minY = double.infinity, maxY = double.negativeInfinity;
    double minX = double.infinity, maxX = double.negativeInfinity;
    final bars = <LineChartBarData>[];

    for (final s in nonEmpty) {
      final effectiveResponse = _smoothing == SmoothingType.none
          ? s.response
          : FrequencySmoothing.smooth(s.response, _smoothing);

      final spots = <FlSpot>[];
      for (final p in effectiveResponse.points) {
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
          barWidth: s.strokeWidth,
          dashArray: s.isDashed ? [6, 4] : null,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    if (widget.zeroReferenceLine != null) {
      minY = math.min(minY, widget.zeroReferenceLine!);
      maxY = math.max(maxY, widget.zeroReferenceLine!);
    }

    final yPad = math.max((maxY - minY).abs() * 0.12, 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showSmoothingSelector || nonEmpty.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (nonEmpty.length > 1)
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final s in nonEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (widget.showSmoothingSelector)
                  PopupMenuButton<SmoothingType>(
                    tooltip: 'Lissage de la courbe',
                    initialValue: _smoothing,
                    onSelected: (t) => setState(() => _smoothing = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_graph,
                            size: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _smoothing.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      for (final type in SmoothingType.values)
                        PopupMenuItem(
                          value: type,
                          child: Text(
                            type == SmoothingType.none
                                ? 'Brut (sans lissage)'
                                : 'Lissage ${type.label}',
                          ),
                        ),
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
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) {
                  if (widget.zeroReferenceLine != null &&
                      (value - widget.zeroReferenceLine!).abs() < 0.1) {
                    return const FlLine(
                      color: Colors.cyanAccent,
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                    );
                  }
                  return FlLine(
                    color: Colors.grey.withAlpha(50),
                    strokeWidth: 0.8,
                  );
                },
                getDrawingVerticalLine: (_) =>
                    FlLine(color: Colors.grey.withAlpha(50), strokeWidth: 0.8),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withAlpha(80)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.black87,
                  getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    final freq = _fromLog10(spot.x);
                    final note = _freqToMusicalNote(freq);
                    return LineTooltipItem(
                      '${_formatFreq(freq)}Hz$note\n${spot.y >= 0 ? '+' : ''}${spot.y.toStringAsFixed(1)} dB',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    );
                  }).toList(),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: math.max((maxX - minX) / 5, 0.001),
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        _formatFreq(_fromLog10(value)),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.round()}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
