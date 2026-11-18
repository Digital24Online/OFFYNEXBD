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

    test('rejects oversized workbook input before JSON decoding', () {
      final oversized = ''.padRight(
        SheetsWorkbookCodec.maxWorkbookBytes + 1,
        'x',
      );
      expect(() => SheetsWorkbookCodec.decode(oversized), throwsFormatException);
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
