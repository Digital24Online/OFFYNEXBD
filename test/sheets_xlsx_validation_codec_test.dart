import 'package:excel_community/excel_community.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_xlsx_validation_codec.dart';

void main() {
  group('SheetsXlsxValidationCodec', () {
    test('imports fixed dropdowns over every cell in an XLSX range', () {
      final workbook = xlsx.Excel.createExcel();
      final source = workbook['Sheet1'];
      source.addDataValidation(
        r'$C$2:$C$4',
        xlsx.DataValidation.list(['Pending', 'Paid', 'Due']),
      );

      final imported = SheetsXlsxValidationCodec.read(
        source,
        baseRows: 1,
        baseColumns: 1,
      );

      expect(imported.rows, 4);
      expect(imported.columns, 3);
      expect(imported.validations, {
        'C2': ['Pending', 'Paid', 'Due'],
        'C3': ['Pending', 'Paid', 'Due'],
        'C4': ['Pending', 'Paid', 'Due'],
      });
    });

    test('imports multiple separated ranges without losing their cells', () {
      final workbook = xlsx.Excel.createExcel();
      final source = workbook['Sheet1'];
      source.addDataValidation(
        'A1:A2 C3:C4',
        xlsx.DataValidation.list(['Yes', 'No']),
      );

      final imported = SheetsXlsxValidationCodec.read(
        source,
        baseRows: 1,
        baseColumns: 1,
      );

      expect(imported.validations.keys, containsAll(['A1', 'A2', 'C3', 'C4']));
      expect(imported.rows, 4);
      expect(imported.columns, 3);
    });

    test('rejects non-list and formula-backed dropdown rules rather than dropping them', () {
      final numericWorkbook = xlsx.Excel.createExcel();
      numericWorkbook['Sheet1'].addDataValidation(
        'A1',
        xlsx.DataValidation.wholeNumber(
          xlsx.DataValidationOperator.between,
          1,
          5,
        ),
      );
      expect(
        () => SheetsXlsxValidationCodec.read(
          numericWorkbook['Sheet1'],
          baseRows: 1,
          baseColumns: 1,
        ),
        throwsFormatException,
      );

      final formulaWorkbook = xlsx.Excel.createExcel();
      formulaWorkbook['Sheet1'].addDataValidation(
        'A1:A2',
        xlsx.DataValidation.listFromRange('B1:B2'),
      );
      expect(
        () => SheetsXlsxValidationCodec.read(
          formulaWorkbook['Sheet1'],
          baseRows: 1,
          baseColumns: 1,
        ),
        throwsFormatException,
      );
    });

    test('rejects ranges outside the supported grid and excessive expansion', () {
      final outsideWorkbook = xlsx.Excel.createExcel();
      outsideWorkbook['Sheet1'].addDataValidation(
        'A1:A1001',
        xlsx.DataValidation.list(['A', 'B']),
      );
      expect(
        () => SheetsXlsxValidationCodec.read(
          outsideWorkbook['Sheet1'],
          baseRows: 1,
          baseColumns: 1,
        ),
        throwsFormatException,
      );

      final largeWorkbook = xlsx.Excel.createExcel();
      largeWorkbook['Sheet1'].addDataValidation(
        'A1:CV101',
        xlsx.DataValidation.list(['A', 'B']),
      );
      expect(
        () => SheetsXlsxValidationCodec.read(
          largeWorkbook['Sheet1'],
          baseRows: 1,
          baseColumns: 1,
        ),
        throwsFormatException,
      );
    });

    test('exports grouped dropdown ranges and preserves them after XLSX round-trip', () {
      final workbook = xlsx.Excel.createExcel();
      final sheet = workbook['Sheet1'];
      SheetsXlsxValidationCodec.write(sheet, {
        'B2': ['Paid', 'Due'],
        'B3': ['Paid', 'Due'],
        'C2': ['Yes', 'No'],
      });

      expect(sheet.dataValidations.keys, contains('B2:B3'));
      final bytes = workbook.save();
      expect(bytes, isNotNull);
      final reopened = xlsx.Excel.decodeBytes(bytes!);
      final reopenedSheet = reopened['Sheet1'];
      expect(
        reopenedSheet.getDataValidation(xlsx.CellIndex.indexByString('B3'))?.listItems,
        ['Paid', 'Due'],
      );
      expect(
        reopenedSheet.getDataValidation(xlsx.CellIndex.indexByString('C2'))?.listItems,
        ['Yes', 'No'],
      );
    });

    test('rejects Excel dropdown lists that cannot be represented faithfully', () {
      final workbook = xlsx.Excel.createExcel();
      expect(
        () => SheetsXlsxValidationCodec.write(
          workbook['Sheet1'],
          {'A1': ['Option, with comma']},
        ),
        throwsFormatException,
      );
      expect(
        () => SheetsXlsxValidationCodec.write(
          workbook['Sheet1'],
          {'A1': [List.filled(256, 'X').join()]},
        ),
        throwsFormatException,
      );
    });
  });
}
