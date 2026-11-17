/// Enforces the currently supported OFFYNEX Sheets grid size before XLSX import.
class SheetsWorkbookLimits {
  static const int maxRows = 1000;
  static const int maxColumns = 100;

  static void validate(int rows, int columns) {
    if (rows > maxRows || columns > maxColumns) {
      throw FormatException(
        'Worksheet size exceeds OFFYNEX Sheets limit '
        '(${maxRows} rows × ${maxColumns} columns). '
        'The existing workbook was not changed.',
      );
    }
    if (rows < 0 || columns < 0) {
      throw const FormatException('Invalid worksheet dimensions');
    }
  }
}
