import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_analytics.dart';

void main() {
  group('SheetsAnalytics range and conditional formatting', () {
    test('parses absolute and reversed ranges into normalized bounds', () {
      final range = SheetsAnalytics.parseRange(r'$C$8:$A$2');
      expect(range.firstRow, 2);
      expect(range.firstColumn, 1);
      expect(range.lastRow, 8);
      expect(range.lastColumn, 3);
      expect(SheetsAnalytics.columnName(27), 'AA');
      expect(SheetsAnalytics.columnNumber('AA'), 27);
    });

    test('rejects malformed, oversized and out-of-grid ranges', () {
      expect(() => SheetsAnalytics.parseRange('A0:B2'), throwsFormatException);
      expect(() => SheetsAnalytics.parseRange('A1:CW2'), throwsFormatException);
      expect(() => SheetsAnalytics.parseRange('A1:B1001'), throwsFormatException);
      expect(() => SheetsAnalytics.parseRange('A1:CV101'), throwsFormatException);
    });

    test('applies numeric, text and empty-cell rules only inside their ranges', () {
      final greater = SheetsAnalytics.createConditionalRule(
        range: 'B2:B8',
        operator: 'greaterThan',
        value: '100',
        fillColor: 'D9EAD3',
        fontColor: '1B5E20',
      );
      final contains = SheetsAnalytics.createConditionalRule(
        range: 'A1:A5',
        operator: 'contains',
        value: 'paid',
        fillColor: 'CFE2F3',
        fontColor: '0B5394',
      );
      final empty = SheetsAnalytics.createConditionalRule(
        range: 'C1:C5',
        operator: 'isEmpty',
        value: '',
        fillColor: 'F4CCCC',
        fontColor: '9C1C1C',
      );
      final rules = [greater, contains, empty];
      expect(
        SheetsAnalytics.conditionalStyleForCell('B3', '150', rules)['fillColor'],
        'D9EAD3',
      );
      expect(
        SheetsAnalytics.conditionalStyleForCell('B3', '50', rules),
        isEmpty,
      );
      expect(
        SheetsAnalytics.conditionalStyleForCell('A2', 'Already PAID', rules)['fontColor'],
        '0B5394',
      );
      expect(
        SheetsAnalytics.conditionalStyleForCell('C4', '', rules)['fillColor'],
        'F4CCCC',
      );
      expect(
        SheetsAnalytics.conditionalStyleForCell('D4', '150', rules),
        isEmpty,
      );
    });

    test('last matching conditional formatting rule overrides previous colors', () {
      final rules = [
        SheetsAnalytics.createConditionalRule(
          range: 'A1:A5',
          operator: 'greaterThan',
          value: '0',
          fillColor: 'D9EAD3',
          fontColor: '1B5E20',
        ),
        SheetsAnalytics.createConditionalRule(
          range: 'A1:A5',
          operator: 'greaterThan',
          value: '10',
          fillColor: 'FCE5CD',
          fontColor: '9C1C1C',
        ),
      ];
      expect(
        SheetsAnalytics.conditionalStyleForCell('A2', '15', rules),
        {'fillColor': 'FCE5CD', 'fontColor': '9C1C1C'},
      );
    });
  });

  group('SheetsAnalytics charts', () {
    final cells = <String, String>{
      'A1': 'Month', 'B1': 'Sales', 'C1': 'Cost',
      'A2': 'Jan', 'B2': '120', 'C2': '70',
      'A3': 'Feb', 'B3': '150', 'C3': '80',
      'A4': 'Mar', 'B4': '90', 'C4': '45',
    };

    test('builds multiple numeric series and category labels', () {
      final data = SheetsAnalytics.buildChartData(cells, 'A1:C4');
      expect(data.labels, ['Jan', 'Feb', 'Mar']);
      expect(data.series, hasLength(2));
      expect(data.series.first.name, 'Sales');
      expect(data.series.first.values, [120, 150, 90]);
      expect(data.series.last.values, [70, 80, 45]);
    });

    test('accepts an explicitly populated series containing only zero values', () {
      final data = SheetsAnalytics.buildChartData({
        'A1': 'Period', 'B1': 'Balance',
        'A2': 'Jan', 'B2': '0',
        'A3': 'Feb', 'B3': '0',
      }, 'A1:B3');
      expect(data.labels, ['Jan', 'Feb']);
      expect(data.series, hasLength(1));
      expect(data.series.single.values, [0, 0]);
    });

    test('rejects incomplete ranges and non-numeric data instead of drawing false charts', () {
      expect(() => SheetsAnalytics.buildChartData(cells, 'A1:A4'), throwsFormatException);
      expect(
        () => SheetsAnalytics.buildChartData({
          'A1': 'Month', 'B1': 'Sales', 'A2': 'Jan', 'B2': 'unknown',
        }, 'A1:B2'),
        throwsFormatException,
      );
    });
  });

  group('SheetsAnalytics Pivot summaries', () {
    final cells = <String, String>{
      'A1': 'Region', 'B1': 'Sales',
      'A2': 'North', 'B2': '100',
      'A3': 'South', 'B3': '80',
      'A4': 'North', 'B4': '50',
      'A5': 'South', 'B5': '20',
      'A6': 'North', 'B6': '',
    };

    test('groups rows and calculates sum, average, minimum and maximum', () {
      final sum = SheetsAnalytics.buildPivotSummary(
        cells: cells, rangeText: 'A1:B6', groupColumn: 'A',
        valueColumn: 'B', aggregation: 'sum',
      );
      expect(sum, [
        ['Region', 'SUM of Sales'],
        ['North', '150'],
        ['South', '100'],
        ['Grand Total', '250'],
      ]);
      final average = SheetsAnalytics.buildPivotSummary(
        cells: cells, rangeText: 'A1:B6', groupColumn: 'A',
        valueColumn: 'B', aggregation: 'average',
      );
      expect(average[1], ['North', '75']);
      expect(average.last, ['Grand Total', '62.5']);
      final min = SheetsAnalytics.buildPivotSummary(
        cells: cells, rangeText: 'A1:B6', groupColumn: 'A',
        valueColumn: 'B', aggregation: 'min',
      );
      expect(min[1], ['North', '50']);
      final max = SheetsAnalytics.buildPivotSummary(
        cells: cells, rangeText: 'A1:B6', groupColumn: 'A',
        valueColumn: 'B', aggregation: 'max',
      );
      expect(max[2], ['South', '80']);
    });

    test('counts non-empty value cells and includes groups with no values', () {
      final count = SheetsAnalytics.buildPivotSummary(
        cells: cells, rangeText: 'A1:B6', groupColumn: 'A',
        valueColumn: 'B', aggregation: 'count',
      );
      expect(count, [
        ['Region', 'COUNT of Sales'],
        ['North', '2'],
        ['South', '2'],
        ['Grand Total', '4'],
      ]);
    });

    test('rejects columns outside the source and non-numeric aggregate values', () {
      expect(
        () => SheetsAnalytics.buildPivotSummary(
          cells: cells, rangeText: 'A1:B6', groupColumn: 'A',
          valueColumn: 'C', aggregation: 'sum',
        ),
        throwsFormatException,
      );
      expect(
        () => SheetsAnalytics.buildPivotSummary(
          cells: {'A1': 'Region', 'B1': 'Sales', 'A2': 'North', 'B2': 'bad'},
          rangeText: 'A1:B2', groupColumn: 'A',
          valueColumn: 'B', aggregation: 'sum',
        ),
        throwsFormatException,
      );
    });
  });
}
