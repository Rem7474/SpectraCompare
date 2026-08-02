import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_compare/core/storage/calibration_file_parser.dart';

void main() {
  group('CalibrationFileParser', () {
    test('parses a REW-style file with comments and tab/space delimiters', () {
      const contents = '''
* UMIK-1 calibration file
* Sens Factor =-32.995dB, SERNO: 12345
20\t1.20
100 0.50
1000\t0.00
20000  -3.10
''';
      final curve = CalibrationFileParser.parse(contents, name: 'UMIK-1');
      expect(curve.name, 'UMIK-1');
      expect(curve.points.length, 4);
      expect(curve.points.first.freqHz, 20);
      expect(curve.points.last.correctionDb, -3.10);
    });

    test('sorts points by frequency even if the file is out of order', () {
      const contents = '1000 0.0\n20 1.0\n500 0.5\n';
      final curve = CalibrationFileParser.parse(contents);
      expect(curve.points.map((p) => p.freqHz).toList(), [20, 500, 1000]);
    });

    test('skips comment lines starting with #, *, and ;', () {
      const contents = '# comment\n* comment\n; comment\n1000 0.0\n';
      final curve = CalibrationFileParser.parse(contents);
      expect(curve.points.length, 1);
    });

    test('ignores malformed rows instead of throwing', () {
      const contents = 'not a number here\n1000 0.0\nfoo bar baz\n';
      final curve = CalibrationFileParser.parse(contents);
      expect(curve.points.length, 1);
    });

    test('throws FormatException when no valid rows are found', () {
      expect(
        () => CalibrationFileParser.parse('# just a comment\n'),
        throwsFormatException,
      );
    });
  });
}
