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

  group('Writer merged-cell structure after row/column edits', () {
    const merged = <Map<String, int>>[
      <String, int>{
        'row': 1,
        'column': 1,
        'rowSpan': 2,
        'columnSpan': 2,
      },
    ];

    test('inserting before a merged range moves its anchor', () {
      expect(
        WriterTableBlockEmbed.insertRowInMerges(
          merged,
          rowCount: 4,
          columnCount: 4,
          index: 1,
        ).single,
        <String, int>{
          'row': 2,
          'column': 1,
          'rowSpan': 2,
          'columnSpan': 2,
        },
      );
    });

    test('inserting inside a merged range expands its span', () {
      expect(
        WriterTableBlockEmbed.insertRowInMerges(
          merged,
          rowCount: 4,
          columnCount: 4,
          index: 2,
        ).single['rowSpan'],
        3,
      );
      expect(
        WriterTableBlockEmbed.insertColumnInMerges(
          merged,
          rowCount: 4,
          columnCount: 4,
          index: 2,
        ).single['columnSpan'],
        3,
      );
    });

    test('removing the anchor row or column preserves the remaining merged cells', () {
      expect(
        WriterTableBlockEmbed.removeRowFromMerges(
          merged,
          rowCount: 4,
          columnCount: 4,
          index: 1,
        ).single,
        <String, int>{
          'row': 1,
          'column': 1,
          'rowSpan': 1,
          'columnSpan': 2,
        },
      );
      expect(
        WriterTableBlockEmbed.removeColumnFromMerges(
          merged,
          rowCount: 4,
          columnCount: 4,
          index: 1,
        ).single,
        <String, int>{
          'row': 1,
          'column': 1,
          'rowSpan': 2,
          'columnSpan': 1,
        },
      );
    });

    test('removing before a merged range shifts its anchor', () {
      expect(
        WriterTableBlockEmbed.removeRowFromMerges(
          merged,
          rowCount: 4,
          columnCount: 4,
          index: 0,
        ).single['row'],
        0,
      );
      expect(
        WriterTableBlockEmbed.removeColumnFromMerges(
          merged,
          rowCount: 4,
          columnCount: 4,
          index: 0,
        ).single['column'],
        0,
      );
    });

    test('removing the only row or column in a merged range drops the merge', () {
      const singleCellMerge = <Map<String, int>>[
        <String, int>{
          'row': 1,
          'column': 1,
          'rowSpan': 1,
          'columnSpan': 2,
        },
      ];
      expect(
        WriterTableBlockEmbed.removeRowFromMerges(
          singleCellMerge,
          rowCount: 3,
          columnCount: 3,
          index: 1,
        ),
        isEmpty,
      );
      const singleColumnMerge = <Map<String, int>>[
        <String, int>{
          'row': 1,
          'column': 1,
          'rowSpan': 2,
          'columnSpan': 1,
        },
      ];
      expect(
        WriterTableBlockEmbed.removeColumnFromMerges(
          singleColumnMerge,
          rowCount: 3,
          columnCount: 3,
          index: 1,
        ),
        isEmpty,
      );
    });
  });

  group('Writer merged-cell anchor text preservation', () {
    test('deleting a vertical merge anchor transfers and joins its text', () {
      final transfers = WriterTableBlockEmbed.rowAnchorTextTransfers(
        cellTexts: <List<String>>[['top anchor'], ['existing lower text'], ['']],
        merges: const <Map<String, int>>[{'row': 0, 'column': 0, 'rowSpan': 3, 'columnSpan': 1}],
        removedRow: 0,
      );
      expect(transfers, hasLength(1));
      expect(transfers.single.row, 1);
      expect(transfers.single.column, 0);
      expect(transfers.single.text, 'top anchor\nexisting lower text');
    });
    test('deleting a horizontal merge anchor transfers and joins its text', () {
      final transfers = WriterTableBlockEmbed.columnAnchorTextTransfers(
        cellTexts: <List<String>>[['left anchor', 'existing right text', ''], ['', '', '']],
        merges: const <Map<String, int>>[{'row': 0, 'column': 0, 'rowSpan': 1, 'columnSpan': 2}],
        removedColumn: 0,
      );
      expect(transfers, hasLength(1));
      expect(transfers.single.row, 0);
      expect(transfers.single.column, 1);
      expect(transfers.single.text, 'left anchor\nexisting right text');
    });
    test('does not create empty transfers', () {
      final transfers = WriterTableBlockEmbed.rowAnchorTextTransfers(
        cellTexts: <List<String>>[[''], ['keep']],
        merges: const <Map<String, int>>[{'row': 0, 'column': 0, 'rowSpan': 2, 'columnSpan': 1}],
        removedRow: 0,
      );
      expect(transfers, isEmpty);
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
      expect((merged['rows'] as List)[0][0], 'A\nB\nD\nE');
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
      expect((split['rows'] as List)[0][0], 'A\nB');
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
