import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Renders a scrolling time/frequency heatmap from log-spaced dB columns
/// (oldest first). Deliberately simple (no interpolation) — the app's own
/// downsampling (`AnalyzerController._downsampleLog`) already keeps the grid
/// small enough to redraw every frame.
class SpectrogramPainter extends CustomPainter {
  final List<Float64List> columns;
  final double minDb;
  final double maxDb;

  SpectrogramPainter({required this.columns, this.minDb = -80, this.maxDb = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (columns.isEmpty) return;
    final colCount = columns.length;
    final binCount = columns.first.length;
    if (binCount == 0) return;
    final colWidth = size.width / colCount;
    final rowHeight = size.height / binCount;
    final paint = Paint();

    for (int c = 0; c < colCount; c++) {
      final col = columns[c];
      for (int b = 0; b < binCount; b++) {
        final t = ((col[b] - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
        paint.color = _colorFor(t);
        final y = size.height - (b + 1) * rowHeight;
        canvas.drawRect(Rect.fromLTWH(c * colWidth, y, colWidth + 1, rowHeight + 1), paint);
      }
    }
  }

  Color _colorFor(double t) {
    if (t < 0.5) {
      return Color.lerp(const Color(0xFF0D1B4C), Colors.cyan, t * 2)!;
    }
    return Color.lerp(Colors.cyan, Colors.red, (t - 0.5) * 2)!;
  }

  @override
  bool shouldRepaint(covariant SpectrogramPainter oldDelegate) => true;
}
