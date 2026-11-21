import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_xlsx_export_guard.dart';

void main() {
  group('SheetsXlsxExportGuard', () {
    test('allows ordinary workbooks with supported cells and styles', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'Sheet1',
            rows: 20,
            columns: 10,
            cells: {'A1': 'Text', 'A2': '=SUM(B1:B3)'},
            styles: {'A1': {'bold': true}},
            validations: {'B1': ['Yes', 'No']},
          ),
        ],
      );
      expect(SheetsXlsxExportGuard.unsupportedFeatures(workbook), isEmpty);
    });

    test('blocks export when any worksheet contains charts, Pivot or conditional rules', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'one',
        sheets: [
          SheetsWorksheet(
            id: 'one',
            name: 'Sheet1',
            rows: 20,
            columns: 10,
            charts: [
              {'type': 'bar', 'title': 'Sales', 'range': 'A1:B5'},
            ],
            conditionalFormats: [
              {'range': 'A1:A5', 'operator': 'greaterThan', 'value': '0'},
            ],
          ),
          SheetsWorksheet(
            id: 'two',
            name: 'Sheet2',
            rows: 20,
            columns: 10,
            pivotConfig: {
              'sourceSheetId': 'one',
              'range': 'A1:B5',
              'groupColumn': 'A',
              'valueColumn': 'B',
              'aggregation': 'sum',
            },
          ),
        ],
      );
      expect(
        SheetsXlsxExportGuard.unsupportedFeatures(workbook),
        unorderedEquals(['charts', 'conditionalFormatting', 'pivotTables']),
      );
    });
  });
}
