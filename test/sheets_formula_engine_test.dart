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

    test('supports Excel comparison operators and numeric logical functions', () {
      final engine = SheetsFormulaEngine({
        'A1': '=IF(10>5,100,0)',
        'A2': '=IF(2>=3,1,2)',
        'A3': '=AND(1,2,1)',
        'A4': '=OR(0,0,1)',
        'A5': '=NOT(0)',
        'A6': '=IF(A1<>0,A1/10,0)',
        'A7': '=IF(2=2,3,4)',
        'A8': '=IF(3<=2,1,2)',
        'A9': '=IF(3<2,1,2)',
        'A10': '=IF(3>2,1,2)',
        'A11': '=NOT(5>2)',
        'A12': '=AND(2>1,3>=3)',
        'A13': '=OR(1<0,1=1)',
        'A14': '=IF((2+3)*2=10,7,8)',
      });
      expect(engine.evaluateCell('A1'), 100);
      expect(engine.evaluateCell('A2'), 2);
      expect(engine.evaluateCell('A3'), 1);
      expect(engine.evaluateCell('A4'), 1);
      expect(engine.evaluateCell('A5'), 1);
      expect(engine.evaluateCell('A6'), 10);
      expect(engine.evaluateCell('A7'), 3);
      expect(engine.evaluateCell('A8'), 2);
      expect(engine.evaluateCell('A9'), 2);
      expect(engine.evaluateCell('A10'), 1);
      expect(engine.evaluateCell('A11'), 0);
      expect(engine.evaluateCell('A12'), 1);
      expect(engine.evaluateCell('A13'), 1);
      expect(engine.evaluateCell('A14'), 7);
    });

    test('IF evaluates only the selected branch, including nested branches', () {
      final engine = SheetsFormulaEngine({
        'A1': '=IF(1=1,9,1/0)',
        'A2': '=IF(1=0,1/0,8)',
        'A3': '=IF(1=1,IF(2=2,6,1/0),1/0)',
        'A4': '=IF(1=0,IF(2=2,1/0,4),IF(3=3,5,1/0))',
        'A5': '=IF(1=1,2,)',
        'A6': '=IF(1=0,,2)',
      });
      expect(engine.evaluateCell('A1'), 9);
      expect(engine.evaluateCell('A2'), 8);
      expect(engine.evaluateCell('A3'), 6);
      expect(engine.evaluateCell('A4'), 5);
      expect(engine.evaluateCell('A5'), isNull);
      expect(engine.evaluateCell('A6'), isNull);
    });

    test('IFERROR returns fallback only for formula errors and is lazy', () {
      final engine = SheetsFormulaEngine({
        'A1': '=IFERROR(10/0,7)',
        'A2': '=IFERROR(A3,9)',
        'A3': '=A3+1',
        'A4': '=IFERROR(5,1/0)',
        'A5': '=IFERROR(IF(1=1,4,1/0),1/0)',
        'A6': '=IFERROR(1/0,IF(2=2,8,1/0))',
      });
      expect(engine.evaluateCell('A1'), 7);
      expect(engine.evaluateCell('A2'), 9);
      expect(engine.evaluateCell('A4'), 5);
      expect(engine.evaluateCell('A5'), 4);
      expect(engine.evaluateCell('A6'), 8);
    });

    test('rejects malformed IFERROR arguments', () {
      final engine = SheetsFormulaEngine({
        'A1': '=IFERROR(1/0)',
        'A2': '=IFERROR(2,)',
        'A3': '=IFERROR(,2)',
      });
      for (var row = 1; row <= 3; row++) {
        expect(engine.evaluateCell('A$row'), isNull);
      }
    });

    test('rejects malformed comparisons and invalid logical argument counts', () {
      final engine = SheetsFormulaEngine({
        'A1': '=1>2>3',
        'A2': '=IF(1,2)',
        'A3': '=AND()',
        'A4': '=OR()',
        'A5': '=NOT(1,2)',
      });
      for (var row = 1; row <= 5; row++) {
        expect(engine.evaluateCell('A$row'), isNull);
      }
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
        'LOG10': '42', 'A19': '=LOG10',
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
      expect(engine.evaluateCell('A12'), closeTo(3, 1e-12));
      expect(engine.evaluateCell('A13'), 0);
      expect(engine.evaluateCell('A14'), 1);
      expect(engine.evaluateCell('A15'), 0);
      expect(engine.evaluateCell('A16'), 0);
      expect(engine.evaluateCell('A17'), 0);
      expect(engine.evaluateCell('A18'), 0);
      expect(engine.evaluateCell('A19'), 42);

      final rangeEngine = SheetsFormulaEngine({
        'A1': '1', 'A2': '3', 'A3': '5', 'A4': '7',
        'B1': '=LARGE(A1:A4,2)', 'B2': '=SMALL(A1:A4,2)',
        'B3': '=LARGE(1,3,5,7,2)', 'B4': '=SMALL(1,3,5,7,2)',
      });
      expect(rangeEngine.evaluateCell('B1'), 5);
      expect(rangeEngine.evaluateCell('B2'), 3);
      expect(rangeEngine.evaluateCell('B3'), 5);
      expect(rangeEngine.evaluateCell('B4'), 3);
    });

    test('evaluates additional statistical aggregate functions', () {
      final engine = SheetsFormulaEngine({
        'A1': '2', 'A2': '4', 'A3': '6', 'A4': '8',
        'B1': '=SUMSQ(A1:A4)',
        'B2': '=DEVSQ(A1:A4)',
        'B3': '=AVEDEV(A1:A4)',
        'B4': '=GEOMEAN(A1:A4)',
        'B5': '=HARMEAN(A1:A4)',
        'B6': '=VARP(A1:A4)',
        'B7': '=VARS(A1:A4)',
        'B8': '=STDEVP(A1:A4)',
        'B9': '=STDEVS(A1:A4)',
      });
      expect(engine.evaluateCell('B1'), 120);
      expect(engine.evaluateCell('B2'), 20);
      expect(engine.evaluateCell('B3'), 2);
      expect(engine.evaluateCell('B4'), closeTo(4.4267, 0.001));
      expect(engine.evaluateCell('B5'), closeTo(3.84, 0.001));
      expect(engine.evaluateCell('B6'), 5);
      expect(engine.evaluateCell('B7'), closeTo(6.6666667, 0.000001));
      expect(engine.evaluateCell('B8'), closeTo(2.2360679, 0.000001));
      expect(engine.evaluateCell('B9'), closeTo(2.5819889, 0.000001));
    });

    test('statistical aggregates ignore direct text and blank cell references', () {
      final engine = SheetsFormulaEngine({
        'A1': 'Bangla',
        'A2': '',
        'A3': '2',
        'A4': '4',
        'B1': '=SUMSQ(A1,A2,A3,A4)',
        'B2': '=DEVSQ(A1,A2,A3,A4)',
        'B3': '=AVEDEV(A1,A2,A3,A4)',
        'B4': '=GEOMEAN(A1,A2,A3,A4)',
        'B5': '=HARMEAN(A1,A2,A3,A4)',
        'B6': '=VARP(A1,A2,A3,A4)',
        'B7': '=STDEVP(A1,A2,A3,A4)',
      });
      expect(engine.evaluateCell('B1'), 20);
      expect(engine.evaluateCell('B2'), 2);
      expect(engine.evaluateCell('B3'), 1);
      expect(engine.evaluateCell('B4'), closeTo(2.828427, 0.00001));
      expect(engine.evaluateCell('B5'), closeTo(2.666667, 0.00001));
      expect(engine.evaluateCell('B6'), 1);
      expect(engine.evaluateCell('B7'), 1);
    });

    test('rejects invalid domains for statistical aggregate functions', () {
      final engine = SheetsFormulaEngine({
        'A1': '=GEOMEAN(1,0)',
        'A2': '=HARMEAN(1,-2)',
        'A3': '=VARS(5)',
        'A4': '=STDEVS(5)',
      });
      for (var row = 1; row <= 4; row++) {
        expect(engine.evaluateCell('A$row'), isNull);
      }
    });

    test('supports COUNTIF, SUMIF and AVERAGEIF with text and numeric criteria', () {
      final engine = SheetsFormulaEngine({
        'A1': 'Apples', 'A2': 'Oranges', 'A3': 'Apples', 'A4': 'Bananas',
        'B1': '3', 'B2': '5', 'B3': '7', 'B4': '9',
        'C1': '=COUNTIF(A1:A4,"Apples")',
        'C2': '=SUMIF(A1:A4,"Apples",B1:B4)',
        'C3': '=AVERAGEIF(A1:A4,"Apples",B1:B4)',
        'C4': '=COUNTIF(B1:B4,">=5")',
        'C5': '=SUMIF(B1:B4,">5")',
        'C6': '=COUNTIF(A1:A4,"A*")',
      });
      expect(engine.evaluateCell('C1'), 2);
      expect(engine.evaluateCell('C2'), 10);
      expect(engine.evaluateCell('C3'), 5);
      expect(engine.evaluateCell('C4'), 3);
      expect(engine.evaluateCell('C5'), 16);
      expect(engine.evaluateCell('C6'), 2);
    });

    test('cross-sheet expansion leaves quoted text criteria untouched', () {
      final engine = SheetsFormulaEngine(
        {
          'A1': 'Sheet2!A1',
          'A2': 'Other',
          'B1': '=COUNTIF(A1:A2,"Sheet2!A1")',
          'C1': '=SUM(A1:A2)',
        },
        worksheets: {'Sheet2': {'A1': '5'}},
        activeSheetName: 'Sheet1',
      );
      expect(engine.evaluateCell('B1'), 1);
    });

    test('supports COUNTIFS, SUMIFS and AVERAGEIFS with multiple conditions', () {
      final engine = SheetsFormulaEngine({
        'A1': 'East', 'A2': 'West', 'A3': 'East', 'A4': 'East',
        'B1': 'Paid', 'B2': 'Paid', 'B3': 'Unpaid', 'B4': 'Paid',
        'C1': '10', 'C2': '20', 'C3': '30', 'C4': '40',
        'D1': '=COUNTIFS(A1:A4,"East",B1:B4,"Paid")',
        'D2': '=SUMIFS(C1:C4,A1:A4,"East",B1:B4,"Paid")',
        'D3': '=AVERAGEIFS(C1:C4,A1:A4,"East",B1:B4,"Paid")',
      });
      expect(engine.evaluateCell('D1'), 2);
      expect(engine.evaluateCell('D2'), 50);
      expect(engine.evaluateCell('D3'), 25);
    });

    test('rejects mismatched SUMIF ranges and AVERAGEIF with no matches', () {
      final engine = SheetsFormulaEngine({
        'A1': 'A', 'A2': 'B', 'B1': '1',
        'C1': '=SUMIF(A1:A2,"A",B1:B1)',
        'C2': '=AVERAGEIF(A1:A2,"missing",B1:B2)',
      });
      expect(engine.evaluateCell('C1'), isNull);
      expect(engine.evaluateCell('C2'), isNull);
    });

    test('evaluates Excel-style postfix percentages', () {
      final engine = SheetsFormulaEngine({
        'A1': '=25%', 'A2': '=50%*200', 'A3': '=10+5%',
        'A4': '=-25%', 'A5': '=200*12.5%',
      });
      expect(engine.evaluateCell('A1'), 0.25);
      expect(engine.evaluateCell('A2'), 100);
      expect(engine.evaluateCell('A3'), 10.05);
      expect(engine.evaluateCell('A4'), -0.25);
      expect(engine.evaluateCell('A5'), 25);
    });

    test('parses scientific notation in formula numbers', () {
      final engine = SheetsFormulaEngine({
        'A1': '=1E3+2.5e-1',
        'A2': '=1.25E-2*1000',
        'A3': '=1e+2',
      });
      expect(engine.evaluateCell('A1'), 1000.25);
      expect(engine.evaluateCell('A2'), 12.5);
      expect(engine.evaluateCell('A3'), 100);
    });

    test('covers empty aggregates, domains, overflow and range limits', () {
      final engine = SheetsFormulaEngine({
        'A1': '=SUM()',
        'A2': '=COUNT()',
        'A3': '=PRODUCT()',
        'A4': '=MIN()',
        'A5': '=MAX()',
        'A6': '=AVERAGE()',
        'A7': '=MEDIAN()',
        'A8': '=LARGE(1)',
        'A9': '=SQRT(-1)',
        'A10': '=POWER(-2,0.5)',
        'A11': '=POWER(0,-1)',
        'A12': '=MOD(1,0)',
        'A13': '=LOG(-1)',
        'A14': '=LOG(10,0)',
        'A15': '=LOG10(0)',
        'A16': '=ACOS(1.01)',
        'A17': '=ROUND(1,1.5)',
        'A18': '=CEILING(1,0)',
        'A19': '=FLOOR(1,0)',
        'A20': '=ABS(1,2)',
        'A21': '=EXP(1000)',
        'A22': '=SUM(A1:ZZ1000)',
        'A23': '=sum(1,2)',
        'A24': '=a1+2',
        'A25': '=MEDIAN(1,3,5)',
        'A26': '=LARGE(1,3,5,1)',
        'A27': '=SMALL(1,3,5,3)',
        'A28': '=LOG(8,2)',
      });

      expect(engine.evaluateCell('A1'), 0);
      expect(engine.evaluateCell('A2'), 0);
      expect(engine.evaluateCell('A3'), 0);
      expect(engine.evaluateCell('A4'), 0);
      expect(engine.evaluateCell('A5'), 0);
      for (var row = 6; row <= 22; row++) {
        expect(engine.evaluateCell('A$row'), isNull, reason: 'A$row should reject invalid input');
      }
      expect(engine.evaluateCell('A23'), 3);
      expect(engine.evaluateCell('A24'), 2);
      expect(engine.evaluateCell('A25'), 3);
      expect(engine.evaluateCell('A26'), 5);
      expect(engine.evaluateCell('A27'), 5);
      expect(engine.evaluateCell('A28'), closeTo(3, 1e-12));
    });

    test('supports nested LOG10 calls inside aggregate functions', () {
      final engine = SheetsFormulaEngine({
        'A1': '=SUM(LOG10(1000),1)',
        'A2': '=AVERAGE(LOG10(100),4)',
      });
      expect(engine.evaluateCell('A1'), closeTo(4, 1e-12));
      expect(engine.evaluateCell('A2'), closeTo(3, 1e-12));
    });

    test('matches CEILING and FLOOR negative-number significance rules', () {
      final engine = SheetsFormulaEngine({
        'A1': '=CEILING(-2.5,-2)',
        'A2': '=CEILING(-2.5,2)',
        'A3': '=FLOOR(-2.5,-2)',
        'A4': '=FLOOR(-2.5,2)',
        'A5': '=CEILING(2.5,-2)',
        'A6': '=FLOOR(2.5,-2)',
      });
      expect(engine.evaluateCell('A1'), -4);
      expect(engine.evaluateCell('A2'), -2);
      expect(engine.evaluateCell('A3'), -2);
      expect(engine.evaluateCell('A4'), -4);
      expect(engine.evaluateCell('A5'), isNull);
      expect(engine.evaluateCell('A6'), isNull);
    });

    test('treats non-finite cell text as text, not numeric data', () {
      final engine = SheetsFormulaEngine({
        'A1': 'NaN',
        'A2': 'Infinity',
        'B1': '=COUNT(A1,A2)',
        'B2': '=SUM(A1,A2)',
        'B3': '=A1+1',
        'C1': '',
        'C2': '=C1+1',
      });
      expect(engine.evaluateCell('A1'), isNull);
      expect(engine.evaluateCell('A2'), isNull);
      expect(engine.evaluateCell('B1'), 0);
      expect(engine.evaluateCell('B2'), 0);
      expect(engine.evaluateCell('B3'), isNull);
      expect(engine.evaluateCell('C2'), 1);
    });

    test('matches spreadsheet MOD sign rules for positive and negative divisors', () {
      final engine = SheetsFormulaEngine({
        'A1': '=MOD(-3,2)',
        'A2': '=MOD(3,-2)',
        'A3': '=MOD(-3,-2)',
        'A4': '=MOD(4,2)',
      });
      expect(engine.evaluateCell('A1'), 1);
      expect(engine.evaluateCell('A2'), -1);
      expect(engine.evaluateCell('A3'), -1);
      expect(engine.evaluateCell('A4'), 0);
    });

    test('aggregate functions ignore direct blank and text cell references', () {
      final engine = SheetsFormulaEngine({
        'A1': '',
        'A2': 'customer',
        'A3': '10',
        'B1': '=SUM(A1,A2,A3)',
        'B2': '=AVERAGE(A1,A2,A3)',
        'B3': '=COUNT(A1,A2,A3)',
        'B4': '=MIN(A1,A2,A3)',
        'B5': '=MAX(A1,A2,A3)',
        'B6': '=MEDIAN(A1,A2,A3)',
      });
      expect(engine.evaluateCell('B1'), 10);
      expect(engine.evaluateCell('B2'), 10);
      expect(engine.evaluateCell('B3'), 1);
      expect(engine.evaluateCell('B4'), 10);
      expect(engine.evaluateCell('B5'), 10);
      expect(engine.evaluateCell('B6'), 10);
    });

    test('rounding functions support negative precision and negative values', () {
      final engine = SheetsFormulaEngine({
        'A1': '=ROUND(1234,-2)',
        'A2': '=ROUNDUP(1234,-2)',
        'A3': '=ROUNDDOWN(1234,-2)',
        'A4': '=ROUNDUP(-1.231,2)',
        'A5': '=ROUNDDOWN(-1.239,2)',
        'A6': '=ROUND(1.25,1.5)',
      });
      expect(engine.evaluateCell('A1'), 1200);
      expect(engine.evaluateCell('A2'), 1300);
      expect(engine.evaluateCell('A3'), 1200);
      expect(engine.evaluateCell('A4'), -1.24);
      expect(engine.evaluateCell('A5'), -1.23);
      expect(engine.evaluateCell('A6'), isNull);
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


    test('rejects formulas that exceed safe length or token limits', () {
      final tooLong = SheetsFormulaEngine({
        'A1': '=${List.filled(2100, "1+").join()}1',
        'A2': '=${List.filled(1100, "1+").join()}1',
      });
      expect(tooLong.evaluateCell('A1'), isNull);
      expect(tooLong.evaluateCell('A2'), isNull);
    });


    test('resolves direct and aggregate references across worksheets', () {
      final sheets = <String, Map<String, String>>{
        'Sheet1': {'A1': '7', 'A2': '=Sheet2!A1+1', 'A3': '=SUM(\'Sales Data\'!B1:B3)'},
        'Sheet2': {'A1': '12'},
        'Sales Data': {'B1': '2', 'B2': '3', 'B3': '5', 'C1': '=Sheet1!A1*2'},
      };
      final engine = SheetsFormulaEngine(
        sheets['Sheet1']!,
        worksheets: sheets,
        activeSheetName: 'Sheet1',
      );
      expect(engine.evaluateCell('A2'), 13);
      expect(engine.evaluateCell('A3'), 10);
      final salesEngine = SheetsFormulaEngine(
        sheets['Sales Data']!,
        worksheets: sheets,
        activeSheetName: 'Sales Data',
      );
      expect(salesEngine.evaluateCell('C1'), 14);
    });

    test('rejects missing worksheets, invalid cross-sheet ranges and cross-sheet cycles', () {
      final sheets = <String, Map<String, String>>{
        'Sheet1': {'A1': '=Missing!A1', 'A2': '=SUM(Sheet2!A1:Sheet3!A1)', 'A3': '=Sheet2!A1'},
        'Sheet2': {'A1': '=Sheet1!A3'},
        'Sheet3': {'A1': '4'},
      };
      final engine = SheetsFormulaEngine(
        sheets['Sheet1']!,
        worksheets: sheets,
        activeSheetName: 'Sheet1',
      );
      expect(engine.evaluateCell('A1'), isNull);
      expect(engine.evaluateCell('A2'), isNull);
      expect(engine.evaluateCell('A3'), isNull);
    });

    test('supports additional Excel-compatible numeric and engineering functions', () {
      final engine = SheetsFormulaEngine({
        'A1': '=TRUNC(-8.9)',
        'A2': '=TRUNC(123.456,2)',
        'A3': '=TRUNC(1234,-2)',
        'A4': '=FACT(5)',
        'A5': '=EVEN(-3)',
        'A6': '=ODD(-2)',
        'A7': '=RADIANS(180)',
        'A8': '=DEGREES(PI())',
        'A9': '=GCD(24,36,60)',
        'A10': '=LCM(4,6,10)',
        'A11': '=COMBIN(5,2)',
        'A12': '=PERMUT(5,2)',
        'A13': '=QUOTIENT(-7,2)',
      });
      expect(engine.evaluateCell('A1'), -8);
      expect(engine.evaluateCell('A2'), closeTo(123.45, 1e-12));
      expect(engine.evaluateCell('A3'), 1200);
      expect(engine.evaluateCell('A4'), 120);
      expect(engine.evaluateCell('A5'), -4);
      expect(engine.evaluateCell('A6'), -3);
      expect(engine.evaluateCell('A7'), closeTo(math.pi, 1e-12));
      expect(engine.evaluateCell('A8'), closeTo(180, 1e-12));
      expect(engine.evaluateCell('A9'), 12);
      expect(engine.evaluateCell('A10'), 60);
      expect(engine.evaluateCell('A11'), 10);
      expect(engine.evaluateCell('A12'), 20);
      expect(engine.evaluateCell('A13'), -3);
    });

    test('rejects invalid integer arguments and unsafe combinatoric results', () {
      final engine = SheetsFormulaEngine({
        'A1': '=FACT(-1)',
        'A2': '=FACT(2.5)',
        'A3': '=GCD(2,2.5)',
        'A4': '=LCM(0,0)',
        'A5': '=COMBIN(4,5)',
        'A6': '=PERMUT(100,100)',
      });
      for (final row in [1, 2, 3, 5, 6]) {
        expect(engine.evaluateCell('A$row'), isNull);
      }
      // Excel's LCM of zero and zero is zero.
      expect(engine.evaluateCell('A4'), 0);
    });

    test('supports MROUND and extended trigonometric functions with domain checks', () {
      final engine = SheetsFormulaEngine({
        'A1': '=MROUND(10,3)',
        'A2': '=MROUND(-10,-3)',
        'A3': '=SINH(0)',
        'A4': '=COSH(0)',
        'A5': '=TANH(0)',
        'A6': '=COT(PI()/4)',
        'A7': '=ATAN2(1,1)',
        'A8': '=MROUND(10,-3)',
        'A9': '=COT(0)',
        'A10': '=ATAN2(0,0)',
      });
      expect(engine.evaluateCell('A1'), 9);
      expect(engine.evaluateCell('A2'), -9);
      expect(engine.evaluateCell('A3'), 0);
      expect(engine.evaluateCell('A4'), 1);
      expect(engine.evaluateCell('A5'), 0);
      expect(engine.evaluateCell('A6'), closeTo(1, 1e-12));
      expect(engine.evaluateCell('A7'), closeTo(math.pi / 4, 1e-12));
      expect(engine.evaluateCell('A8'), isNull);
      expect(engine.evaluateCell('A9'), isNull);
      expect(engine.evaluateCell('A10'), isNull);
    });

  });
}
