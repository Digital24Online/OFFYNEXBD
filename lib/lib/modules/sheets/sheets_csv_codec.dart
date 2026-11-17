/// RFC 4180-style CSV codec used by OFFYNEX Sheets.
class SheetsCsvCodec {
  const SheetsCsvCodec._();

  static List<List<String>> decode(String source) {
    var text = source;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    if (text.isEmpty) return const [];

    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var quoteClosed = false;
    var rowStarted = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
            quoteClosed = true;
          }
        } else {
          field.write(char);
        }
        continue;
      }

      if (quoteClosed) {
        if (char == ',') {
          row.add(field.toString());
          field.clear();
          quoteClosed = false;
          rowStarted = true;
        } else if (char == '\n' || char == '\r') {
          row.add(field.toString());
          field.clear();
          rows.add(row);
          row = <String>[];
          quoteClosed = false;
          rowStarted = false;
          if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        } else {
          throw const FormatException('Unexpected character after closing CSV quote');
        }
        continue;
      }

      if (char == '"') {
        if (field.isNotEmpty) {
          throw const FormatException('CSV quote must begin at the start of a field');
        }
        inQuotes = true;
        rowStarted = true;
      } else if (char == ',') {
        row.add(field.toString());
        field.clear();
        rowStarted = true;
      } else if (char == '\n' || char == '\r') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
        rowStarted = false;
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      } else {
        field.write(char);
        rowStarted = true;
      }
    }

    if (inQuotes) throw const FormatException('Unclosed quoted CSV field');
    if (rowStarted || row.isNotEmpty || quoteClosed || field.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static String encode(List<List<String>> rows) {
    String encodeField(String value) {
      if (value.contains(',') ||
          value.contains('"') ||
          value.contains('\r') ||
          value.contains('\n')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }

    return rows
        .map((row) => row.map(encodeField).join(','))
        .join('\r\n');
  }
}
