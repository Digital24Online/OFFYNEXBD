import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_table.dart';

void main() {
  group('Writer table header-row metadata', () {
    test('defaults older tables to a header row', () {
      expect(
        WriterTableBlockEmbed.hasHeaderRow(const <String, dynamic>{'rows': []}),
        isTrue,
      );
    });

    test('preserves an explicit header row setting', () {
      expect(
        WriterTableBlockEmbed.hasHeaderRow(const <String, dynamic>{
          'rows': [],
          'headerRow': false,
        }),
        isFalse,
      );
      expect(
        WriterTableBlockEmbed.hasHeaderRow(const <String, dynamic>{
          'rows': [],
          'headerRow': true,
        }),
        isTrue,
      );
    });
  });

  group('Writer merged-cell model', () {
    const table = <String, dynamic>{
      'rows': <List<String>>[
        <String>['A', 'B', 'C'],
        <String>['D', 'E', 'F'],
      ],
    };

    test('merges a rectangle and retains cell text in reading order', () {
      final merged = WriterTableBlockEmbed.mergeCells(table,
        firstRow: 0, firstColumn: 0, lastRow: 1, lastColumn: 1);
      expect((merged['rows'] as List)[0][0], 'A\\nB\\nD\\nE');
      expect(WriterTableBlockEmbed.normalizedMerges(merged,
        rowCount: 2, columnCount: 3), <Map<String, int>>[
        <String, int>{'row': 0, 'column': 0, 'rowSpan': 2, 'columnSpan': 2},
      ]);
      expect((merged['rows'] as List)[1], <String>['', '', 'F']);
    });

    test('rejects one-cell and out-of-bounds selections', () {
      expect(() => WriterTableBlockEmbed.mergeCells(table,
        firstRow: 0, firstColumn: 0, lastRow: 0, lastColumn: 0),
        throwsArgumentError);
      expect(() => WriterTableBlockEmbed.mergeCells(table,
        firstRow: 0, firstColumn: 0, lastRow: 3, lastColumn: 0),
        throwsArgumentError);
    });

    test('split removes span metadata without losing anchor text', () {
      final merged = WriterTableBlockEmbed.mergeCells(table,
        firstRow: 0, firstColumn: 0, lastRow: 0, lastColumn: 1);
      final split = WriterTableBlockEmbed.splitCell(merged, row: 0, column: 0);
      expect(split['merges'], isEmpty);
      expect((split['rows'] as List)[0][0], 'A\\nB');
    });

    test('ignores malformed, out-of-range and overlapping spans', () {
      final spans = WriterTableBlockEmbed.normalizedMerges(<String, dynamic>{
        'merges': <dynamic>[
          <String, int>{'row': 0, 'column': 0, 'rowSpan': 2, 'columnSpan': 2},
          <String, int>{'row': 1, 'column': 1, 'rowSpan': 1, 'columnSpan': 2},
          <String, int>{'row': 8, 'column': 0, 'rowSpan': 2, 'columnSpan': 1},
        ],
      }, rowCount: 2, columnCount: 3);
      expect(spans, hasLength(1));
    });
  });
}
