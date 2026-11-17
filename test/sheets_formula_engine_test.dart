import 'dart:math' as math;
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

    test('supports common numeric functions and Excel unary precedence', () {
      final engine = SheetsFormulaEngine({
        'A1': '=-2^2',
        'A2': '=(-2)^2',
        'A3': '=ABS(-8)',
        'A4': '=ROUND(12.345,2)',
        'A5': '=SQRT(81)',
        'A6': '=POWER(2,5)',
        'A7': '=MOD(17,5)',
        'A8': '=INT(-2.3)',
        'A9': '=SIGN(-12)',
        'A10': '=PRODUCT(2,3,4)',
        'A11': '5',
        'A12': '6',
        'B1': '=PRODUCT(A11:A12)',
      });
      expect(engine.evaluateCell('A1'), -4);
      expect(engine.evaluateCell('A2'), 4);
      expect(engine.evaluateCell('A3'), 8);
      expect(engine.evaluateCell('A4'), 12.35);
      expect(engine.evaluateCell('A5'), 9);
      expect(engine.evaluateCell('A6'), 32);
      expect(engine.evaluateCell('A7'), 2);
      expect(engine.evaluateCell('A8'), -3);
      expect(engine.evaluateCell('A9'), -1);
      expect(engine.evaluateCell('A10'), 24);
      expect(engine.evaluateCell('B1'), 30);
    });

    test('propagates formula errors from cells inside aggregate ranges', () {
      final engine = SheetsFormulaEngine({
        'A1': '10',
        'A2': '=1/0',
        'A3': '20',
        'B1': '=SUM(A1:A3)',
        'B2': '=AVERAGE(A1:A3)',
        'B3': '=MIN(A1:A3)',
      });
      expect(engine.evaluateCell('B1'), isNull);
      expect(engine.evaluateCell('B2'), isNull);
      expect(engine.evaluateCell('B3'), isNull);
    });

    test('continues to ignore text values inside aggregate ranges', () {
      final engine = SheetsFormulaEngine({
        'A1': '10',
        'A2': 'not a number',
        'A3': '20',
        'B1': '=SUM(A1:A3)',
      });
      expect(engine.evaluateCell('B1'), 30);
    });

    test('detects circular references and division by zero', () {
      final engine = SheetsFormulaEngine({
        'A1': '=A2+1', 'A2': '=A1+1', 'B1': '=5/0',
      });
      expect(engine.evaluateCell('A1'), isNull);
      expect(engine.evaluateCell('B1'), isNull);
    });

    test('rejects unsupported functions and malformed formulas', () {
      final engine = SheetsFormulaEngine({
        'A1': '=UNKNOWN(1)', 'A2': '=1+',
      });
      expect(engine.evaluateCell('A1'), isNull);
      expect(engine.evaluateCell('A2'), isNull);
    });
    test('supports common statistical, rounding and mathematical functions', () {
      final engine = SheetsFormulaEngine({
        'A1': '=MEDIAN(1,3,5,7)', 'A2': '=LARGE(1,3,5,7,2)',
        'A3': '=SMALL(1,3,5,7,2)', 'A4': '=ROUNDUP(1.231,2)',
        'A5': '=ROUNDDOWN(1.239,2)', 'A6': '=CEILING(4.2,1)',
        'A7': '=FLOOR(4.8,1)', 'A8': '=PI()', 'A9': '=EXP(1)',
        'A10': '=LN(1)', 'A11': '=LOG(100)', 'A12': '=LOG10(1000)',
        'A13': '=SIN(0)', 'A14': '=COS(0)', 'A15': '=TAN(0)',
        'A16': '=ASIN(0)', 'A17': '=ACOS(1)', 'A18': '=ATAN(0)',
      });
      expect(engine.evaluateCell('A1'), 4);
      expect(engine.evaluateCell('A2'), 5);
      expect(engine.evaluateCell('A3'), 3);
      expect(engine.evaluateCell('A4'), 1.24);
      expect(engine.evaluateCell('A5'), 1.23);
      expect(engine.evaluateCell('A6'), 5);
      expect(engine.evaluateCell('A7'), 4);
      expect(engine.evaluateCell('A8'), closeTo(math.pi, 1e-12));
      expect(engine.evaluateCell('A9'), closeTo(math.e, 1e-12));
      expect(engine.evaluateCell('A10'), 0);
      expect(engine.evaluateCell('A11'), 2);
      expect(engine.evaluateCell('A12'), 3);
      expect(engine.evaluateCell('A13'), 0);
      expect(engine.evaluateCell('A14'), 1);
      expect(engine.evaluateCell('A15'), 0);
      expect(engine.evaluateCell('A16'), 0);
      expect(engine.evaluateCell('A17'), 0);
      expect(engine.evaluateCell('A18'), 0);
    });

    test('rejects invalid ranks, domains and argument counts', () {
      final engine = SheetsFormulaEngine({
        'A1': '=LARGE(1,2,3)', 'A2': '=SMALL(1,0)', 'A3': '=LN(0)',
        'A4': '=LOG(10,1)', 'A5': '=ASIN(2)', 'A6': '=PI(1)',
        'A7': '=ROUNDUP(1,2,3)',
      });
      for (var row = 1; row <= 7; row++) {
        expect(engine.evaluateCell('A$row'), isNull);
      }
    });

  });
}
