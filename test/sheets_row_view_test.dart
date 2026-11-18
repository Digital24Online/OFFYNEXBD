import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_row_view.dart';

void main() {
  group('SheetsRowView', () {
    const values = ['Name', 'Zara', '10', '2', '', 'apple'];
    String valueForRow(int row) => values[row];

    test('sorts ascending numerically and alphabetically, with blanks last', () {
      expect(
        SheetsRowView.buildOrder(rowCount: values.length, valueForRow: valueForRow, sortAscending: true),
        [3, 2, 5, 0, 1, 4],
      );
    });

    test('sorts descending and keeps blank cells last', () {
      expect(
        SheetsRowView.buildOrder(rowCount: values.length, valueForRow: valueForRow, sortAscending: false),
        [1, 0, 5, 2, 3, 4],
      );
    });

    test('filters case-insensitively without changing source row indices', () {
      expect(
        SheetsRowView.buildOrder(rowCount: values.length, valueForRow: valueForRow, filter: 'a'),
        [0, 1, 5],
      );
    });

    test('combines filtering and sorting', () {
      expect(
        SheetsRowView.buildOrder(rowCount: values.length, valueForRow: valueForRow, filter: 'a', sortAscending: true),
        [5, 0, 1],
      );
    });

    test('returns every original row when no view operation is active', () {
      expect(
        SheetsRowView.buildOrder(rowCount: values.length, valueForRow: valueForRow),
        [0, 1, 2, 3, 4, 5],
      );
    });
  });
}
