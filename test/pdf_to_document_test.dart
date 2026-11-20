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

    test('builds a real editable DOCX from Bangla and English OCR text', () async {
      final bytes = await PdfToDocumentService.buildDocxFromPlainText(
        'বাংলা OCR লেখা\nEnglish OCR text',
      );
      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('accepts supported image extensions without case sensitivity', () {
      expect(PdfToDocumentService.isSupportedImageName('scan.JPG'), isTrue);
      expect(PdfToDocumentService.isSupportedImageName('paper.png'), isTrue);
      expect(PdfToDocumentService.isSupportedImageName('photo.webp'), isTrue);
      expect(PdfToDocumentService.isSupportedImageName('file.pdf'), isFalse);
      expect(PdfToDocumentService.isSupportedImageName('file.txt'), isFalse);
    });
    test('validates actual image signatures against file extensions', () {
      expect(PdfToDocumentService.hasValidImageSignature(
        Uint8List.fromList([0xFF, 0xD8, 0xFF]), 'scan.jpg'), isTrue);
      expect(PdfToDocumentService.hasValidImageSignature(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), 'scan.png'), isTrue);
      expect(PdfToDocumentService.hasValidImageSignature(
        Uint8List.fromList([0xFF, 0xD8, 0xFF]), 'scan.png'), isFalse);
    });

    test('OCR rejects image bytes whose signature disagrees with the extension', () async {
      await expectLater(
        PdfToDocumentService.recognizeImageBytes(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]),
          sourceName: 'spoofed.png',
        ),
        throwsFormatException,
      );
      await expectLater(
        PdfToDocumentService.recognizeImageBytes(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
          sourceName: 'spoofed.jpg',
        ),
        throwsFormatException,
      );
    });

    test('creates an empty editable paragraph for empty input', () {
      expect(PdfToDocumentService.plainTextToDelta('').single['insert'], '\n');
    });

    test('rejects PDFs larger than the conversion safety limit before parsing', () async {
      final oversized = Uint8List(PdfToDocumentService.maxPdfBytes + 1);
      await expectLater(
        PdfToDocumentService.convert(
          oversized,
          sourceName: 'oversized.pdf',
          runOcr: false,
        ),
        throwsFormatException,
      );
    });


    test('validates PDF page bounds and DOCX ZIP signatures', () {
      expect(() => PdfToDocumentService.validatePageCount(1), returnsNormally);
      expect(() => PdfToDocumentService.validatePageCount(1000), returnsNormally);
      expect(() => PdfToDocumentService.validatePageCount(0), throwsFormatException);
      expect(() => PdfToDocumentService.validatePageCount(1001), throwsFormatException);
      expect(
        PdfToDocumentService.isValidDocxBytes(
          Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]),
        ),
        isTrue,
      );
      expect(
        PdfToDocumentService.isValidDocxBytes(
          Uint8List.fromList([0x50, 0x4B, 0x00, 0x00]),
        ),
        isFalse,
      );
    });


    test('validates PDF byte signature and size for reader input', () {
      expect(
        () => PdfToDocumentService.validatePdfBytes(
          Uint8List.fromList('%PDF-1.7'.codeUnits),
        ),
        returnsNormally,
      );
      expect(
        () => PdfToDocumentService.validatePdfBytes(Uint8List(0)),
        throwsFormatException,
      );
      expect(
        () => PdfToDocumentService.validatePdfBytes(
          Uint8List.fromList('%PDF-9.9'.codeUnits),
        ),
        throwsFormatException,
      );
      expect(
        () => PdfToDocumentService.validatePdfBytes(
          Uint8List.fromList('NOT A PDF'.codeUnits),
        ),
        throwsFormatException,
      );
      expect(
        () => PdfToDocumentService.validatePdfBytes(
          Uint8List(PdfToDocumentService.maxPdfBytes + 1),
        ),
        throwsFormatException,
      );
    });

  });
}
