import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_limits.dart';

void main() {
  group('SheetsWorkbookLimits', () {
    test('accepts the exact supported grid boundary', () {
      expect(() => SheetsWorkbookLimits.validate(1000, 100), returnsNormally);
      expect(() => SheetsWorkbookLimits.validate(30, 12), returnsNormally);
    });

    test('rejects oversized worksheets before import can replace saved data', () {
      expect(
        () => SheetsWorkbookLimits.validate(1001, 100),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SheetsWorkbookLimits.validate(1000, 101),
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
