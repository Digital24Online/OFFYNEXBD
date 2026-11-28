import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/database_rows_query.dart';

void main() {
  final rows = <Map<String, dynamic>>[
    {'id': 'r1', 'values': {'Name': 'Rahim', 'Age': '9', 'Joined': '2025-01-02'}},
    {'id': 'r2', 'values': {'Name': 'Karim', 'Age': '12', 'Joined': '2024-06-01'}},
    {'id': 'r3', 'values': {'Name': 'Rashida', 'Age': '12', 'Joined': '2026-02-10'}},
  ];

  test('search is case-insensitive across configured fields', () {
    final result = DatabaseRowsQuery.apply(
      rows: rows,
      fields: const ['Name', 'Age'],
      query: 'RAH',
    );
    expect(result.map((row) => row['id']), ['r1']);
  });

  test('numeric sorting compares values numerically and is stable for ties', () {
    final result = DatabaseRowsQuery.apply(
      rows: rows,
      fields: const ['Name', 'Age'],
      sortField: 'Age',
    );
    expect(result.map((row) => row['id']), ['r1', 'r2', 'r3']);
  });

  test('date sorting and descending order are supported', () {
    final result = DatabaseRowsQuery.apply(
      rows: rows,
      fields: const ['Name', 'Joined'],
      sortField: 'Joined',
      ascending: false,
    );
    expect(result.map((row) => row['id']), ['r3', 'r1', 'r2']);
  });

  test('mixed-type sorting is deterministic and keeps blank values last', () {
    final mixedRows = <Map<String, dynamic>>[
      {'id': 'text', 'values': {'Value': 'Alpha'}},
      {'id': 'blank', 'values': {'Value': ' '}},
      {'id': 'date', 'values': {'Value': '2025-01-01'}},
      {'id': 'number', 'values': {'Value': '12'}},
      {'id': 'number2', 'values': {'Value': '3'}},
    ];
    final ascending = DatabaseRowsQuery.apply(
      rows: mixedRows,
      fields: const ['Value'],
      sortField: 'Value',
    );
    expect(ascending.map((row) => row['id']), [
      'number2', 'number', 'date', 'text', 'blank',
    ]);
    final descending = DatabaseRowsQuery.apply(
      rows: mixedRows,
      fields: const ['Value'],
      sortField: 'Value',
      ascending: false,
    );
    expect(descending.map((row) => row['id']), [
      'text', 'date', 'number', 'number2', 'blank',
    ]);
  });

  test('query operation does not mutate the stored row order or values', () {
    final original = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    DatabaseRowsQuery.apply(
      rows: rows,
      fields: const ['Name', 'Age'],
      query: 'r',
      sortField: 'Age',
      ascending: false,
    );
    expect(rows, original);
  });
}
