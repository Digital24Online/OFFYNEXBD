import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/database_rows_csv_codec.dart';

void main() {
  const fields = ['নাম', 'Phone', 'Address'];

  test('CSV round trip preserves Bengali, commas, quotes and multiline cells', () {
    final rows = [
      {
        'id': 'row-1',
        'values': {
          'নাম': 'রহিম, করিম',
          'Phone': '01700000000',
          'Address': 'House "A"\nRoad 2',
        },
      },
    ];
    final csv = DatabaseRowsCsvCodec.encode(fields: fields, rows: rows);
    expect(csv.startsWith('\uFEFF'), isTrue);
    final decoded = DatabaseRowsCsvCodec.decode(
      utf8.encode(csv),
      expectedFields: fields,
    );
    expect(decoded, hasLength(1));
    expect(decoded.single['values'], rows.single['values']);
  });

  test('CSV import rejects a different or reordered schema', () {
    final csv = utf8.encode('\uFEFFPhone,নাম,Address\r\n01700000000,রহিম,ঢাকা');
    expect(
      () => DatabaseRowsCsvCodec.decode(csv, expectedFields: fields),
      throwsFormatException,
    );
  });

  test('CSV import rejects malformed quote and wrong column count', () {
    expect(
      () => DatabaseRowsCsvCodec.decode(
        utf8.encode('নাম,Phone,Address\n"রহিম,01700000000,ঢাকা'),
        expectedFields: fields,
      ),
      throwsFormatException,
    );
    expect(
      () => DatabaseRowsCsvCodec.decode(
        utf8.encode('নাম,Phone,Address\nরহিম,01700000000'),
        expectedFields: fields,
      ),
      throwsFormatException,
    );
  });

  test('CSV import rejects duplicate or empty schema fields', () {
    expect(
      () => DatabaseRowsCsvCodec.decode(
        utf8.encode('Name,Name\nA,B'),
        expectedFields: ['Name', 'Name'],
      ),
      throwsFormatException,
    );
  });

  test('CSV export rejects empty tables and invalid row values', () {
    expect(
      () => DatabaseRowsCsvCodec.encode(fields: fields, rows: []),
      throwsFormatException,
    );
    expect(
      () => DatabaseRowsCsvCodec.encode(
        fields: fields,
        rows: [{'id': '1', 'values': {'নাম': 7}}],
      ),
      throwsFormatException,
    );
  });
}
