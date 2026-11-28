import 'sheets_workbook_codec.dart';

/// Prevents XLSX export from silently dropping workbook features that the
/// current XLSX writer does not serialize as native Excel structures.
class SheetsXlsxExportGuard {
  const SheetsXlsxExportGuard._();

  static List<String> unsupportedFeatures(SheetsWorkbook workbook) {
    final features = <String>{};
    for (final sheet in workbook.sheets) {
      if (sheet.charts.isNotEmpty) features.add('charts');
      if (sheet.pivotConfig != null) features.add('pivotTables');
      if (sheet.conditionalFormats.isNotEmpty) {
        features.add('conditionalFormatting');
      }
    }
    return features.toList(growable: false);
  }
}
