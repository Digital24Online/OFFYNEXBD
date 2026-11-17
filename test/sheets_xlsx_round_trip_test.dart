import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OFFYNEX Sheets XLSX workbook round-trip', () {
    test('preserves text, numbers, booleans and formulas', () {
      final source = xlsx.Excel.createExcel();
      final sheet = source['Sheet1'];
      sheet.cell(xlsx.CellIndex.indexByString('A1')).value =
          xlsx.TextCellValue('Customer');
      sheet.cell(xlsx.CellIndex.indexByString('A2')).value =
          xlsx.IntCellValue(125);
      sheet.cell(xlsx.CellIndex.indexByString('A3')).value =
          xlsx.DoubleCellValue(12.5);
      sheet.cell(xlsx.CellIndex.indexByString('A4')).value =
          xlsx.BoolCellValue(true);
      sheet.cell(xlsx.CellIndex.indexByString('B1')).value =
          xlsx.FormulaCellValue('SUM(A2:A3)');

      final bytes = source.save();
      expect(bytes, isNotNull);

      final restored = xlsx.Excel.decodeBytes(bytes!);
      final result = restored['Sheet1'];
      expect(result.cell(xlsx.CellIndex.indexByString('A1')).value.toString(),
          'Customer');
      expect(result.cell(xlsx.CellIndex.indexByString('A2')).value.toString(),
          '125');
      expect(result.cell(xlsx.CellIndex.indexByString('A3')).value.toString(),
          '12.5');
      expect(result.cell(xlsx.CellIndex.indexByString('A4')).value.toString(),
          'true');
      expect(
        result.cell(xlsx.CellIndex.indexByString('B1')).value.toString(),
        contains('SUM(A2:A3)'),
      );
    });

    test('preserves supported cell formatting', () {
      final source = xlsx.Excel.createExcel();
      final cell = source['Sheet1'].cell(
        xlsx.CellIndex.indexByString('A1'),
      );
      cell.value = xlsx.TextCellValue('Formatted');
      cell.cellStyle = xlsx.CellStyle(
        bold: true,
        italic: true,
        underline: xlsx.Underline.Single,
        fontSize: 16,
        horizontalAlign: xlsx.HorizontalAlign.Center,
        verticalAlign: xlsx.VerticalAlign.Top,
        textWrapping: xlsx.TextWrapping.WrapText,
        numberFormat: xlsx.CustomNumericNumFormat(formatCode: '#,##0.00'),
        leftBorder: xlsx.Border(borderStyle: xlsx.BorderStyle.Thin),
      );

      final bytes = source.save();
      expect(bytes, isNotNull);

      final restored = xlsx.Excel.decodeBytes(bytes!);
      final style = restored['Sheet1']
          .cell(xlsx.CellIndex.indexByString('A1'))
          .cellStyle;
      expect(style, isNotNull);
      expect(style!.isBold, isTrue);
      expect(style.isItalic, isTrue);
      expect(style.underline, xlsx.Underline.Single);
      expect(style.fontSize, 16);
      expect(style.horizontalAlignment, xlsx.HorizontalAlign.Center);
      expect(style.verticalAlignment, xlsx.VerticalAlign.Top);
      expect(style.wrap, xlsx.TextWrapping.WrapText);
      expect(style.leftBorder.borderStyle, isNotNull);
    });
  });
}
