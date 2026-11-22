import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:bangla_pdf/extract.dart';
import 'package:bangla_pdf/widgets.dart' as pw;
import 'package:offynexbd/lib/modules/writer/writer_pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Writer PDF maps text highlight and combined underline/strikethrough attributes', () {
    final highlight = WriterPdfExportService.highlightColorForAttributes({
      'background': '#FFF200',
    });
    expect(highlight, isNotNull);

    final decoration = WriterPdfExportService.textDecorationForAttributes({
      'underline': true,
      'strike': true,
    });
    expect(decoration, isNotNull);
    expect(decoration!.contains(pw.TextDecoration.underline), isTrue);
    expect(decoration.contains(pw.TextDecoration.lineThrough), isTrue);

    expect(
      WriterPdfExportService.textDecorationForAttributes({'underline': true})!
          .contains(pw.TextDecoration.underline),
      isTrue,
    );
    expect(
      WriterPdfExportService.textDecorationForAttributes({'strike': true})!
          .contains(pw.TextDecoration.lineThrough),
      isTrue,
    );
    expect(
      WriterPdfExportService.textDecorationForAttributes(const {}),
      isNull,
    );
  });

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
  test('Writer PDF preserves all six Word heading levels in exported content', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    final bytes = await WriterPdfExportService.build(
      title: 'Heading export',
      delta: [
        {'insert': 'Heading four\n', 'attributes': {'header': 4}},
        {'insert': 'Heading five\n', 'attributes': {'header': 5}},
        {'insert': 'Heading six\n', 'attributes': {'header': 6}},
      ],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54, marginBottom: 54, marginLeft: 54, marginRight: 54,
    );
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains('Heading four'));
    expect(extracted, contains('Heading five'));
    expect(extracted, contains('Heading six'));
  });

  test('Writer PDF accepts imported Bengali font families from the document font library', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    final bytes = await WriterPdfExportService.build(
      title: 'Custom font test',
      delta: [
        {'insert': 'কাস্টম বাংলা ফন্ট', 'attributes': {'font': 'OFFYNEX Test Bengali'}},
        {'insert': '\n'},
      ],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      customFontData: {'OFFYNEX Test Bengali': sans},
      pageFormat: PdfPageFormat.a4,
      marginTop: 54, marginBottom: 54, marginLeft: 54, marginRight: 54,
    );
    expect(bytes.length, greaterThan(1000));
    expect(BanglaPdfExtractor.extract(bytes).text, contains('কাস্টম বাংলা ফন্ট'));
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

  test('Writer PDF does not duplicate a title already in the first body paragraph', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    const title = 'OFFYNEXBD report title';
    final bytes = await WriterPdfExportService.build(
      title: title,
      delta: [
        {'insert': '$title\n'},
        {'insert': 'Document body\n'},
      ],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54,
      marginBottom: 54,
      marginLeft: 54,
      marginRight: 54,
    );
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted.split(title).length - 1, 1);
  });

  test('Writer PDF inserts metadata title when body starts with different text', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    const title = 'OFFYNEXBD metadata title';
    final bytes = await WriterPdfExportService.build(
      title: title,
      delta: [{'insert': 'Body starts here\n'}],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54,
      marginBottom: 54,
      marginLeft: 54,
      marginRight: 54,
    );
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains(title));
    expect(extracted, contains('Body starts here'));
  });

  test('Writer PDF preserves bullet and numbered list markers and indentation', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    final bytes = await WriterPdfExportService.build(
      title: 'List export test',
      delta: [
        {'insert': 'Bullet item\n', 'attributes': {'list': 'bullet'}},
        {'insert': 'First numbered item\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'Second numbered item\n', 'attributes': {'list': 'ordered', 'indent': 1}},
      ],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54,
      marginBottom: 54,
      marginLeft: 54,
      marginRight: 54,
    );
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains('•'));
    expect(extracted, contains('Bullet item'));
    expect(extracted, contains('1.'));
    expect(extracted, contains('First numbered item'));
    expect(extracted, contains('2.'));
    expect(extracted, contains('Second numbered item'));
  });


  test('Writer PDF keeps content on both sides of an explicit page break', () async {
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    final bytes = await WriterPdfExportService.build(
      title: 'Page break export test',
      delta: [
        {'insert': 'First page content\n'},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
        {'insert': 'Second page content\n'},
      ],
      sansFontData: sans,
      serifFontData: serif,
      latinFontData: latin,
      pageFormat: PdfPageFormat.a4,
      marginTop: 54,
      marginBottom: 54,
      marginLeft: 54,
      marginRight: 54,
    );
    final extracted = BanglaPdfExtractor.extract(bytes).text;
    expect(extracted, contains('First page content'));
    expect(extracted, contains('Second page content'));
  });

}
