import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_reference_guard.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';

void main() {
  group('SheetsReferenceGuard', () {
    test('protects a last row referenced by a formula on another worksheet', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'sales',
        sheets: [
          SheetsWorksheet(id: 'sales', name: 'Sales', rows: 30, columns: 8),
          SheetsWorksheet(
            id: 'summary',
            name: 'Summary',
            rows: 20,
            columns: 8,
            cells: {'A1': '=SUM(Sales!A1:A30)'},
          ),
        ],
      );

      expect(
        SheetsReferenceGuard.referencesRow(
          workbook: workbook,
          targetSheetId: 'sales',
          row: 30,
        ),
        isTrue,
      );
      expect(
        SheetsReferenceGuard.referencesRow(
          workbook: workbook,
          targetSheetId: 'sales',
          row: 29,
        ),
        isTrue,
      );
    });

    test('supports quoted worksheet names and absolute cell references', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'sales-data',
        sheets: [
          SheetsWorksheet(id: 'sales-data', name: 'Sales Data', rows: 30, columns: 8),
          SheetsWorksheet(
            id: 'summary',
            name: 'Summary',
            rows: 20,
            columns: 8,
            cells: {'A1': "=SUM('Sales Data'!\$B\$2:\$B\$30)"},
          ),
        ],
      );

      expect(
        SheetsReferenceGuard.referencesRow(
          workbook: workbook,
          targetSheetId: 'sales-data',
          row: 30,
        ),
        isTrue,
      );
      expect(
        SheetsReferenceGuard.referencesColumn(
          workbook: workbook,
          targetSheetId: 'sales-data',
          column: 2,
        ),
        isTrue,
      );
    });

    test('does not confuse unqualified references on another worksheet', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'sales',
        sheets: [
          SheetsWorksheet(id: 'sales', name: 'Sales', rows: 30, columns: 8),
          SheetsWorksheet(
            id: 'summary',
            name: 'Summary',
            rows: 20,
            columns: 8,
            cells: {'A1': '=SUM(A1:A30)'},
          ),
        ],
      );

      expect(
        SheetsReferenceGuard.referencesRow(
          workbook: workbook,
          targetSheetId: 'sales',
          row: 30,
        ),
        isFalse,
      );
    });

    test('protects chart, Pivot and conditional-format ranges', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'data',
        sheets: [
          SheetsWorksheet(
            id: 'data',
            name: 'Data',
            rows: 30,
            columns: 8,
            conditionalFormats: [
              {'range': 'A1:B30', 'operator': 'greaterThan', 'value': '0'},
            ],
            charts: [
              {'type': 'bar', 'title': 'Sales', 'range': 'A1:B30'},
            ],
          ),
          SheetsWorksheet(
            id: 'summary',
            name: 'Summary',
            rows: 30,
            columns: 8,
            pivotConfig: {
              'sourceSheetId': 'data',
              'range': 'A1:B30',
              'groupColumn': 'A',
              'valueColumn': 'B',
              'aggregation': 'sum',
            },
          ),
        ],
      );

      expect(
        SheetsReferenceGuard.referencesRow(
          workbook: workbook,
          targetSheetId: 'data',
          row: 30,
        ),
        isTrue,
      );
      expect(
        SheetsReferenceGuard.referencesColumn(
          workbook: workbook,
          targetSheetId: 'data',
          column: 2,
        ),
        isTrue,
      );
    });

    test('allows shrinking when no formulas or metadata refer to removed bounds', () {
      final workbook = SheetsWorkbook(
        activeSheetId: 'data',
        sheets: [
          SheetsWorksheet(id: 'data', name: 'Data', rows: 30, columns: 8),
          SheetsWorksheet(
            id: 'summary',
            name: 'Summary',
            rows: 20,
            columns: 8,
            cells: {'A1': '=SUM(A1:A10)'},
          ),
        ],
      );

      expect(
        SheetsReferenceGuard.referencesRow(
          workbook: workbook,
          targetSheetId: 'data',
          row: 30,
        ),
        isFalse,
      );
      expect(
        SheetsReferenceGuard.referencesColumn(
          workbook: workbook,
          targetSheetId: 'data',
          column: 8,
        ),
        isFalse,
      );
    });
  });
}
