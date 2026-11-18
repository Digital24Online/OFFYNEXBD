import 'dart:convert';

import 'sheets_workbook_limits.dart';
import 'sheets_analytics.dart';

class SheetsWorksheet {
  SheetsWorksheet({
    required this.id,
    required this.name,
    required this.rows,
    required this.columns,
    Map<String, String>? cells,
    Map<String, Map<String, dynamic>>? styles,
    this.freezeTopRow = false,
    Map<String, List<String>>? validations,
    List<Map<String, dynamic>>? conditionalFormats,
    List<Map<String, dynamic>>? charts,
    Map<String, dynamic>? pivotConfig,
  })  : cells = cells ?? <String, String>{},
        styles = styles ?? <String, Map<String, dynamic>>{},
        validations = validations ?? <String, List<String>>{},
        conditionalFormats = conditionalFormats ?? <Map<String, dynamic>>[],
        charts = charts ?? <Map<String, dynamic>>[],
        pivotConfig = pivotConfig == null ? null : Map<String, dynamic>.from(pivotConfig);

  final String id;
  String name;
  int rows;
  int columns;
  final Map<String, String> cells;
  final Map<String, Map<String, dynamic>> styles;
  bool freezeTopRow;
  final Map<String, List<String>> validations;
  final List<Map<String, dynamic>> conditionalFormats;
  final List<Map<String, dynamic>> charts;
  Map<String, dynamic>? pivotConfig;
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
  static const int maxWorkbookBytes = 20 * 1024 * 1024;
  static const String legacySheetId = 'legacy-sheet-1';

  static SheetsWorkbook decode(String raw) {
    if (utf8.encode(raw).length > maxWorkbookBytes) {
      throw const FormatException('Sheets workbook exceeds the 20 MB limit.');
    }
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
    final rawFreezeTopRow = data['freezeTopRow'];
    if (rawFreezeTopRow != null && rawFreezeTopRow is! bool) {
      throw const FormatException('Invalid freeze top row setting.');
    }
    final rawValidations = data['validations'];
    if (rawValidations != null && rawValidations is! Map) {
      throw const FormatException('Invalid cell validation settings.');
    }
    final rawConditionalFormats = data['conditionalFormats'];
    final rawCharts = data['charts'];
    final rawPivotConfig = data['pivotConfig'];
    if (rawConditionalFormats != null &&
        (rawConditionalFormats is! List ||
            rawConditionalFormats.length > SheetsAnalytics.maxConditionalRules)) {
      throw const FormatException('Invalid conditional formatting rules.');
    }
    if (rawCharts != null &&
        (rawCharts is! List || rawCharts.length > SheetsAnalytics.maxCharts)) {
      throw const FormatException('Invalid chart collection.');
    }
    if (rawPivotConfig != null && rawPivotConfig is! Map) {
      throw const FormatException('Invalid Pivot Table configuration.');
    }
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
    final validations = <String, List<String>>{};
    if (rawValidations is Map) {
      for (final entry in rawValidations.entries) {
        final key = entry.key.toString().toUpperCase();
        final options = entry.value;
        if (!_isCellInsideBounds(key, rows, columns) ||
            options is! List || options.isEmpty || options.length > 100 ||
            options.any((option) => option is! String || option.trim().isEmpty || option.length > 200)) {
          throw const FormatException('Invalid cell dropdown validation rule.');
        }
        final normalized = options.cast<String>().map((option) => option.trim()).toList(growable: false);
        if (normalized.toSet().length != normalized.length) {
          throw const FormatException('Dropdown options must be unique.');
        }
        validations[key] = normalized;
      }
    }
    final styles = <String, Map<String, dynamic>>{};
    for (final entry in rawStyles.entries) {
      final key = entry.key.toString().toUpperCase();
      if (!_isCellInsideBounds(key, rows, columns) || entry.value is! Map) {
        throw const FormatException('Invalid cell style reference.');
      }
      styles[key] = Map<String, dynamic>.from(entry.value as Map);
    }
    final conditionalFormats = <Map<String, dynamic>>[];
    if (rawConditionalFormats is List) {
      for (final item in rawConditionalFormats) {
        if (item is! Map) throw const FormatException('Invalid conditional formatting rule.');
        final rule = Map<String, dynamic>.from(item);
        conditionalFormats.add(SheetsAnalytics.createConditionalRule(
          range: rule['range']?.toString() ?? '',
          operator: rule['operator']?.toString() ?? '',
          value: rule['value']?.toString() ?? '',
          fillColor: rule['fillColor']?.toString() ?? '',
          fontColor: rule['fontColor']?.toString() ?? '',
        ));
      }
    }
    final charts = <Map<String, dynamic>>[];
    if (rawCharts is List) {
      for (final item in rawCharts) {
        if (item is! Map) throw const FormatException('Invalid chart record.');
        final chart = Map<String, dynamic>.from(item);
        final type = chart['type']?.toString() ?? '';
        final title = chart['title']?.toString().trim() ?? '';
        final range = chart['range']?.toString() ?? '';
        if (!{'bar', 'line'}.contains(type) || title.isEmpty || title.length > 100) {
          throw const FormatException('Invalid chart settings.');
        }
        SheetsAnalytics.parseRange(range);
        charts.add({'type': type, 'title': title, 'range': range});
      }
    }
    Map<String, dynamic>? pivotConfig;
    if (rawPivotConfig is Map) {
      pivotConfig = Map<String, dynamic>.from(rawPivotConfig);
      final sourceSheetId = pivotConfig['sourceSheetId']?.toString() ?? '';
      final range = pivotConfig['range']?.toString() ?? '';
      final groupColumn = pivotConfig['groupColumn']?.toString() ?? '';
      final valueColumn = pivotConfig['valueColumn']?.toString() ?? '';
      final aggregation = pivotConfig['aggregation']?.toString() ?? '';
      if (sourceSheetId.isEmpty ||
          !SheetsAnalytics.pivotAggregations.contains(aggregation)) {
        throw const FormatException('Invalid Pivot Table settings.');
      }
      SheetsAnalytics.parseRange(range);
      SheetsAnalytics.columnNumber(groupColumn);
      SheetsAnalytics.columnNumber(valueColumn);
    }
    return SheetsWorksheet(
      id: id,
      name: name,
      rows: rows,
      columns: columns,
      cells: cells,
      styles: styles,
      freezeTopRow: rawFreezeTopRow == true,
      validations: validations,
      conditionalFormats: conditionalFormats,
      charts: charts,
      pivotConfig: pivotConfig,
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
        'freezeTopRow': sheet.freezeTopRow,
        'validations': sheet.validations,
        'conditionalFormats': sheet.conditionalFormats,
        'charts': sheet.charts,
        if (sheet.pivotConfig != null) 'pivotConfig': sheet.pivotConfig,
      });
    }
    if (!ids.contains(workbook.activeSheetId)) {
      throw const FormatException('Active worksheet does not exist.');
    }
    final encoded = jsonEncode({
      'format': 'OFFYNEXBD_SHEETS_WORKBOOK',
      'version': formatVersion,
      'activeSheetId': workbook.activeSheetId,
      'sheets': encodedSheets,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (utf8.encode(encoded).length > maxWorkbookBytes) {
      throw const FormatException('Sheets workbook exceeds the 20 MB limit.');
    }
    return encoded;
  }
}
