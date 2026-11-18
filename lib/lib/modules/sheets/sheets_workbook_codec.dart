import 'dart:convert';

import 'sheets_workbook_limits.dart';

class SheetsWorksheet {
  SheetsWorksheet({
    required this.id,
    required this.name,
    required this.rows,
    required this.columns,
    Map<String, String>? cells,
    Map<String, Map<String, dynamic>>? styles,
  })  : cells = cells ?? <String, String>{},
        styles = styles ?? <String, Map<String, dynamic>>{};

  final String id;
  String name;
  int rows;
  int columns;
  final Map<String, String> cells;
  final Map<String, Map<String, dynamic>> styles;
}

class SheetsWorkbook {
  SheetsWorkbook({
    required this.activeSheetId,
    required this.sheets,
  });

  String activeSheetId;
  final List<SheetsWorksheet> sheets;

  SheetsWorksheet get activeSheet =>
      sheets.firstWhere((sheet) => sheet.id == activeSheetId);
}

class SheetsWorkbookCodec {
  static const int formatVersion = 2;
  static const int maxWorksheets = 100;
  static const int maxSheetNameLength = 31;
  static const String legacySheetId = 'legacy-sheet-1';

  static SheetsWorkbook decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Workbook root must be an object.');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['format'] != 'OFFYNEXBD_SHEETS_WORKBOOK') {
      return _decodeLegacy(data);
    }
    if (data['version'] != formatVersion) {
      throw const FormatException('Unsupported Sheets workbook version.');
    }
    final storedSheets = data['sheets'];
    if (storedSheets is! List ||
        storedSheets.isEmpty ||
        storedSheets.length > maxWorksheets) {
      throw const FormatException('Invalid worksheet collection.');
    }
    final sheets = <SheetsWorksheet>[];
    final ids = <String>{};
    final names = <String>{};
    for (final item in storedSheets) {
      if (item is! Map) throw const FormatException('Invalid worksheet record.');
      final sheet = _decodeSheet(Map<String, dynamic>.from(item));
      if (!ids.add(sheet.id)) throw const FormatException('Duplicate worksheet ID.');
      if (!names.add(sheet.name.toLowerCase())) {
        throw const FormatException('Worksheet names must be unique.');
      }
      sheets.add(sheet);
    }
    final activeId = data['activeSheetId']?.toString() ?? '';
    if (!ids.contains(activeId)) {
      throw const FormatException('Active worksheet does not exist.');
    }
    return SheetsWorkbook(activeSheetId: activeId, sheets: sheets);
  }

  static SheetsWorkbook _decodeLegacy(Map<String, dynamic> data) {
    final sheet = _decodeSheet({
      'id': legacySheetId,
      'name': data['name']?.toString() ?? 'Sheet1',
      'rows': data['rows'] ?? 30,
      'columns': data['columns'] ?? 12,
      'cells': data['cells'] ?? const <String, dynamic>{},
      'styles': data['styles'] ?? const <String, dynamic>{},
    });
    return SheetsWorkbook(activeSheetId: sheet.id, sheets: [sheet]);
  }

  static SheetsWorksheet _decodeSheet(Map<String, dynamic> data) {
    final id = data['id']?.toString().trim() ?? '';
    final name = data['name']?.toString().trim() ?? '';
    if (id.isEmpty) throw const FormatException('Worksheet ID is required.');
    validateSheetName(name);
    final rowsValue = data['rows'];
    final columnsValue = data['columns'];
    if (rowsValue is! num || columnsValue is! num) {
      throw const FormatException('Invalid worksheet dimensions.');
    }
    final rows = rowsValue.toInt();
    final columns = columnsValue.toInt();
    SheetsWorkbookLimits.validate(rows, columns);
    if (rows < 1 || columns < 1) {
      throw const FormatException('Worksheet dimensions must be positive.');
    }
    final rawCells = data['cells'];
    final rawStyles = data['styles'];
    if (rawCells is! Map || rawStyles is! Map) {
      throw const FormatException('Invalid worksheet cell data.');
    }
    final cells = <String, String>{};
    for (final entry in rawCells.entries) {
      final key = entry.key.toString().toUpperCase();
      if (!_isCellInsideBounds(key, rows, columns) || entry.value is! String) {
        throw const FormatException('Invalid cell reference or value.');
      }
      if ((entry.value as String).isNotEmpty) cells[key] = entry.value as String;
    }
    final styles = <String, Map<String, dynamic>>{};
    for (final entry in rawStyles.entries) {
      final key = entry.key.toString().toUpperCase();
      if (!_isCellInsideBounds(key, rows, columns) || entry.value is! Map) {
        throw const FormatException('Invalid cell style reference.');
      }
      styles[key] = Map<String, dynamic>.from(entry.value as Map);
    }
    return SheetsWorksheet(
      id: id,
      name: name,
      rows: rows,
      columns: columns,
      cells: cells,
      styles: styles,
    );
  }

  static bool _isCellInsideBounds(String key, int rows, int columns) {
    final match = RegExp(r'^([A-Z]+)([1-9]\d*)$').firstMatch(key);
    if (match == null) return false;
    var column = 0;
    for (final rune in match.group(1)!.runes) {
      column = column * 26 + rune - 64;
    }
    final row = int.tryParse(match.group(2)!);
    return row != null && row <= rows && column <= columns;
  }

  static void validateSheetName(String name) {
    if (name.isEmpty ||
        name.length > maxSheetNameLength ||
        RegExp(r'[\[\]:*?/\\]').hasMatch(name) ||
        name.startsWith("'") ||
        name.endsWith("'")) {
      throw const FormatException('Invalid worksheet name.');
    }
  }

  static String encode(SheetsWorkbook workbook) {
    if (workbook.sheets.isEmpty || workbook.sheets.length > maxWorksheets) {
      throw const FormatException('Invalid worksheet count.');
    }
    final ids = <String>{};
    final names = <String>{};
    final encodedSheets = <Map<String, dynamic>>[];
    for (final sheet in workbook.sheets) {
      if (!ids.add(sheet.id)) throw const FormatException('Duplicate worksheet ID.');
      if (!names.add(sheet.name.toLowerCase())) {
        throw const FormatException('Worksheet names must be unique.');
      }
      validateSheetName(sheet.name);
      SheetsWorkbookLimits.validate(sheet.rows, sheet.columns);
      if (sheet.rows < 1 || sheet.columns < 1) {
        throw const FormatException('Worksheet dimensions must be positive.');
      }
      encodedSheets.add({
        'id': sheet.id,
        'name': sheet.name,
        'rows': sheet.rows,
        'columns': sheet.columns,
        'cells': sheet.cells,
        'styles': sheet.styles,
      });
    }
    if (!ids.contains(workbook.activeSheetId)) {
      throw const FormatException('Active worksheet does not exist.');
    }
    return jsonEncode({
      'format': 'OFFYNEXBD_SHEETS_WORKBOOK',
      'version': formatVersion,
      'activeSheetId': workbook.activeSheetId,
      'sheets': encodedSheets,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
