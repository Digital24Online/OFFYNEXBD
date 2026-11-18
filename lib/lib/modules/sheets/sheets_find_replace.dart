import 'sheets_workbook_codec.dart';

/// Applies a literal find-and-replace operation to every cell in a workbook.
/// Cell styles and worksheet metadata are intentionally left untouched.
class SheetsFindReplace {
  static int replaceInWorkbook(
    SheetsWorkbook workbook, {
    required String find,
    required String replacement,
    bool matchCase = false,
  }) {
    if (find.isEmpty) {
      throw ArgumentError.value(find, 'find', 'Must not be empty.');
    }

    final pattern = RegExp(RegExp.escape(find), caseSensitive: matchCase);
    var replacements = 0;
    for (final sheet in workbook.sheets) {
      for (final entry in sheet.cells.entries.toList()) {
        final matches = pattern.allMatches(entry.value).length;
        if (matches == 0) continue;
        sheet.cells[entry.key] = entry.value.replaceAllMapped(
          pattern,
          (_) => replacement,
        );
        replacements += matches;
      }
    }
    return replacements;
  }
}
