import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';

void main() {
  group('SheetsWorkbookCodec', () {
    test('round-trips multiple worksheets, styles and active sheet', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'budget',
        sheets: [
          SheetsWorksheet(
            id: 'main',
            name: 'Main',
            rows: 30,
            columns: 12,
            cells: {'A1': 'বাংলা', 'B2': '=SUM(B3:B5)'},
            styles: {'A1': {'bold': true, 'fillColor': 'D9EAD3'}},
          ),
          SheetsWorksheet(
            id: 'budget',
            name: 'Budget',
            rows: 50,
            columns: 8,
            cells: {'C4': '125.50'},
          ),
        ],
      );

      final decoded = SheetsWorkbookCodec.decode(
        SheetsWorkbookCodec.encode(workbook),
      );

      expect(decoded.activeSheetId, 'budget');
      expect(decoded.sheets, hasLength(2));
      expect(decoded.sheets.first.cells['A1'], 'বাংলা');
      expect(decoded.sheets.first.styles['A1']?['bold'], isTrue);
      expect(decoded.activeSheet.cells['C4'], '125.50');
    });

    test('migrates the existing single-sheet storage format without data loss', () {
      final decoded = SheetsWorkbookCodec.decode(
        '{"name":"Old Sheet","rows":40,"columns":9,'
        '"cells":{"A1":"existing","B2":"=SUM(A1:A2)"},'
        '"styles":{"A1":{"bold":true}}}',
      );

      expect(decoded.sheets, hasLength(1));
      expect(decoded.activeSheetId, SheetsWorkbookCodec.legacySheetId);
      expect(decoded.activeSheet.name, 'Old Sheet');
      expect(decoded.activeSheet.rows, 40);
      expect(decoded.activeSheet.columns, 9);
      expect(decoded.activeSheet.cells['A1'], 'existing');
      expect(decoded.activeSheet.cells['B2'], '=SUM(A1:A2)');
      expect(decoded.activeSheet.styles['A1']?['bold'], isTrue);
    });

    test('rejects duplicate IDs, duplicate names and missing active sheet', () {
      final duplicateId = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(id: 'one', name: 'One', rows: 10, columns: 5),
          SheetsWorksheet(id: 'one', name: 'Two', rows: 10, columns: 5),
        ],
      );
      expect(() => SheetsWorkbookCodec.encode(duplicateId), throwsFormatException);

      final duplicateName = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(id: 'one', name: 'Same', rows: 10, columns: 5),
          SheetsWorksheet(id: 'two', name: 'same', rows: 10, columns: 5),
        ],
      );
      expect(() => SheetsWorkbookCodec.encode(duplicateName), throwsFormatException);

      final missingActive = SheetsWorkbook(
        activeSheetId: 'missing',
        sheets: [
          SheetsWorksheet(id: 'one', name: 'One', rows: 10, columns: 5),
        ],
      );
      expect(() => SheetsWorkbookCodec.encode(missingActive), throwsFormatException);
    });

    test('rejects invalid worksheet names, cell bounds and dimensions', () {
      expect(
        () => SheetsWorkbookCodec.encode(SheetsWorkbook(
          activeSheetId: 'one',
          sheets: [SheetsWorksheet(id: 'one', name: 'Bad/Name', rows: 10, columns: 5)],
        )),
        throwsFormatException,
      );

      expect(
        () => SheetsWorkbookCodec.decode(
          '{"format":"OFFYNEXBD_SHEETS_WORKBOOK","version":2,'
          '"activeSheetId":"one","sheets":[{"id":"one","name":"One",'
          '"rows":10,"columns":5,"cells":{"F1":"outside"},'
          '"styles":{}}]}',
        ),
        throwsFormatException,
      );
    });

    test('round-trips Freeze Top Row and defaults it off for old workbooks', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 10,
            columns: 5,
            freezeTopRow: true,
          ),
        ],
      );
      final decoded = SheetsWorkbookCodec.decode(SheetsWorkbookCodec.encode(workbook));
      expect(decoded.activeSheet.freezeTopRow, isTrue);

      final legacy = SheetsWorkbookCodec.decode(
        '{"name":"Old","rows":10,"columns":5,"cells":{},"styles":{}}',
      );
      expect(legacy.activeSheet.freezeTopRow, isFalse);
    });

    test('rejects an invalid Freeze Top Row setting without losing workbook data', () {
      expect(
        () => SheetsWorkbookCodec.decode(
          '{"format":"OFFYNEXBD_SHEETS_WORKBOOK","version":2,'
          '"activeSheetId":"one","sheets":[{"id":"one","name":"One",'
          '"rows":10,"columns":5,"cells":{},"styles":{},'
          '"freezeTopRow":"yes"}]}',
        ),
        throwsFormatException,
      );
    });

    test('round-trips per-cell dropdown validation rules', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 10,
            columns: 5,
            validations: {'B2': ['Pending', 'Paid', 'Due']},
          ),
        ],
      );
      final decoded = SheetsWorkbookCodec.decode(SheetsWorkbookCodec.encode(workbook));
      expect(decoded.activeSheet.validations['B2'], ['Pending', 'Paid', 'Due']);
    });

    test('rejects dropdown rules outside bounds, empty and duplicate options', () {
      String raw(String key, String options) =>
          '{"format":"OFFYNEXBD_SHEETS_WORKBOOK","version":2,'
          '"activeSheetId":"one","sheets":[{"id":"one","name":"One",'
          '"rows":10,"columns":5,"cells":{},"styles":{},'
          '"validations":{"$key":$options}}]}';
      expect(() => SheetsWorkbookCodec.decode(raw('F1', '["A"]')), throwsFormatException);
      expect(() => SheetsWorkbookCodec.decode(raw('A1', '[]')), throwsFormatException);
      expect(() => SheetsWorkbookCodec.decode(raw('A1', '["A","A"]')), throwsFormatException);
    });

    test('rejects oversized workbook input before JSON decoding', () {
      final oversized = ''.padRight(
        SheetsWorkbookCodec.maxWorkbookBytes + 1,
        'x',
      );
      expect(() => SheetsWorkbookCodec.decode(oversized), throwsFormatException);
    });

    test('round-trips charts, conditional formatting and Pivot source metadata', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'pivot',
        sheets: [
          SheetsWorksheet(
            id: 'source',
            name: 'Source',
            rows: 20,
            columns: 5,
            cells: {'A1': 'Region', 'B1': 'Sales'},
            conditionalFormats: [
              {
                'range': 'B2:B20',
                'operator': 'greaterThan',
                'value': '100',
                'fillColor': 'D9EAD3',
                'fontColor': '1B5E20',
              },
            ],
            charts: [
              {'type': 'bar', 'title': 'Sales by region', 'range': 'A1:B20'},
              {'type': 'line', 'title': 'Trend', 'range': 'A1:C20'},
            ],
          ),
          SheetsWorksheet(
            id: 'pivot',
            name: 'Pivot Table',
            rows: 3,
            columns: 2,
            cells: {'A1': 'Region', 'B1': 'SUM of Sales'},
            pivotConfig: {
              'sourceSheetId': 'source',
              'range': 'A1:B20',
              'groupColumn': 'A',
              'valueColumn': 'B',
              'aggregation': 'sum',
            },
          ),
        ],
      );

      final decoded = SheetsWorkbookCodec.decode(
        SheetsWorkbookCodec.encode(workbook),
      );
      expect(decoded.sheets.first.conditionalFormats, hasLength(1));
      expect(decoded.sheets.first.charts, hasLength(2));
      expect(decoded.activeSheet.pivotConfig?['sourceSheetId'], 'source');
      expect(decoded.activeSheet.pivotConfig?['aggregation'], 'sum');
    });

    test('rejects invalid chart and Pivot metadata during workbook decode', () {
      final invalidChart = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 10,
            columns: 5,
            charts: [{'type': 'pie', 'title': 'Bad', 'range': 'A1:B5'}],
          ),
        ],
      );
      expect(() => SheetsWorkbookCodec.encode(invalidChart), returnsNormally);
      expect(
        () => SheetsWorkbookCodec.decode(SheetsWorkbookCodec.encode(invalidChart)),
        throwsFormatException,
      );

      final invalidPivot = SheetsWorkbook(
        activeSheetId: 'pivot',
        sheets: [
          SheetsWorksheet(
            id: 'pivot',
            name: 'Pivot',
            rows: 2,
            columns: 2,
            pivotConfig: {
              'sourceSheetId': 'source',
              'range': 'A1:B5',
              'groupColumn': 'A',
              'valueColumn': 'B',
              'aggregation': 'median',
            },
          ),
        ],
      );
      expect(
        () => SheetsWorkbookCodec.decode(SheetsWorkbookCodec.encode(invalidPivot)),
        throwsFormatException,
      );

      final missingSource = SheetsWorkbook(
        activeSheetId: 'pivot',
        sheets: [
          SheetsWorksheet(
            id: 'pivot',
            name: 'Pivot',
            rows: 2,
            columns: 2,
            pivotConfig: {
              'sourceSheetId': 'deleted-source',
              'range': 'A1:B5',
              'groupColumn': 'A',
              'valueColumn': 'B',
              'aggregation': 'sum',
            },
          ),
        ],
      );
      expect(
        () => SheetsWorkbookCodec.decode(SheetsWorkbookCodec.encode(missingSource)),
        throwsFormatException,
      );
    });

    test('rejects oversized workbook exports without changing the source', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 10,
            columns: 5,
            cells: {'A1': ''.padRight(SheetsWorkbookCodec.maxWorkbookBytes, 'x')},
          ),
        ],
      );
      expect(() => SheetsWorkbookCodec.encode(workbook), throwsFormatException);
      expect(workbook.activeSheet.cells['A1']?.length, SheetsWorkbookCodec.maxWorkbookBytes);
    });

  });
}
