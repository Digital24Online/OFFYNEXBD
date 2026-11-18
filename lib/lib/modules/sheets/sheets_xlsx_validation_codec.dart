import 'dart:convert';

import 'package:excel_community/excel_community.dart' as xlsx;

import 'sheets_data_validation.dart';
import 'sheets_workbook_limits.dart';

class SheetsXlsxValidationImport {
  const SheetsXlsxValidationImport({
    required this.validations,
    required this.rows,
    required this.columns,
  });

  final Map<String, List<String>> validations;
  final int rows;
  final int columns;
}

/// Bridges OFFYNEXBD's exact-value cell rules with native XLSX list validation.
///
/// The app currently models fixed dropdown lists only. Unsupported Excel
/// validation types and formula/range-backed dropdowns are rejected instead
/// of being silently discarded during import.
class SheetsXlsxValidationCodec {
  const SheetsXlsxValidationCodec._();

  static const int maxExpandedCells = 10000;

  static SheetsXlsxValidationImport read(
    xlsx.Sheet source, {
    required int baseRows,
    required int baseColumns,
  }) {
    var rows = baseRows.clamp(1, SheetsWorkbookLimits.maxRows).toInt();
    var columns = baseColumns.clamp(1, SheetsWorkbookLimits.maxColumns).toInt();
    final validations = <String, List<String>>{};
    for (final entry in source.dataValidations.entries) {
      final rule = entry.value;
      if (rule.type != xlsx.DataValidationType.list) {
        throw const FormatException(
          'This XLSX contains a non-dropdown validation rule that OFFYNEX Sheets cannot edit yet. The current workbook was not changed.',
        );
      }
      final rawOptions = rule.listItems;
      if (rawOptions == null) {
        throw const FormatException(
          'This XLSX uses a formula- or range-based dropdown. Only fixed dropdown lists can currently be imported safely.',
        );
      }
      final options = SheetsDataValidation.parseOptions(rawOptions.join('\n'));
      if (options.length != rawOptions.length) {
        throw const FormatException('XLSX dropdown contains an empty option.');
      }
      _validateExcelList(options);
      for (final rawRange in entry.key.trim().split(RegExp(r'\s+'))) {
        if (rawRange.isEmpty) continue;
        final range = _parseRange(rawRange);
        final firstRow = range.$1;
        final firstColumn = range.$2;
        final lastRow = range.$3;
        final lastColumn = range.$4;
        if (lastRow > SheetsWorkbookLimits.maxRows ||
            lastColumn > SheetsWorkbookLimits.maxColumns) {
          throw const FormatException(
            'An XLSX dropdown range exceeds the OFFYNEX Sheets grid limit.',
          );
        }
        final area = (lastRow - firstRow + 1) *
            (lastColumn - firstColumn + 1);
        if (area > maxExpandedCells) {
          throw const FormatException(
            'XLSX dropdown ranges cover too many cells for a safe import.',
          );
        }
        for (var row = firstRow; row <= lastRow; row++) {
          for (var column = firstColumn; column <= lastColumn; column++) {
            final key = '${_columnName(column)}$row';
            final existing = validations[key];
            if (existing != null && jsonEncode(existing) != jsonEncode(options)) {
              throw const FormatException(
                'Overlapping XLSX dropdown rules cannot be imported safely.',
              );
            }
            validations[key] = options;
          }
        }
        rows = rows > lastRow ? rows : lastRow;
        columns = columns > lastColumn ? columns : lastColumn;
        if (validations.length > maxExpandedCells) {
          throw const FormatException(
            'XLSX dropdown ranges cover too many cells for a safe import.',
          );
        }
      }
    }
    return SheetsXlsxValidationImport(
      validations: validations,
      rows: rows,
      columns: columns,
    );
  }

  static void write(
    xlsx.Sheet target,
    Map<String, List<String>> validations,
  ) {
    if (validations.length > maxExpandedCells) {
      throw const FormatException(
        'Too many dropdown cells to export safely to XLSX.',
      );
    }
    final byColumn = <int, List<(int, List<String>, String)>>{};
    for (final entry in validations.entries) {
      final cell = _parseCell(entry.key);
      final options = SheetsDataValidation.parseOptions(entry.value.join('\n'));
      if (options.length != entry.value.length) {
        throw const FormatException('Dropdown contains an empty option.');
      }
      _validateExcelList(options);
      final optionsKey = jsonEncode(options);
      byColumn.putIfAbsent(cell.$2, () => []).add((cell.$1, options, optionsKey));
    }

    for (final entry in byColumn.entries) {
      final items = entry.value..sort((a, b) => a.$1.compareTo(b.$1));
      if (items.isEmpty) continue;
      var startRow = items.first.$1;
      var endRow = startRow;
      var activeOptions = items.first.$2;
      var activeKey = items.first.$3;
      for (final item in items.skip(1)) {
        if (item.$1 == endRow + 1 && item.$3 == activeKey) {
          endRow = item.$1;
          continue;
        }
        _writeRange(target, entry.key, startRow, endRow, activeOptions);
        startRow = item.$1;
        endRow = item.$1;
        activeOptions = item.$2;
        activeKey = item.$3;
      }
      _writeRange(target, entry.key, startRow, endRow, activeOptions);
    }
  }

  static void _writeRange(
    xlsx.Sheet target,
    int column,
    int firstRow,
    int lastRow,
    List<String> options,
  ) {
    final columnName = _columnName(column);
    target.addDataValidation(
      '$columnName$firstRow:$columnName$lastRow',
      xlsx.DataValidation.list(options),
    );
  }

  static void _validateExcelList(List<String> options) {
    if (options.any((value) =>
        value.contains(',') || value.contains('"') ||
        value.contains('\n') || value.contains('\r'))) {
      throw const FormatException(
        'XLSX fixed dropdown options cannot contain commas, quotes or line breaks.',
      );
    }
    if (options.join(',').length > 255) {
      throw const FormatException(
        'XLSX fixed dropdown options exceed Excel’s 255-character list limit.',
      );
    }
  }

  static (int, int, int, int) _parseRange(String raw) {
    final parts = raw.split(':');
    if (parts.length > 2) {
      throw const FormatException('Invalid XLSX dropdown range.');
    }
    final first = _parseCell(parts.first);
    final last = parts.length == 1 ? first : _parseCell(parts.last);
    final firstRow = first.$1 < last.$1 ? first.$1 : last.$1;
    final lastRow = first.$1 > last.$1 ? first.$1 : last.$1;
    final firstColumn = first.$2 < last.$2 ? first.$2 : last.$2;
    final lastColumn = first.$2 > last.$2 ? first.$2 : last.$2;
    return (firstRow, firstColumn, lastRow, lastColumn);
  }

  static (int, int) _parseCell(String raw) {
    final normalized = raw.toUpperCase().replaceAll(r'$', '');
    final match = RegExp(r'^([A-Z]+)([1-9]\d*)$').firstMatch(normalized);
    if (match == null) {
      throw const FormatException('Invalid XLSX dropdown cell reference.');
    }
    var column = 0;
    for (final rune in match.group(1)!.runes) {
      column = column * 26 + rune - 64;
    }
    final row = int.tryParse(match.group(2)!);
    if (row == null || row < 1 || column < 1) {
      throw const FormatException('Invalid XLSX dropdown cell reference.');
    }
    return (row, column);
  }

  static String _columnName(int column) {
    var value = column;
    var result = '';
    while (value > 0) {
      final remainder = (value - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      value = (value - 1) ~/ 26;
    }
    return result;
  }
}
