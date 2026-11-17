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
    const complexBangla = 'ক্ষ্ম ঙ্ক্ষ ত্ত্ব কর্ম ধর্ম প্রয়োজন কি কোথায়';
    final bytes = await WriterPdfExportService.build(
      title: 'বাংলা ডকুমেন্ট',
      delta: [
        {'insert': complexBangla, 'attributes': {'bold': true, 'font': 'serif', 'size': '24', 'color': '#123456'}},
        {'insert': '\n', 'attributes': {'align': 'center'}},
        {'insert': 'English mixed text', 'attributes': {'italic': true, 'underline': true}},
        {'insert': '\n'},
      ],
      sansFontData: sans,
      serifFontData: serif,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54, marginBottom: 54, marginLeft: 54, marginRight: 54,
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes), startsWith('%PDF-'));
    expect(String.fromCharCodes(bytes), contains('FontFile2'));
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains('বাংলা ডকুমেন্ট'));
    expect(extracted, contains(complexBangla));
    expect(extracted, contains('English mixed text'));
  });
}
