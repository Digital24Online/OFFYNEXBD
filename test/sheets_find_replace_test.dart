import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_find_replace.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';

void main() {
  group('SheetsFindReplace', () {
    test('replaces literal text across every worksheet and preserves styles', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 10,
            columns: 4,
            cells: {'A1': 'Hello hello', 'B1': 'HELLO!', 'C1': 'unrelated'},
            styles: {'A1': {'bold': true}},
          ),
          SheetsWorksheet(
            id: 'two',
            name: 'Two',
            rows: 10,
            columns: 4,
            cells: {'A1': 'hello'},
          ),
        ],
      );

      final count = SheetsFindReplace.replaceInWorkbook(
        workbook,
        find: 'hello',
        replacement: 'বাংলা',
      );

      expect(count, 4);
      expect(workbook.sheets[0].cells, {
        'A1': 'বাংলা বাংলা',
        'B1': 'বাংলা!',
        'C1': 'unrelated',
      });
      expect(workbook.sheets[1].cells['A1'], 'বাংলা');
      expect(workbook.sheets[0].styles['A1'], {'bold': true});
    });

    test('supports case-sensitive matching and empty replacement', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 5,
            columns: 2,
            cells: {'A1': 'Cat cat'},
          ),
        ],
      );

      expect(
        SheetsFindReplace.replaceInWorkbook(
          workbook,
          find: 'Cat',
          replacement: '',
          matchCase: true,
        ),
        1,
      );
      expect(workbook.activeSheet.cells['A1'], ' cat');
    });

    test('treats replacement dollar signs and regex symbols literally', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 5,
            columns: 2,
            cells: {'A1': 'a+b a+b'},
          ),
        ],
      );

      expect(
        SheetsFindReplace.replaceInWorkbook(
          workbook,
          find: 'a+b',
          replacement: r'$1[ok]',
        ),
        2,
      );
      expect(workbook.activeSheet.cells['A1'], r'$1[ok] $1[ok]');
    });


    test('keeps formulas safe unless formula replacement is explicitly enabled', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'One',
            rows: 5,
            columns: 3,
            cells: {
              'A1': 'Sales',
              'B1': '=SUM(A1:A3)',
              'C1': '=IF(A1="Sales",1,0)',
            },
          ),
        ],
      );

      expect(
        SheetsFindReplace.replaceInWorkbook(
          workbook,
          find: 'A1',
          replacement: 'B1',
        ),
        0,
      );
      expect(workbook.activeSheet.cells['B1'], '=SUM(A1:A3)');

      expect(
        SheetsFindReplace.replaceInWorkbook(
          workbook,
          find: 'A1',
          replacement: 'B1',
          includeFormulas: true,
        ),
        2,
      );
      expect(workbook.activeSheet.cells['B1'], '=SUM(B1:A3)');
      expect(workbook.activeSheet.cells['C1'], '=IF(B1="Sales",1,0)');
    });

    test('rejects an empty search string', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(id: 'one', name: 'One', rows: 1, columns: 1),
        ],
      );
      expect(
        () => SheetsFindReplace.replaceInWorkbook(
          workbook,
          find: '',
          replacement: 'x',
        ),
        throwsArgumentError,
      );
    });
  });
}
