import 'dart:math' as math;

/// Safe formula evaluator for OFFYNEX Sheets.
/// Blank cells evaluate as zero; non-numeric text and circular formulas fail.
/// Aggregate ranges skip blank and non-numeric cells.
class SheetsFormulaEngine {
  static const int maxFormulaLength = 4096;
  static const int maxFormulaTokens = 2048;

  SheetsFormulaEngine(
    this.cells, {
    this.worksheets = const <String, Map<String, String>>{},
    this.activeSheetName = 'Sheet1',
  });

  final Map<String, String> cells;
  final Map<String, Map<String, String>> worksheets;
  final String activeSheetName;

  double? evaluateCell(String reference, [Set<String>? visiting]) {
    final key = reference.toUpperCase();
    if (!_isCellReference(key)) return null;
    final raw = cells[key]?.trim() ?? '';
    if (raw.isEmpty) return 0;
    if (!raw.startsWith('=')) {
      final number = double.tryParse(raw);
      return number != null && number.isFinite ? number : null;
    }

    if (raw.length > maxFormulaLength) return null;
    final active = visiting ?? <String>{};
    final visitKey = '${activeSheetName.toLowerCase()}!$key';
    if (!active.add(visitKey)) return null;
    try {
      final formula = _expandCrossSheetReferences(raw.substring(1), active);
      return _FormulaParser(formula, this, active).parse();
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    } finally {
      active.remove(visitKey);
    }
  }


  Map<String, String> _cellsForSheet(String sheetName) {
    if (sheetName.toLowerCase() == activeSheetName.toLowerCase()) {
      return cells;
    }
    for (final entry in worksheets.entries) {
      if (entry.key.toLowerCase() == sheetName.toLowerCase()) {
        return entry.value;
      }
    }
    throw FormatException('Unknown worksheet: $sheetName');
  }

  double? _readQualifiedCell(
    String sheetName,
    String reference,
    Set<String> visiting,
  ) {
    final target = _cellsForSheet(sheetName);
    final key = reference.toUpperCase();
    final raw = target[key]?.trim() ?? '';
    if (raw.isEmpty) return 0;
    if (!raw.startsWith('=')) {
      final value = double.tryParse(raw);
      return value != null && value.isFinite ? value : null;
    }
    return SheetsFormulaEngine(
      target,
      worksheets: worksheets,
      activeSheetName: sheetName,
    ).evaluateCell(key, visiting);
  }

  List<double> _readQualifiedRange(
    String sheetName,
    String start,
    String end,
    Set<String> visiting,
  ) {
    final first = _splitCellReference(start.toUpperCase());
    final last = _splitCellReference(end.toUpperCase());
    if (first == null || last == null) {
      throw const FormatException('Invalid cross-worksheet range');
    }
    final minColumn = math.min(first.$1, last.$1).toInt();
    final maxColumn = math.max(first.$1, last.$1).toInt();
    final minRow = math.min(first.$2, last.$2).toInt();
    final maxRow = math.max(first.$2, last.$2).toInt();
    final count = (maxColumn - minColumn + 1) * (maxRow - minRow + 1);
    if (count > 10000) {
      throw const FormatException('Cross-worksheet range is too large');
    }
    final target = _cellsForSheet(sheetName);
    final values = <double>[];
    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        final key = _columnName(column) + row.toString();
        final raw = target[key]?.trim() ?? '';
        if (raw.isEmpty) continue;
        final value = _readQualifiedCell(sheetName, key, visiting);
        if (value == null) {
          if (raw.startsWith('=')) {
            throw const FormatException('Invalid or circular formula in cross-worksheet range');
          }
          continue;
        }
        values.add(value);
      }
    }
    return values;
  }

  String _expandCrossSheetReferences(
    String formula,
    Set<String> visiting,
  ) {
    // Protect quoted criteria/text literals before resolving worksheet refs;
    // otherwise text such as "Sheet2!A1" would be rewritten as a cell value.
    final quotedStrings = <String>[];
    var expanded = formula.replaceAllMapped(
      RegExp(r'"(?:[^"]|"")*"'),
      (match) {
        final index = quotedStrings.length;
        quotedStrings.add(match.group(0)!);
        return '__OFFYNEXBD_STRING_$index__';
      },
    );
    final sheetToken = r"(?:'(?:[^']|'')+'|[A-Za-z_][A-Za-z0-9_]*)";
    final cellToken = r'[A-Z]+[1-9]\d*';
    final rangePattern = RegExp(
      '($sheetToken)!($cellToken):($sheetToken!)?($cellToken)',
      caseSensitive: false,
    );
    expanded = expanded.replaceAllMapped(rangePattern, (match) {
      final sheetName = _decodeSheetName(match.group(1)!);
      final endSheetToken = match.group(3);
      if (endSheetToken != null &&
          _decodeSheetName(endSheetToken.substring(0, endSheetToken.length - 1)).toLowerCase() !=
              sheetName.toLowerCase()) {
        throw const FormatException('A range cannot span worksheets.');
      }
      final values = _readQualifiedRange(
        sheetName,
        match.group(2)!,
        match.group(4)!,
        visiting,
      );
      return values.map((value) => value.toString()).join(',');
    });
    final cellPattern = RegExp(
      '($sheetToken)!($cellToken)',
      caseSensitive: false,
    );
    expanded = expanded.replaceAllMapped(cellPattern, (match) {
      final sheetName = _decodeSheetName(match.group(1)!);
      final value = _readQualifiedCell(sheetName, match.group(2)!, visiting);
      if (value == null) {
        throw const FormatException('Cross-worksheet reference is not numeric or contains an error.');
      }
      return value.toString();
    });
    for (var index = 0; index < quotedStrings.length; index++) {
      expanded = expanded.replaceAll('__OFFYNEXBD_STRING_$index__', quotedStrings[index]);
    }
    return expanded;
  }

  static String _decodeSheetName(String token) {
    if (token.startsWith("'") && token.endsWith("'")) {
      return token.substring(1, token.length - 1).replaceAll("''", "'");
    }
    return token;
  }

  double? _readCell(String reference, Set<String> visiting) =>
      evaluateCell(reference, visiting);

  List<double> _readRange(String start, String end, Set<String> visiting) {
    final first = _splitCellReference(start);
    final last = _splitCellReference(end);
    if (first == null || last == null) {
      throw const FormatException('Invalid range');
    }
    final minColumn = math.min(first.$1, last.$1).toInt();
    final maxColumn = math.max(first.$1, last.$1).toInt();
    final minRow = math.min(first.$2, last.$2).toInt();
    final maxRow = math.max(first.$2, last.$2).toInt();
    final cellCount = (maxColumn - minColumn + 1) *
        (maxRow - minRow + 1);
    if (cellCount > 10000) {
      throw const FormatException('Range is too large');
    }

    final values = <double>[];
    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        final key = _columnName(column) + row.toString();
        final raw = cells[key]?.trim() ?? '';
        if (raw.isEmpty) continue;
        final value = _readCell(key, visiting);
        if (value == null) {
          // Spreadsheet aggregate functions must not silently ignore formula
          // errors or circular references inside a referenced range.
          if (raw.startsWith('=')) {
            throw const FormatException('Invalid or circular formula in range');
          }
          // Text cells are ignored by numeric aggregate functions.
          continue;
        }
        values.add(value);
      }
    }
    return values;
  }

  List<(String, String, double?)> _readCriteriaRange(
    String start,
    String end,
    Set<String> visiting,
  ) {
    final first = _splitCellReference(start.toUpperCase());
    final last = _splitCellReference(end.toUpperCase());
    if (first == null || last == null) throw const FormatException('Invalid criteria range');
    final minColumn = math.min(first.$1, last.$1).toInt();
    final maxColumn = math.max(first.$1, last.$1).toInt();
    final minRow = math.min(first.$2, last.$2).toInt();
    final maxRow = math.max(first.$2, last.$2).toInt();
    final count = (maxColumn - minColumn + 1) * (maxRow - minRow + 1);
    if (count > 10000) throw const FormatException('Criteria range is too large');
    final result = <(String, String, double?)>[];
    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        final key = _columnName(column) + row.toString();
        final raw = cells[key]?.trim() ?? '';
        double? numeric;
        if (raw.startsWith('=')) {
          numeric = _readCell(key, visiting);
          if (numeric == null) throw const FormatException('Invalid or circular formula in criteria range');
        } else {
          final parsed = double.tryParse(raw);
          if (parsed != null && parsed.isFinite) numeric = parsed;
        }
        result.add((key, raw, numeric));
      }
    }
    return result;
  }

  static bool _isCellReference(String value) =>
      RegExp(r'^[A-Z]+[1-9]\d*$').hasMatch(value);

  static (int, int)? _splitCellReference(String value) {
    final match = RegExp(r'^([A-Z]+)([1-9]\d*)$').firstMatch(value);
    if (match == null) return null;
    var column = 0;
    for (final rune in match.group(1)!.runes) {
      column = column * 26 + rune - 64;
    }
    return (column, int.parse(match.group(2)!));
  }

  static String _columnName(int column) {
    var number = column;
    var result = '';
    while (number > 0) {
      final remainder = (number - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      number = (number - 1) ~/ 26;
    }
    return result;
  }
}

class _FormulaParser {
  _FormulaParser(this.source, this.engine, this.visiting) {
    final pattern = RegExp(
      r'\s+|"(?:[^"]|"")*"|(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?|[A-Za-z]+[0-9]+|'
      r'[A-Za-z_][A-Za-z0-9_]*|>=|<=|<>|[=<>()+\-*/^%,:]',
    );
    var offset = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start != offset) {
        throw const FormatException('Invalid formula token');
      }
      offset = match.end;
      final token = match.group(0)!;
      if (token.trim().isNotEmpty) {
        tokens.add(token.startsWith('"') ? token : token.toUpperCase());
      }
    }
    if (offset != source.length) {
      throw const FormatException('Invalid formula token');
    }
    if (tokens.length > SheetsFormulaEngine.maxFormulaTokens) {
      throw const FormatException('Formula contains too many tokens');
    }
  }

  final String source;
  final SheetsFormulaEngine engine;
  final Set<String> visiting;
  final List<String> tokens = [];
  int position = 0;

  String? get current => position < tokens.length ? tokens[position] : null;

  String _take() {
    final token = current;
    if (token == null) throw const FormatException('Unexpected end');
    position++;
    return token;
  }

  bool _accept(String token) {
    if (current != token) return false;
    position++;
    return true;
  }

  void _expect(String token) {
    if (!_accept(token)) throw FormatException('Expected $token');
  }

  double? parse() {
    if (tokens.isEmpty) return null;
    final result = _parseComparison();
    if (position != tokens.length || !result.isFinite) {
      throw const FormatException('Invalid formula');
    }
    return result;
  }

  double _parseComparison() {
    final left = _parseAdditive();
    final operator = current;
    if (operator == null ||
        !const {'=', '<>', '>', '<', '>=', '<='}.contains(operator)) {
      return left;
    }
    _take();
    final right = _parseAdditive();
    if (current != null &&
        const {'=', '<>', '>', '<', '>=', '<='}.contains(current)) {
      throw const FormatException('Chained comparisons are not supported');
    }
    final result = switch (operator) {
      '=' => left == right,
      '<>' => left != right,
      '>' => left > right,
      '<' => left < right,
      '>=' => left >= right,
      '<=' => left <= right,
      _ => false,
    };
    return result ? 1 : 0;
  }

  double _parseAdditive() {
    var value = _parseMultiplicative();
    while (current == '+' || current == '-') {
      final operator = _take();
      final right = _parseMultiplicative();
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseMultiplicative() {
    var value = _parseUnary();
    while (current == '*' || current == '/') {
      final operator = _take();
      final right = _parseUnary();
      if (operator == '/' && right == 0) {
        throw const FormatException('Division by zero');
      }
      value = operator == '*' ? value * right : value / right;
    }
    return value;
  }

  // Exponentiation binds more tightly than unary signs, as in Excel:
  // -2^2 is -4, while (-2)^2 is 4.
  double _parseUnary() {
    if (_accept('+')) return _parseUnary();
    if (_accept('-')) return -_parseUnary();
    var value = _parsePower();
    // Excel-style postfix percentage: 25% evaluates to 0.25.
    while (_accept('%')) {
      value /= 100;
    }
    return value;
  }

  double _parsePower() {
    final value = _parsePrimary();
    if (_accept('^')) return math.pow(value, _parseUnary()).toDouble();
    return value;
  }

  double _parsePrimary() {
    if (_accept('(')) {
      final value = _parseComparison();
      _expect(')');
      return value;
    }
    final token = _take();
    final number = double.tryParse(token);
    if (number != null) return number;
    // Function names can resemble cell references (for example LOG10).
    // Prefer a function call when the identifier is immediately followed by '('.
    if (RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(token) && current == '(') {
      return _parseFunction(token);
    }
    if (SheetsFormulaEngine._isCellReference(token)) {
      final value = engine._readCell(token, visiting);
      if (value == null) {
        throw const FormatException('Invalid or circular cell reference');
      }
      return value;
    }
    if (RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(token)) {
      return _parseFunction(token);
    }
    throw const FormatException('Invalid formula value');
  }

  double _parseFunction(String name) {
    const supported = {
      'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX', 'PRODUCT',
      'ABS', 'ROUND', 'ROUNDUP', 'ROUNDDOWN', 'SQRT', 'POWER',
      'MOD', 'INT', 'SIGN', 'MEDIAN', 'LARGE', 'SMALL',
      'CEILING', 'FLOOR', 'PI', 'EXP', 'LN', 'LOG', 'LOG10',
      'TRUNC', 'FACT', 'EVEN', 'ODD', 'RADIANS', 'DEGREES',
      'GCD', 'LCM', 'COMBIN', 'PERMUT', 'QUOTIENT',
      'SIN', 'COS', 'TAN', 'ASIN', 'ACOS', 'ATAN', 'ATAN2', 'COT', 'SINH', 'COSH', 'TANH', 'MROUND',
      'SUMSQ', 'DEVSQ', 'AVEDEV', 'GEOMEAN', 'HARMEAN',
      'VARP', 'VARS', 'STDEVP', 'STDEVS',
      'IF', 'IFERROR', 'AND', 'OR', 'NOT',
      'COUNTIF', 'SUMIF', 'AVERAGEIF',
      'COUNTIFS', 'SUMIFS', 'AVERAGEIFS',
    };
    if (!supported.contains(name)) {
      throw FormatException('Unsupported function: $name');
    }
    _expect('(');
    if (name == 'IF') return _parseIfFunction();
    if (name == 'IFERROR') return _parseIfErrorFunction();
    if (name == 'COUNTIF' || name == 'SUMIF' || name == 'AVERAGEIF') {
      return _parseCriteriaFunction(name);
    }
    if (name == 'COUNTIFS' || name == 'SUMIFS' || name == 'AVERAGEIFS') {
      return _parseMultiCriteriaFunction(name);
    }
    final values = <double>[];
    if (!_accept(')')) {
      while (true) {
        if (current != null &&
            SheetsFormulaEngine._isCellReference(current!) &&
            position + 1 < tokens.length &&
            tokens[position + 1] == ':') {
          final start = _take();
          _expect(':');
          final end = _take();
          if (!SheetsFormulaEngine._isCellReference(end)) {
            throw const FormatException('Invalid range end');
          }
          values.addAll(engine._readRange(start, end, visiting));
        } else if (_isAggregateFunction(name) &&
            current != null &&
            SheetsFormulaEngine._isCellReference(current!) &&
            (position + 1 >= tokens.length ||
                (tokens[position + 1] != ':' && tokens[position + 1] != '('))) {
          // Direct blank/text references are ignored by spreadsheet aggregate
          // functions, just like blank/text cells inside a referenced range.
          final reference = _take();
          final raw = engine.cells[reference]?.trim() ?? '';
          final parsedNumber = double.tryParse(raw);
          if (raw.isNotEmpty &&
              (raw.startsWith('=') ||
                  (parsedNumber != null && parsedNumber.isFinite))) {
            final value = engine._readCell(reference, visiting);
            if (value == null) {
              throw const FormatException('Invalid or circular cell reference');
            }
            values.add(value);
          }
        } else {
          values.add(_parseComparison());
        }
        if (_accept(')')) break;
        _expect(',');
      }
    }

    if (name == 'PI') {
      _expectNoExtraArguments(name, values, 0);
      return math.pi;
    }
    if (name == 'COUNT') return values.length.toDouble();
    if (name == 'SUM') return values.fold<double>(0, (a, b) => a + b);
    if (name == 'PRODUCT') {
      return values.isEmpty ? 0 : values.fold<double>(1, (a, b) => a * b);
    }
    if (values.isEmpty && (name == 'MIN' || name == 'MAX')) return 0;
    if (values.isEmpty) throw const FormatException('No numeric values');

    switch (name) {
      case 'AVERAGE':
        return values.reduce((a, b) => a + b) / values.length;
      case 'SUMSQ':
        return values.fold<double>(0, (sum, value) => sum + value * value);
      case 'DEVSQ': {
        final mean = values.reduce((a, b) => a + b) / values.length;
        return values.fold<double>(0, (sum, value) => sum + math.pow(value - mean, 2).toDouble());
      }
      case 'AVEDEV': {
        final mean = values.reduce((a, b) => a + b) / values.length;
        return values.fold<double>(0, (sum, value) => sum + (value - mean).abs()) / values.length;
      }
      case 'GEOMEAN':
        if (values.any((value) => value <= 0)) {
          throw const FormatException('GEOMEAN requires positive values');
        }
        return math.exp(values.fold<double>(0, (sum, value) => sum + math.log(value)) / values.length);
      case 'HARMEAN':
        if (values.any((value) => value <= 0)) {
          throw const FormatException('HARMEAN requires positive values');
        }
        return values.length / values.fold<double>(0, (sum, value) => sum + 1 / value);
      case 'VARP':
      case 'STDEVP':
      case 'VARS':
      case 'STDEVS': {
        if ((name == 'VARS' || name == 'STDEVS') && values.length < 2) {
          throw const FormatException('Sample variance requires at least two values');
        }
        final mean = values.reduce((a, b) => a + b) / values.length;
        final divisor = (name == 'VARS' || name == 'STDEVS') ? values.length - 1 : values.length;
        final variance = values.fold<double>(0, (sum, value) => sum + math.pow(value - mean, 2)) / divisor;
        return name == 'STDEVP' || name == 'STDEVS' ? math.sqrt(variance) : variance;
      }
      case 'MIN':
        return values.reduce((a, b) => math.min(a, b).toDouble());
      case 'MAX':
        return values.reduce((a, b) => math.max(a, b).toDouble());
      case 'ABS':
        _expectNoExtraArguments(name, values, 1);
        return values.first.abs();
      case 'ROUND':
      case 'ROUNDUP':
      case 'ROUNDDOWN':
        _expectNoExtraArguments(name, values, 2);
        return _roundWithPrecision(values[0], values[1], name);
      case 'MEDIAN':
        final sorted = [...values]..sort();
        final middle = sorted.length ~/ 2;
        return sorted.length.isOdd ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
      case 'LARGE':
      case 'SMALL':
        _expectAtLeastArguments(name, values, 2);
        final rank = values.last;
        final candidates = values.sublist(0, values.length - 1);
        if (rank < 1 || rank > candidates.length || rank != rank.roundToDouble()) {
          throw const FormatException('Invalid rank');
        }
        final sorted = [...candidates]..sort();
        return name == 'LARGE' ? sorted[sorted.length - rank.toInt()] : sorted[rank.toInt() - 1];
      case 'CEILING':
      case 'FLOOR':
        _expectNoExtraArguments(name, values, 2);
        if (values[1] == 0) throw const FormatException('Significance cannot be zero');
        if (values[0] > 0 && values[1] < 0) {
          throw const FormatException('Number and significance have different signs');
        }
        final quotient = values[0] / values[1];
        return (name == 'CEILING' ? quotient.ceilToDouble() : quotient.floorToDouble()) * values[1];
      case 'SQRT':
        _expectNoExtraArguments(name, values, 1);
        if (values.first < 0) throw const FormatException('SQRT domain error');
        return math.sqrt(values.first);
      case 'POWER':
        _expectNoExtraArguments(name, values, 2);
        return math.pow(values[0], values[1]).toDouble();
      case 'MOD':
        _expectNoExtraArguments(name, values, 2);
        if (values[1] == 0) throw const FormatException('Division by zero');
        final remainder = values[0] % values[1];
        if (remainder == 0) return 0;
        // Excel MOD has the sign of the divisor, unlike Dart's remainder.
        return remainder.sign == values[1].sign
            ? remainder
            : remainder + values[1];
      case 'INT':
        _expectNoExtraArguments(name, values, 1);
        return values.first.floorToDouble();
      case 'TRUNC':
        if (values.isEmpty || values.length > 2) {
          throw const FormatException('TRUNC expects one or two arguments');
        }
        final digits = values.length == 2 ? _integerArgument(values[1]) : 0;
        return _roundTowardZero(values[0], digits);
      case 'FACT':
        _expectNoExtraArguments(name, values, 1);
        final n = _integerArgument(values.first);
        if (n < 0 || n > 170) throw const FormatException('FACT argument out of range');
        var factorial = 1.0;
        for (var i = 2; i <= n; i++) {
          factorial *= i;
        }
        return factorial;
      case 'EVEN':
      case 'ODD':
        _expectNoExtraArguments(name, values, 1);
        final value = values.first;
        final rounded = value.isNegative ? value.floor() : value.ceil();
        if (name == 'EVEN') {
          final even = rounded.abs().isEven ? rounded : rounded + (rounded.isNegative ? -1 : 1);
          return even.toDouble();
        }
        final odd = rounded.abs().isOdd ? rounded : rounded + (rounded.isNegative ? -1 : 1);
        return odd.toDouble();
      case 'RADIANS':
        _expectNoExtraArguments(name, values, 1);
        return values.first * math.pi / 180;
      case 'DEGREES':
        _expectNoExtraArguments(name, values, 1);
        return values.first * 180 / math.pi;
      case 'GCD':
      case 'LCM':
        if (values.isEmpty || values.length > 255) {
          throw FormatException('$name expects between 1 and 255 arguments');
        }
        var aggregate = name == 'GCD' ? 0 : 1;
        for (final value in values) {
          final integer = _integerArgument(value).abs();
          if (name == 'GCD') {
            aggregate = _greatestCommonDivisor(aggregate, integer);
          } else {
            if (integer == 0) return 0;
            aggregate = (aggregate ~/ _greatestCommonDivisor(aggregate, integer)) * integer;
            if (aggregate > 9007199254740991) {
              throw const FormatException('LCM result exceeds safe integer range');
            }
          }
        }
        return aggregate.toDouble();
      case 'COMBIN':
      case 'PERMUT':
        _expectNoExtraArguments(name, values, 2);
        final n = _integerArgument(values[0]);
        final k = _integerArgument(values[1]);
        if (n < 0 || k < 0 || k > n) {
          throw const FormatException('Invalid combination/permutation arguments');
        }
        var result = 1.0;
        final count = name == 'COMBIN' ? math.min(k, n - k) : k;
        for (var i = 1; i <= count; i++) {
          result *= name == 'COMBIN' ? (n - count + i) / i : (n - i + 1);
          if (!result.isFinite || result > 9007199254740991) {
            throw const FormatException('Result exceeds safe integer range');
          }
        }
        return result;
      case 'QUOTIENT':
        _expectNoExtraArguments(name, values, 2);
        if (values[1] == 0) throw const FormatException('Division by zero');
        return (values[0] / values[1]).truncateToDouble();
      case 'SIGN':
        _expectNoExtraArguments(name, values, 1);
        return values.first.sign.toDouble();
      case 'EXP':
        _expectNoExtraArguments(name, values, 1);
        return math.exp(values.first);
      case 'LN':
        _expectNoExtraArguments(name, values, 1);
        if (values.first <= 0) throw const FormatException('LN domain error');
        return math.log(values.first);
      case 'LOG':
        if (values.isEmpty || values.length > 2 || values.first <= 0) throw const FormatException('Invalid LOG arguments');
        final base = values.length == 2 ? values[1] : 10.0;
        if (base <= 0 || base == 1) throw const FormatException('Invalid LOG base');
        return math.log(values.first) / math.log(base);
      case 'LOG10':
        _expectNoExtraArguments(name, values, 1);
        if (values.first <= 0) throw const FormatException('LOG10 domain error');
        return math.log(values.first) / math.ln10;
      case 'MROUND':
        _expectNoExtraArguments(name, values, 2);
        if (values[1] == 0 || values[0].sign != values[1].sign && values[0] != 0) {
          throw const FormatException('MROUND number and multiple must have the same sign.');
        }
        return (values[0] / values[1]).roundToDouble() * values[1];
      case 'SINH':
        _expectNoExtraArguments(name, values, 1);
        return (math.exp(values.first) - math.exp(-values.first)) / 2;
      case 'COSH':
        _expectNoExtraArguments(name, values, 1);
        return (math.exp(values.first) + math.exp(-values.first)) / 2;
      case 'TANH':
        _expectNoExtraArguments(name, values, 1);
        final positive = math.exp(values.first);
        final negative = math.exp(-values.first);
        return (positive - negative) / (positive + negative);
      case 'COT':
        _expectNoExtraArguments(name, values, 1);
        final tangent = math.tan(values.first);
        if (tangent.abs() < 1e-15) throw const FormatException('COT domain error');
        return 1 / tangent;
      case 'SIN':
        _expectNoExtraArguments(name, values, 1);
        return math.sin(values.first);
      case 'COS':
        _expectNoExtraArguments(name, values, 1);
        return math.cos(values.first);
      case 'TAN':
        _expectNoExtraArguments(name, values, 1);
        return math.tan(values.first);
      case 'IF':
        _expectNoExtraArguments(name, values, 3);
        return values[0] != 0 ? values[1] : values[2];
      case 'AND':
        if (values.isEmpty || values.length > 255) {
          throw const FormatException('AND expects between 1 and 255 arguments');
        }
        return values.every((value) => value != 0) ? 1 : 0;
      case 'OR':
        if (values.isEmpty || values.length > 255) {
          throw const FormatException('OR expects between 1 and 255 arguments');
        }
        return values.any((value) => value != 0) ? 1 : 0;
      case 'NOT':
        _expectNoExtraArguments(name, values, 1);
        return values.first == 0 ? 1 : 0;
      case 'ASIN':
        _expectNoExtraArguments(name, values, 1);
        if (values.first.abs() > 1) throw const FormatException('ASIN domain error');
        return math.asin(values.first);
      case 'ACOS':
        _expectNoExtraArguments(name, values, 1);
        if (values.first.abs() > 1) throw const FormatException('ACOS domain error');
        return math.acos(values.first);
      case 'ATAN':
        _expectNoExtraArguments(name, values, 1);
        return math.atan(values.first);
      case 'ATAN2':
        _expectNoExtraArguments(name, values, 2);
        if (values[0] == 0 && values[1] == 0) {
          throw const FormatException('ATAN2 is undefined for (0, 0).');
        }
        return math.atan2(values[1], values[0]);
    }
    throw const FormatException('Unsupported function');
  }

  double _parseCriteriaFunction(String name) {
    final criteriaRange = _readRangeArgument();
    _expect(',');
    final criterion = _readCriterionArgument();
    (String, String)? sumRange;
    if (name != 'COUNTIF' && _accept(',')) sumRange = _readRangeArgument();
    _expect(')');
    final criteriaCells = engine._readCriteriaRange(criteriaRange.$1, criteriaRange.$2, visiting);
    final valueCells = sumRange == null
        ? criteriaCells
        : engine._readCriteriaRange(sumRange.$1, sumRange.$2, visiting);
    if (criteriaCells.length != valueCells.length ||
        _rangeShape(criteriaRange) != _rangeShape(sumRange ?? criteriaRange)) {
      throw const FormatException('Criteria and sum ranges must have the same dimensions');
    }
    var count = 0;
    var sum = 0.0;
    for (var index = 0; index < criteriaCells.length; index++) {
      if (!_matchesCriterion(criteriaCells[index].$2, criteriaCells[index].$3, criterion)) continue;
      final value = valueCells[index].$3;
      if (value == null) continue;
      count++;
      sum += value;
    }
    if (name == 'COUNTIF') return criteriaCells.where((cell) =>
        _matchesCriterion(cell.$2, cell.$3, criterion)).length.toDouble();
    if (name == 'SUMIF') return sum;
    if (count == 0) throw const FormatException('AVERAGEIF has no numeric matches');
    return sum / count;
  }

  double _parseMultiCriteriaFunction(String name) {
    (String, String)? sumRange;
    if (name != 'COUNTIFS') {
      sumRange = _readRangeArgument();
      _expect(',');
    }
    final criteria = <((String, String), String)>[];
    while (true) {
      final range = _readRangeArgument();
      _expect(',');
      final criterion = _readCriterionArgument();
      criteria.add((range, criterion));
      if (_accept(')')) break;
      _expect(',');
      if (criteria.length >= 127) throw const FormatException('Too many criteria pairs');
    }
    if (criteria.isEmpty) throw const FormatException('At least one criteria pair is required');
    final ranges = criteria.map((entry) => engine._readCriteriaRange(
      entry.$1.$1, entry.$1.$2, visiting,
    )).toList(growable: false);
    final expectedLength = ranges.first.length;
    final expectedShape = _rangeShape(criteria.first.$1);
    if (ranges.any((range) => range.length != expectedLength) ||
        criteria.any((entry) => _rangeShape(entry.$1) != expectedShape)) {
      throw const FormatException('All criteria ranges must have the same dimensions');
    }
    final values = sumRange == null
        ? const <(String, String, double?)>[]
        : engine._readCriteriaRange(sumRange.$1, sumRange.$2, visiting);
    if (sumRange != null &&
        (values.length != expectedLength || _rangeShape(sumRange) != expectedShape)) {
      throw const FormatException('Sum and criteria ranges must have the same dimensions');
    }
    var matches = 0;
    var sum = 0.0;
    for (var index = 0; index < expectedLength; index++) {
      var accepted = true;
      for (var criteriaIndex = 0; criteriaIndex < criteria.length; criteriaIndex++) {
        final cell = ranges[criteriaIndex][index];
        if (!_matchesCriterion(cell.$2, cell.$3, criteria[criteriaIndex].$2)) {
          accepted = false;
          break;
        }
      }
      if (!accepted) continue;
      if (name == 'COUNTIFS') {
        matches++;
      } else {
        final value = values[index].$3;
        if (value == null) continue;
        matches++;
        sum += value;
      }
    }
    if (name == 'COUNTIFS') return matches.toDouble();
    if (name == 'SUMIFS') return sum;
    if (matches == 0) throw const FormatException('AVERAGEIFS has no numeric matches');
    return sum / matches;
  }

  (int, int) _rangeShape((String, String) range) {
    final first = SheetsFormulaEngine._splitCellReference(range.$1);
    final last = SheetsFormulaEngine._splitCellReference(range.$2);
    if (first == null || last == null) throw const FormatException('Invalid criteria range');
    return (
      (first.$2 - last.$2).abs() + 1,
      (first.$1 - last.$1).abs() + 1,
    );
  }

  (String, String) _readRangeArgument() {
    final start = _take();
    if (!SheetsFormulaEngine._isCellReference(start)) {
      throw const FormatException('Expected a cell or range reference');
    }
    if (!_accept(':')) return (start, start);
    final end = _take();
    if (!SheetsFormulaEngine._isCellReference(end)) {
      throw const FormatException('Invalid criteria range end');
    }
    return (start, end);
  }

  String _readCriterionArgument() {
    final token = _take();
    if (token.startsWith('"') && token.endsWith('"') && token.length >= 2) {
      return token.substring(1, token.length - 1).replaceAll('""', '"');
    }
    if (SheetsFormulaEngine._isCellReference(token)) {
      final raw = engine.cells[token]?.trim() ?? '';
      if (raw.startsWith('=')) {
        final value = engine._readCell(token, visiting);
        if (value == null) throw const FormatException('Invalid criteria reference');
        return value.toString();
      }
      return raw;
    }
    return token;
  }

  bool _matchesCriterion(String raw, double? numeric, String criterion) {
    var operator = '=';
    var expected = criterion;
    for (final candidate in const ['>=', '<=', '<>', '>', '<', '=']) {
      if (criterion.startsWith(candidate)) {
        operator = candidate;
        expected = criterion.substring(candidate.length);
        break;
      }
    }
    final expectedNumber = double.tryParse(expected.trim());
    final actualNumber = numeric ?? double.tryParse(raw.trim());
    if (expectedNumber != null && actualNumber != null) {
      return switch (operator) {
        '>' => actualNumber > expectedNumber,
        '>=' => actualNumber >= expectedNumber,
        '<' => actualNumber < expectedNumber,
        '<=' => actualNumber <= expectedNumber,
        '<>' => actualNumber != expectedNumber,
        _ => actualNumber == expectedNumber,
      };
    }
    if (operator != '=' && operator != '<>') {
      final comparison = raw.toLowerCase().compareTo(expected.toLowerCase());
      return switch (operator) {
        '>' => comparison > 0,
        '>=' => comparison >= 0,
        '<' => comparison < 0,
        '<=' => comparison <= 0,
        _ => false,
      };
    }
    final hasWildcard = expected.contains('*') || expected.contains('?');
    if (hasWildcard && raw.isEmpty) return false;
    final pattern = RegExp.escape(expected)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    final matches = RegExp('^$pattern$', caseSensitive: false).hasMatch(raw);
    return operator == '<>' ? !matches : matches;
  }

  double _parseIfFunction() {
    final condition = _parseComparison();
    _expect(',');
    if (condition != 0) {
      final whenTrue = _parseComparison();
      _expect(',');
      _skipFunctionArgument();
      _expect(')');
      return whenTrue;
    }
    _skipFunctionArgument();
    _expect(',');
    final whenFalse = _parseComparison();
    _expect(')');
    return whenFalse;
  }

  double _parseIfErrorFunction() {
    double value;
    try {
      value = _parseComparison();
    } on FormatException {
      if (current != ',') _skipFunctionArgument();
      _expect(',');
      final fallback = _parseComparison();
      _expect(')');
      return fallback;
    } on RangeError {
      if (current != ',') _skipFunctionArgument();
      _expect(',');
      final fallback = _parseComparison();
      _expect(')');
      return fallback;
    }
    _expect(',');
    _skipFunctionArgument();
    _expect(')');
    return value;
  }

  /// Advances over one syntactically nested argument without evaluating it.
  /// This gives IF spreadsheet-style lazy branch evaluation.
  void _skipFunctionArgument() {
    if (current == null || current == ',' || current == ')') {
      throw const FormatException('IF argument is missing');
    }
    var depth = 0;
    var consumed = false;
    while (current != null) {
      final token = current!;
      if (depth == 0 && (token == ',' || token == ')')) break;
      if (token == '(') {
        depth++;
      } else if (token == ')') {
        if (depth == 0) break;
        depth--;
      }
      position++;
      consumed = true;
    }
    if (!consumed || depth != 0) {
      throw const FormatException('Invalid IF argument');
    }
  }

  bool _isAggregateFunction(String name) => const {
    'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX', 'PRODUCT',
    'MEDIAN', 'LARGE', 'SMALL', 'SUMSQ', 'DEVSQ', 'AVEDEV',
    'GEOMEAN', 'HARMEAN', 'VARP', 'VARS', 'STDEVP', 'STDEVS',
  }.contains(name);

  int _integerArgument(double value) {
    if (!value.isFinite || value != value.truncateToDouble() ||
        value.abs() > 9007199254740991) {
      throw const FormatException('Expected a safe integer argument');
    }
    return value.toInt();
  }

  int _greatestCommonDivisor(int a, int b) {
    var left = a;
    var right = b;
    while (right != 0) {
      final remainder = left % right;
      left = right;
      right = remainder;
    }
    return left;
  }

  double _roundTowardZero(double number, int digits) {
    if (digits > 308) return number;
    if (digits < -308) return 0;
    final factor = math.pow(10, digits).toDouble();
    if (!factor.isFinite) return number;
    if (factor == 0) return 0;
    final scaled = number * factor;
    if (!scaled.isFinite) return number;
    return scaled.truncateToDouble() / factor;
  }

  double _roundWithPrecision(double number, double precision, String mode) {
    if (!precision.isFinite || precision != precision.truncateToDouble()) {
      throw const FormatException('Rounding precision must be an integer');
    }
    // Beyond IEEE-754's useful decimal range, finer precision changes nothing;
    // coarser precision rounds every finite value to zero.
    if (precision > 308) return number;
    if (precision < -308) return 0;
    final factor = math.pow(10, precision).toDouble();
    if (factor == 0) return 0;
    if (!factor.isFinite) return number;
    final scaled = number * factor;
    if (!scaled.isFinite) return number;
    final rounded = switch (mode) {
      'ROUNDUP' => scaled.isNegative
          ? scaled.floorToDouble()
          : scaled.ceilToDouble(),
      'ROUNDDOWN' => scaled.truncateToDouble(),
      _ => scaled.roundToDouble(),
    };
    final result = rounded / factor;
    if (!result.isFinite) throw const FormatException('Rounding overflow');
    return result;
  }

  void _expectNoExtraArguments(String name, List<double> values, int count) {
    if (values.length != count) {
      throw FormatException('$name expects $count argument(s)');
    }
  }

  void _expectAtLeastArguments(String name, List<double> values, int count) {
    if (values.length < count) {
      throw FormatException('$name expects at least $count arguments');
    }
  }
}
