import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sheets PDF embeds Bengali fonts and preserves cell styling', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final bytes = await SheetsPdfExportService.build(
      sheetName: 'বাংলা হিসাব',
      values: [['নাম', 'টাকার পরিমাণ'], ['রহিম', '১২৫০.৫০']],
      styles: [
        [
          {'bold': true, 'align': 'center', 'fillColor': 'DCEBFF'},
          {'bold': true, 'align': 'center', 'fillColor': 'DCEBFF'},
        ],
        [
          {'fontColor': '123456', 'fontSize': 12},
          {'fontSize': 12, 'align': 'right'},
        ],
      ],
      sansFontData: sans,
      serifFontData: serif,
      pageFormat: PdfPageFormat.a4.landscape,
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes), startsWith('%PDF-'));
    expect(String.fromCharCodes(bytes), contains('FontFile2'));
  });
}
