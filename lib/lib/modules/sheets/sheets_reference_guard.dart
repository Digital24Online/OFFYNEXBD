import 'sheets_workbook_codec.dart';

/// Conservative guard for shrinking a worksheet's used row/column bounds.
/// It checks formulas in every worksheet, including qualified references to
/// the target sheet, and ranges owned by charts, pivots and conditional rules.
class SheetsReferenceGuard {
  const SheetsReferenceGuard._();

  static bool referencesRow({
    required SheetsWorkbook workbook,
    required String targetSheetId,
    required int row,
  }) {
    if (row < 1) return false;
    final target = workbook.sheets.where((sheet) => sheet.id == targetSheetId);
    if (target.isEmpty) return false;
    final targetSheet = target.first;

    for (final sheet in workbook.sheets) {
      for (final formula in sheet.cells.values.where((value) => value.startsWith('='))) {
        if (sheet.id == targetSheetId) {
          if (_referencesRow(formula, row)) return true;
        } else if (_qualifiedReferences(
          formula,
          targetSheet.name,
          (references) => _referencesRow(references, row),
        )) {
          return true;
        }
      }
    }

    for (final range in _metadataRanges(targetSheet)) {
      if (_referencesRow(range, row)) return true;
    }
    return false;
  }

  static bool referencesColumn({
    required SheetsWorkbook workbook,
    required String targetSheetId,
    required int column,
  }) {
    if (column < 1) return false;
    final target = workbook.sheets.where((sheet) => sheet.id == targetSheetId);
    if (target.isEmpty) return false;
    final targetSheet = target.first;

    for (final sheet in workbook.sheets) {
      for (final formula in sheet.cells.values.where((value) => value.startsWith('='))) {
        if (sheet.id == targetSheetId) {
          if (_referencesColumn(formula, column)) return true;
        } else if (_qualifiedReferences(
          formula,
          targetSheet.name,
          (references) => _referencesColumn(references, column),
        )) {
          return true;
        }
      }
    }

    for (final range in _metadataRanges(targetSheet)) {
      if (_referencesColumn(range, column)) return true;
    }
    return false;
  }

  static Iterable<String> _metadataRanges(SheetsWorksheet sheet) sync* {
    for (final rule in sheet.conditionalFormats) {
      final range = rule['range'];
      if (range is String) yield range;
    }
    for (final chart in sheet.charts) {
      final range = chart['range'];
      if (range is String) yield range;
    }
    final pivotRange = sheet.pivotConfig?['range'];
    if (pivotRange is String) yield pivotRange;
  }

  static bool _qualifiedReferences(
    String formula,
    String sheetName,
    bool Function(String references) predicate,
  ) {
    final escapedName = sheetName.replaceAll("'", "''");
    final quoted = RegExp.escape("'$escapedName'");
    final unquoted = RegExp.escape(sheetName);
    final prefix = RegExp(
      '(?:$quoted|$unquoted)\\s*!([^,;)]*)',
      caseSensitive: false,
    );
    for (final match in prefix.allMatches(formula)) {
      if (predicate(match.group(1) ?? '')) return true;
    }
    return false;
  }

  static bool _referencesRow(String value, int targetRow) {
    final references = RegExp(
      r'(?<![A-Z0-9_])\\$?[A-Z]{1,3}\\$?([1-9]\\d*)(?![A-Z0-9_])(?!\\s*\\()',
      caseSensitive: false,
    );
    for (final match in references.allMatches(value)) {
      final row = int.tryParse(match.group(1) ?? '');
      if (row != null && row >= targetRow) return true;
    }
    return false;
  }

  static bool _referencesColumn(String value, int targetColumn) {
    final references = RegExp(
      r'(?<![A-Z0-9_])\\$?([A-Z]{1,3})\\$?[1-9]\\d*(?![A-Z0-9_])(?!\\s*\\()',
      caseSensitive: false,
    );
    for (final match in references.allMatches(value)) {
      final letters = (match.group(1) ?? '').toUpperCase();
      var column = 0;
      for (final rune in letters.runes) {
        column = column * 26 + rune - 64;
      }
      if (column >= targetColumn) return true;
    }
    return false;
  }
}
