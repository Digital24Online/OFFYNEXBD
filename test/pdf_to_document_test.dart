import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:offynexbd/lib/modules/pdf/pdf_to_document_service.dart';

void main() {
  group('PDF to Writer helpers', () {
    test('converts Bangla and English text to a Quill delta', () {
      final delta = PdfToDocumentService.plainTextToDelta('বাংলা লেখা\nEnglish text');
      expect(delta.single['insert'], 'বাংলা লেখা\nEnglish text\n');
    });
    test('keeps an existing final newline', () {
      final delta = PdfToDocumentService.plainTextToDelta('Page one\n');
      expect(delta.single['insert'], 'Page one\n');
    });
    test('extracts text and creates DOCX from a generated PDF', () async {
      final source = pw.Document();
      source.addPage(pw.Page(
        build: (_) => pw.Center(child: pw.Text('PDF conversion integration test')),
      ));
      final bytes = Uint8List.fromList(await source.save());
      final converted = await PdfToDocumentService.convert(
        bytes,
        sourceName: 'integration.pdf',
        runOcr: false,
      );
      final writerText = converted.writerDelta
          .map((operation) => operation['insert'])
          .whereType<String>()
          .join();
      expect(converted.pageCount, 1);
      expect(writerText, contains('PDF conversion integration test'));
      expect(converted.docxBytes, isNotEmpty);
    });

    test('creates an empty editable paragraph for empty input', () {
      expect(PdfToDocumentService.plainTextToDelta('').single['insert'], '\n');
    });
  });
}
