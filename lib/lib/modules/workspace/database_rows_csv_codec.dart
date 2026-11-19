import 'dart:convert';

/// Safe CSV interchange for offline Database table rows.
class DatabaseRowsCsvCodec {
  const DatabaseRowsCsvCodec._();

  static const int maxBytes = 10 * 1024 * 1024;
  static const int maxRows = 100000;

  static String encode({
    required List<String> fields,
    required List<Map<String, dynamic>> rows,
  }) {
    _validateFields(fields);
    if (rows.isEmpty) {
      throw const FormatException('There are no database rows to export.');
    }
    if (rows.length > maxRows) {
      throw const FormatException('Database CSV exceeds the 100,000-row limit.');
    }
    String safeCell(String value) {
      final trimmed = value.trimLeft();
      if (trimmed.isNotEmpty && '=+-@'.contains(trimmed[0])) return "'$value";
      return value;
    }
    String quote(String value) {
      final safe = safeCell(value);
      final escaped = safe.replaceAll('"', '""');
      return '"$escaped"';
    }
    final lines = <String>[
      fields.map(quote).join(','),
      for (final row in rows)
        fields.map((field) {
          final values = row['values'];
          if (values is! Map || (values[field] != null && values[field] is! String)) {
            throw FormatException('Database row contains an invalid value for "$field".');
          }
          return quote(values[field]?.toString() ?? '');
        }).join(','),
    ];
    final result = '\uFEFF${lines.join('\r\n')}\r\n';
    if (utf8.encode(result).length > maxBytes) {
      throw const FormatException('Database CSV exceeds the 10 MB limit.');
    }
    return result;
  }

  static List<Map<String, dynamic>> decode(
    List<int> bytes, {
    required List<String> expectedFields,
  }) {
    _validateFields(expectedFields);
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Database CSV must be between 1 byte and 10 MB.');
    }
    var source = utf8.decode(bytes, allowMalformed: false);
    if (source.startsWith('\uFEFF')) source = source.substring(1);
    final records = _parse(source);
    while (records.isNotEmpty && records.last.length == 1 && records.last.first.isEmpty) {
      records.removeLast();
    }
    if (records.isEmpty) throw const FormatException('Database CSV is empty.');
    final header = records.first;
    if (header.length != expectedFields.length ||
        header.asMap().entries.any((entry) => entry.value != expectedFields[entry.key])) {
      throw const FormatException('CSV columns do not match this database table.');
    }
    if (records.length - 1 > maxRows) {
      throw const FormatException('Database CSV exceeds the 100,000-row limit.');
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final rows = <Map<String, dynamic>>[];
    for (var index = 1; index < records.length; index++) {
      final record = records[index];
      if (record.length == 1 && record.first.isEmpty) continue;
      if (record.length != expectedFields.length) {
        throw FormatException('CSV row ${index + 1} has an incorrect column count.');
      }
      rows.add({
        'id': 'csv-$stamp-$index',
        'values': {
          for (var column = 0; column < expectedFields.length; column++)
            expectedFields[column]: record[column],
        },
      });
    }
    return rows;
  }

  static void _validateFields(List<String> fields) {
    if (fields.isEmpty ||
        fields.length > 40 ||
        fields.any((field) => field.trim().isEmpty) ||
        fields.toSet().length != fields.length) {
      throw const FormatException('Database table must have 1–40 unique, non-empty fields.');
    }
  }

  static List<List<String>> _parse(String source) {
    final records = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    var closedQuote = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
            closedQuote = true;
          }
        } else {
          cell.write(char);
        }
        continue;
      }
      if (closedQuote && char != ',' && char != '\r' && char != '\n') {
        throw const FormatException('CSV contains characters after a closing quote.');
      }
      if (char == '"' && cell.isEmpty && !closedQuote) {
        quoted = true;
      } else if (char == ',') {
        row.add(cell.toString());
        cell.clear();
        closedQuote = false;
      } else if (char == '\r' || char == '\n') {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
        row.add(cell.toString());
        records.add(row);
        row = <String>[];
        cell.clear();
        closedQuote = false;
      } else {
        cell.write(char);
      }
    }
    if (quoted) throw const FormatException('CSV contains an unclosed quoted field.');
    if (cell.isNotEmpty || row.isNotEmpty || closedQuote) {
      row.add(cell.toString());
      records.add(row);
    }
    return records;
  }
}
