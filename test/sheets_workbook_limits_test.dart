import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_limits.dart';

void main() {
  group('SheetsWorkbookLimits', () {
    test('accepts the Excel-compatible worksheet grid boundary', () {
      expect(() => SheetsWorkbookLimits.validate(1048576, 16384), returnsNormally);
      expect(() => SheetsWorkbookLimits.validate(30, 12), returnsNormally);
    });

    test('rejects dimensions beyond the Excel worksheet grid', () {
      expect(
        () => SheetsWorkbookLimits.validate(1048577, 100),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SheetsWorkbookLimits.validate(1048576, 16385),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts XLSX files up to the 20 MB import limit', () {
      expect(() => SheetsWorkbookLimits.validateImportBytes(0), returnsNormally);
      expect(() => SheetsWorkbookLimits.validateImportBytes(20 * 1024 * 1024), returnsNormally);
    });

    test('rejects XLSX files larger than 20 MB', () {
      expect(
        () => SheetsWorkbookLimits.validateImportBytes(20 * 1024 * 1024 + 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid negative dimensions', () {
      expect(
        () => SheetsWorkbookLimits.validate(-1, 12),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
