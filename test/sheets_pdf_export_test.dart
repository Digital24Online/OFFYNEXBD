import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:bangla_pdf/extract.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sheets PDF shapes Bengali and retains cell formatting and Unicode text', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    const complexBangla = 'ক্ষ্ম ঙ্ক্ষ ত্ত্ব কর্ম ধর্ম প্রয়োজন কি কোথায়';
    const englishText = 'English mixed text — Office 365';
    final bytes = await SheetsPdfExportService.build(
      sheetName: 'বাংলা হিসাব',
      values: [
        ['নাম', 'টাকার পরিমাণ'],
        [englishText, 'Office 365'],
        ['রহিম', '১২৫০.৫০'],
        [complexBangla, '৳১২৫০'],
      ],
      styles: [
        [
          {'bold': true, 'align': 'center', 'fillColor': 'DCEBFF', 'border': true},
          {'bold': true, 'align': 'center', 'fillColor': 'DCEBFF'},
        ],
        [
          {'fontColor': '123456', 'fontSize': 12, 'verticalAlign': 'bottom'},
          {'fontSize': 12, 'align': 'right', 'wrapText': true},
        ],
        [
          {'fontFamily': 'serif', 'italic': true, 'wrapText': true},
          {'underline': true, 'align': 'right'},
        ],
      ],
      sansFontData: sans,
      serifFontData: serif,
      showGridlines: true,
      pageFormat: PdfPageFormat.a4.landscape,
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes), startsWith('%PDF-'));
    expect(String.fromCharCodes(bytes), contains('FontFile2'));
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains('বাংলা হিসাব'));
    expect(extracted, contains(complexBangla));
    expect(extracted, contains('৳১২৫০'));
    expect(extracted, contains(englishText));
  });
}
