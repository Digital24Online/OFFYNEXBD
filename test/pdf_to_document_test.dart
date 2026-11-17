import 'package:flutter_test/flutter_test.dart';
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
    test('creates an empty editable paragraph for empty input', () {
      expect(PdfToDocumentService.plainTextToDelta('').single['insert'], '\n');
    });
  });
}
