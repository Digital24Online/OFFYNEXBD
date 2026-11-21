/// Enforces the currently supported OFFYNEX Sheets grid size before XLSX import.
class SheetsWorkbookLimits {
  // Match the Excel worksheet grid so valid XLSX files are not rejected
  // by an arbitrary OFFYNEXBD-only row/column ceiling.
  static const int maxRows = 1048576;
  static const int maxColumns = 16384;
  static const int maxImportBytes = 20 * 1024 * 1024;

  static void validateImportBytes(int bytes) {
    if (bytes < 0 || bytes > maxImportBytes) {
      throw FormatException(
        'XLSX file exceeds the OFFYNEX Sheets import limit (20 MB). '
        'The existing workbook was not changed.',
      );
    }
  }

  static void validate(int rows, int columns) {
    if (rows > maxRows || columns > maxColumns) {
      throw FormatException(
        'Worksheet size exceeds OFFYNEX Sheets limit '
        '($maxRows rows × $maxColumns columns). '
        'The existing workbook was not changed.',
      );
    }
    if (rows < 0 || columns < 0) {
      throw const FormatException('Invalid worksheet dimensions');
    }
  }
}
