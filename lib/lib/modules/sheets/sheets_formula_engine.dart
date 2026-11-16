import 'dart:math' as math;

/// Safe formula evaluator for OFFYNEX Sheets.
/// Blank cells evaluate as zero; non-numeric text and circular formulas fail.
class SheetsFormulaEngine {
  SheetsFormulaEngine(this.cells);

  final Map<String, String> cells;

  double? evaluateCell(String reference, [Set<String>? visiting]) {
    final key = reference.toUpperCase();
    if (!_isCellReference(key)) return null;
    final raw = cells[key]?.trim() ?? '';
    if (raw.isEmpty) return 0;
    if (!raw.startsWith('=')) return double.tryParse(raw);

    final active = visiting ?? <String>{};
    if (!active.add(key)) return null;
    try {
      return _FormulaParser(raw.substring(1), this, active).parse();
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    } finally {
      active.remove(key);
    }
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
        if (value != null) values.add(value);
      }
    }
    return values;
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
      r'\s+|(?:\d+(?:\.\d*)?|\.\d+)|[A-Za-z]+[0-9]+|'
      r'[A-Za-z_][A-Za-z0-9_]*|[()+\-*/^,:]',
    );
    var offset = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start != offset) {
        throw const FormatException('Invalid formula token');
      }
      offset = match.end;
      final token = match.group(0)!;
      if (token.trim().isNotEmpty) tokens.add(token.toUpperCase());
    }
    if (offset != source.length) {
      throw const FormatException('Invalid formula token');
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
    final result = _parseAdditive();
    if (position != tokens.length || !result.isFinite) {
      throw const FormatException('Invalid formula');
    }
    return result;
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
    var value = _parsePower();
    while (current == '*' || current == '/') {
      final operator = _take();
      final right = _parsePower();
      if (operator == '/' && right == 0) {
        throw const FormatException('Division by zero');
      }
      value = operator == '*' ? value * right : value / right;
    }
    return value;
  }

  double _parsePower() {
    var value = _parseUnary();
    if (_accept('^')) value = math.pow(value, _parsePower()).toDouble();
    return value;
  }

  double _parseUnary() {
    if (_accept('+')) return _parseUnary();
    if (_accept('-')) return -_parseUnary();
    return _parsePrimary();
  }

  double _parsePrimary() {
    if (_accept('(')) {
      final value = _parseAdditive();
      _expect(')');
      return value;
    }
    final token = _take();
    final number = double.tryParse(token);
    if (number != null) return number;
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
    const supported = {'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX'};
    if (!supported.contains(name)) {
      throw FormatException('Unsupported function: $name');
    }
    _expect('(');
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
        } else {
          values.add(_parseAdditive());
        }
        if (_accept(')')) break;
        _expect(',');
      }
    }
    if (name == 'COUNT') return values.length.toDouble();
    if (values.isEmpty) {
      if (name == 'SUM') return 0;
      throw const FormatException('No numeric values');
    }
    switch (name) {
      case 'SUM': return values.fold<double>(0, (a, b) => a + b);
      case 'AVERAGE': return values.reduce((a, b) => a + b) / values.length;
      case 'MIN': return values.reduce((a, b) => math.min(a, b).toDouble());
      case 'MAX': return values.reduce((a, b) => math.max(a, b).toDouble());
    }
    throw const FormatException('Unsupported function');
  }
}
