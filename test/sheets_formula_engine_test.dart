import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_formula_engine.dart';

void main() {
  group('SheetsFormulaEngine', () {
    test('evaluates arithmetic precedence, parentheses and powers', () {
      final engine = SheetsFormulaEngine({
        'A1': '=2+3*4',
        'A2': '=(2+3)*4',
        'A3': '=2^3^2',
      });
      expect(engine.evaluateCell('A1'), 14);
      expect(engine.evaluateCell('A2'), 20);
      expect(engine.evaluateCell('A3'), 512);
    });

    test('resolves repeated and chained cell references', () {
      final engine = SheetsFormulaEngine({
        'A1': '5', 'A2': '=A1+A1', 'A3': '=A2*2',
      });
      expect(engine.evaluateCell('A2'), 10);
      expect(engine.evaluateCell('A3'), 20);
    });

    test('supports aggregate ranges and ignores blanks and text', () {
      final engine = SheetsFormulaEngine({
        'A1': '10', 'A2': '', 'A3': 'text', 'A4': '20',
        'B1': '=SUM(A1:A4)', 'B2': '=AVERAGE(A1:A4)',
        'B3': '=COUNT(A1:A4)', 'B4': '=MIN(A1:A4)',
        'B5': '=MAX(A1:A4)',
      });
      expect(engine.evaluateCell('B1'), 30);
      expect(engine.evaluateCell('B2'), 15);
      expect(engine.evaluateCell('B3'), 2);
      expect(engine.evaluateCell('B4'), 10);
      expect(engine.evaluateCell('B5'), 20);
    });

    test('supports reversed ranges and multiple arguments', () {
      final engine = SheetsFormulaEngine({
        'A1': '2', 'A2': '3', 'B1': '=SUM(A2:A1,5,7)',
      });
      expect(engine.evaluateCell('B1'), 17);
    });

    test('detects circular references and division by zero', () {
      final engine = SheetsFormulaEngine({
        'A1': '=A2+1', 'A2': '=A1+1', 'B1': '=5/0',
      });
      expect(engine.evaluateCell('A1'), 0);
      expect(engine.evaluateCell('B1'), isNull);
    });

    test('rejects unsupported functions and malformed formulas', () {
      final engine = SheetsFormulaEngine({
        'A1': '=UNKNOWN(1)', 'A2': '=1+',
      });
      expect(engine.evaluateCell('A1'), isNull);
      expect(engine.evaluateCell('A2'), isNull);
    });
  });
}
