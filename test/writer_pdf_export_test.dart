import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:bangla_pdf/extract.dart';
import 'package:offynexbd/lib/modules/writer/writer_pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Writer PDF shapes Bengali and preserves styled Unicode text', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    const complexBangla = 'ক্ষ্ম ঙ্ক্ষ ত্ত্ব কর্ম ধর্ম প্রয়োজন কি কোথায়';
    const englishText = 'English mixed text — Office 365';
    const mixedText = 'English and বাংলা mixed — Office 365';
    final bytes = await WriterPdfExportService.build(
      title: 'বাংলা ডকুমেন্ট',
      delta: [
        {'insert': complexBangla, 'attributes': {'bold': true, 'font': 'serif', 'size': '24', 'color': '#123456'}},
        {'insert': '\n', 'attributes': {'align': 'center'}},
        {'insert': englishText, 'attributes': {'italic': true, 'underline': true}},
        {'insert': '\n'},
        {'insert': mixedText, 'attributes': {'bold': true}},
        {'insert': '\n'},
      ],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54, marginBottom: 54, marginLeft: 54, marginRight: 54,
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes), startsWith('%PDF-'));
    expect(String.fromCharCodes(bytes), contains('FontFile2'));
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains('বাংলা ডকুমেন্ট'));
    expect(extracted, contains(complexBangla));
    expect(extracted, contains(englishText));
    expect(extracted, contains(mixedText));
    expect(extracted, contains('ক্ষ্ম'));
    expect(extracted, isNot(contains('ঊহমষরংয')));
  });
  test('Writer PDF renders repeated header and dynamic page numbers', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    final bytes = await WriterPdfExportService.build(
      title: 'Header footer test',
      delta: [{'insert': 'Document body\n'}],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54,
      marginBottom: 54,
      marginLeft: 54,
      marginRight: 54,
      headerText: 'OFFYNEXBD Header',
      footerText: 'Page {page} of {pages}',
    );
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains('OFFYNEXBD Header'));
    expect(extracted, contains('Page 1 of 1'));
  });

}
