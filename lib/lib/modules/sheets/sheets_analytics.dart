import 'sheets_workbook_limits.dart';

class SheetsCellRange {
  const SheetsCellRange({
    required this.firstRow,
    required this.firstColumn,
    required this.lastRow,
    required this.lastColumn,
  });

  final int firstRow;
  final int firstColumn;
  final int lastRow;
  final int lastColumn;

  int get rows => lastRow - firstRow + 1;
  int get columns => lastColumn - firstColumn + 1;
}

class SheetsChartSeries {
  const SheetsChartSeries({required this.name, required this.values});

  final String name;
  final List<double> values;
}

class SheetsChartData {
  const SheetsChartData({required this.labels, required this.series});

  final List<String> labels;
  final List<SheetsChartSeries> series;
}

class SheetsAnalytics {
  const SheetsAnalytics._();

  static const int maxRangeCells = 10000;
  static const int maxConditionalRules = 100;
  static const int maxCharts = 20;
  static const Set<String> conditionalOperators = {
    'greaterThan',
    'greaterOrEqual',
    'lessThan',
    'lessOrEqual',
    'equal',
    'notEqual',
    'contains',
    'isEmpty',
    'isNotEmpty',
  };
  static const Set<String> pivotAggregations = {
    'sum',
    'count',
    'average',
    'min',
    'max',
  };

  static int columnNumber(String letters) {
    final normalized = letters.toUpperCase();
    if (!RegExp(r'^[A-Z]{1,3}$').hasMatch(normalized)) {
      throw const FormatException('Invalid column reference.');
    }
    var value = 0;
    for (final rune in normalized.runes) {
      value = value * 26 + rune - 64;
    }
    if (value > SheetsWorkbookLimits.maxColumns) {
      throw const FormatException('Column exceeds the supported grid.');
    }
    return value;
  }

  static String columnName(int number) {
    if (number < 1 || number > SheetsWorkbookLimits.maxColumns) {
      throw const FormatException('Column exceeds the supported grid.');
    }
    var value = number;
    var result = '';
    while (value > 0) {
      final remainder = (value - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      value = (value - 1) ~/ 26;
    }
    return result;
  }

  static SheetsCellRange parseRange(String input) {
    final raw = input.trim().toUpperCase();
    final match = RegExp(
      r'^\$?([A-Z]{1,3})\$?([1-9]\d*)(?::\$?([A-Z]{1,3})\$?([1-9]\d*))?$',
    ).firstMatch(raw);
    if (match == null) throw const FormatException('Enter a valid range, e.g. A1:C20.');
    final firstColumn = columnNumber(match.group(1)!);
    final firstRow = int.parse(match.group(2)!);
    final lastColumn = match.group(3) == null
        ? firstColumn
        : columnNumber(match.group(3)!);
    final lastRow = match.group(4) == null
        ? firstRow
        : int.parse(match.group(4)!);
    final range = SheetsCellRange(
      firstRow: firstRow < lastRow ? firstRow : lastRow,
      firstColumn: firstColumn < lastColumn ? firstColumn : lastColumn,
      lastRow: firstRow > lastRow ? firstRow : lastRow,
      lastColumn: firstColumn > lastColumn ? firstColumn : lastColumn,
    );
    if (range.lastRow > SheetsWorkbookLimits.maxRows ||
        range.lastColumn > SheetsWorkbookLimits.maxColumns ||
        range.rows * range.columns > maxRangeCells) {
      throw const FormatException('Range exceeds the supported analysis size.');
    }
    return range;
  }

  static Map<String, dynamic> createConditionalRule({
    required String range,
    required String operator,
    required String value,
    required String fillColor,
    required String fontColor,
  }) {
    final parsed = parseRange(range);
    if (parsed.rows * parsed.columns > maxRangeCells) {
      throw const FormatException('Conditional formatting range is too large.');
    }
    if (!conditionalOperators.contains(operator)) {
      throw const FormatException('Unsupported conditional formatting rule.');
    }
    if (!{'isEmpty', 'isNotEmpty'}.contains(operator) && value.trim().isEmpty) {
      throw const FormatException('Enter a comparison value.');
    }
    for (final color in [fillColor, fontColor]) {
      if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(color)) {
        throw const FormatException('Invalid formatting color.');
      }
    }
    return {
      'range': range.trim().toUpperCase(),
      'operator': operator,
      'value': value.trim(),
      'fillColor': fillColor.toUpperCase(),
      'fontColor': fontColor.toUpperCase(),
    };
  }

  static Map<String, dynamic> conditionalStyleForCell(
    String cellKey,
    String value,
    List<Map<String, dynamic>> rules,
  ) {
    final result = <String, dynamic>{};
    for (final rule in rules) {
      try {
        final range = parseRange(rule['range']?.toString() ?? '');
        final cell = parseRange(cellKey);
        if (cell.firstRow < range.firstRow ||
            cell.firstRow > range.lastRow ||
            cell.firstColumn < range.firstColumn ||
            cell.firstColumn > range.lastColumn) {
          continue;
        }
        final operator = rule['operator']?.toString() ?? '';
        final expected = rule['value']?.toString() ?? '';
        final number = double.tryParse(value.trim());
        final target = double.tryParse(expected.trim());
        final matches = switch (operator) {
          'greaterThan' => number != null && target != null && number > target,
          'greaterOrEqual' => number != null && target != null && number >= target,
          'lessThan' => number != null && target != null && number < target,
          'lessOrEqual' => number != null && target != null && number <= target,
          'equal' => number != null && target != null
              ? number == target
              : value.toLowerCase() == expected.toLowerCase(),
          'notEqual' => number != null && target != null
              ? number != target
              : value.toLowerCase() != expected.toLowerCase(),
          'contains' => value.toLowerCase().contains(expected.toLowerCase()),
          'isEmpty' => value.trim().isEmpty,
          'isNotEmpty' => value.trim().isNotEmpty,
          _ => false,
        };
        if (!matches) continue;
        final fill = rule['fillColor']?.toString();
        final font = rule['fontColor']?.toString();
        if (fill != null) result['fillColor'] = fill;
        if (font != null) result['fontColor'] = font;
      } on FormatException {
        continue;
      }
    }
    return result;
  }

  static SheetsChartData buildChartData(
    Map<String, String> cells,
    String rangeText,
  ) {
    final range = parseRange(rangeText);
    if (range.rows < 2 || range.columns < 2) {
      throw const FormatException('A chart needs a header row, labels and at least one numeric series.');
    }
    final labels = <String>[];
    final series = <SheetsChartSeries>[];
    for (var column = range.firstColumn + 1;
        column <= range.lastColumn;
        column++) {
      final header = cells['${columnName(column)}${range.firstRow}']?.trim() ?? '';
      final name = header.isEmpty ? 'Series ${column - range.firstColumn}' : header;
      final values = <double>[];
      var hasNumericValue = false;
      for (var row = range.firstRow + 1; row <= range.lastRow; row++) {
        final raw = cells['${columnName(range.firstColumn)}$row']?.trim() ?? '';
        if (column == range.firstColumn + 1) {
          labels.add(raw.isEmpty ? 'Row $row' : raw);
        }
        final cell = cells['${columnName(column)}$row']?.trim() ?? '';
        if (cell.isEmpty) {
          values.add(0);
        } else {
          final numeric = double.tryParse(cell);
          if (numeric == null || !numeric.isFinite) {
            throw FormatException('Chart value in ${columnName(column)}$row is not numeric.');
          }
          values.add(numeric);
          hasNumericValue = true;
        }
      }
      if (hasNumericValue) {
        series.add(SheetsChartSeries(name: name, values: values));
      }
    }
    if (labels.isEmpty || series.isEmpty) {
      throw const FormatException('The selected range has no numeric chart data.');
    }
    return SheetsChartData(labels: labels, series: series);
  }

  static List<List<String>> buildPivotSummary({
    required Map<String, String> cells,
    required String rangeText,
    required String groupColumn,
    required String valueColumn,
    required String aggregation,
  }) {
    final range = parseRange(rangeText);
    final groupIndex = columnNumber(groupColumn);
    final valueIndex = columnNumber(valueColumn);
    if (range.rows < 2 ||
        groupIndex < range.firstColumn ||
        groupIndex > range.lastColumn ||
        valueIndex < range.firstColumn ||
        valueIndex > range.lastColumn ||
        groupIndex == valueIndex) {
      throw const FormatException('Choose two different columns inside the source range, including a header row.');
    }
    if (!pivotAggregations.contains(aggregation)) {
      throw const FormatException('Unsupported Pivot aggregation.');
    }
    final groupHeader = cells['${columnName(groupIndex)}${range.firstRow}']?.trim() ?? '';
    final valueHeader = cells['${columnName(valueIndex)}${range.firstRow}']?.trim() ?? '';
    final groups = <String, List<double>>{};
    for (var row = range.firstRow + 1; row <= range.lastRow; row++) {
      final label = cells['${columnName(groupIndex)}$row']?.trim() ?? '';
      if (label.isEmpty) continue;
      final raw = cells['${columnName(valueIndex)}$row']?.trim() ?? '';
      if (aggregation == 'count') {
        final values = groups.putIfAbsent(label, () => <double>[]);
        if (raw.isNotEmpty) values.add(1);
        continue;
      }
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null || !value.isFinite) {
        throw FormatException('Pivot value in ${columnName(valueIndex)}$row is not numeric.');
      }
      groups.putIfAbsent(label, () => <double>[]).add(value);
    }
    if (groups.isEmpty) throw const FormatException('No grouped rows were found in the selected range.');
    final result = <List<String>>[
      [groupHeader.isEmpty ? 'Row' : groupHeader, '${aggregation.toUpperCase()} of ${valueHeader.isEmpty ? 'Value' : valueHeader}'],
    ];
    final keys = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (keys.length > SheetsWorkbookLimits.maxRows - 2) {
      throw const FormatException('Pivot result would exceed the supported worksheet row limit.');
    }
    for (final key in keys) {
      final values = groups[key]!;
      final total = values.fold<double>(0, (sum, value) => sum + value);
      final aggregate = values.isEmpty ? 0.0 : switch (aggregation) {
        'count' => values.length.toDouble(),
        'average' => total / values.length,
        'min' => values.reduce((left, right) => left < right ? left : right),
        'max' => values.reduce((left, right) => left > right ? left : right),
        _ => total,
      };
      result.add([key, aggregate == aggregate.roundToDouble()
          ? aggregate.toStringAsFixed(0)
          : aggregate.toStringAsFixed(2)]);
    }
    final grandValues = groups.values.expand((values) => values).toList();
    final grandTotal = grandValues.fold<double>(0, (sum, value) => sum + value);
    final grand = grandValues.isEmpty ? 0.0 : switch (aggregation) {
      'count' => grandValues.length.toDouble(),
      'average' => grandTotal / grandValues.length,
      'min' => grandValues.reduce((left, right) => left < right ? left : right),
      'max' => grandValues.reduce((left, right) => left > right ? left : right),
      _ => grandTotal,
    };
    result.add(['Grand Total', grand == grand.roundToDouble()
        ? grand.toStringAsFixed(0)
        : grand.toStringAsFixed(2)]);
    return result;
  }
}
