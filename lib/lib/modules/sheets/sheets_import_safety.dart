import 'package:shared_preferences/shared_preferences.dart';

/// Preserves the current single-sheet workbook before a destructive XLSX import.
class SheetsImportSafety {
  static Future<String?> preserveCurrentWorkbook(
    SharedPreferences preferences,
    String? rawWorkbook, {
    int? timestamp,
  }) async {
    if (rawWorkbook == null) return null;
    final key = 'offynex_sheets_import_backup_'
        '${timestamp ?? DateTime.now().microsecondsSinceEpoch}';
    final saved = await preferences.setString(key, rawWorkbook);
    if (!saved) {
      throw StateError(
        'The existing workbook could not be backed up. Import was cancelled.',
      );
    }
    return key;
  }
}
