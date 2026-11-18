import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_import_safety.dart';

void main() {
  group('SheetsImportSafety', () {
    test('preserves the exact current workbook before replacement', () async {
      const raw = '{"name":"Accounts","cells":{"A1":"রহিম"}}';
      SharedPreferences.setMockInitialValues({
        'offynex_sheets_workbook_v1': raw,
      });
      final prefs = await SharedPreferences.getInstance();
      final key = await SheetsImportSafety.preserveCurrentWorkbook(
        prefs,
        prefs.getString('offynex_sheets_workbook_v1'),
        timestamp: 12345,
      );
      expect(key, 'offynex_sheets_import_backup_12345');
      expect(prefs.getString(key!), raw);
      expect(prefs.getString('offynex_sheets_workbook_v1'), raw);
    });

    test('does not create a backup when no workbook exists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(
        await SheetsImportSafety.preserveCurrentWorkbook(prefs, null),
        isNull,
      );
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
