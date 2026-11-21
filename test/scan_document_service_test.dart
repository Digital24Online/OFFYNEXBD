import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/scan_document_service.dart';

void main() {
  group('ScanDocumentService', () {
    test('keeps a scan PDF while a Writer document references it', () {
      const path = '/OFFYNEXBD/Scans/scan-1.pdf';
      expect(
        ScanDocumentService.isPdfReferencedByWriterDocuments(path, [
          {'id': 'writer-1', 'scanPdfPath': path},
        ]),
        isTrue,
      );
      expect(
        ScanDocumentService.isPdfReferencedByWriterDocuments(path, [
          {'id': 'writer-1', 'scanPdfPath': ' /OFFYNEXBD/Scans/scan-1.pdf '},
        ]),
        isTrue,
      );
      expect(
        ScanDocumentService.isPdfReferencedByWriterDocuments(path, [
          {'id': 'writer-2', 'scanPdfPath': '/OFFYNEXBD/Scans/other.pdf'},
        ]),
        isFalse,
      );
      expect(
        ScanDocumentService.isPdfReferencedByWriterDocuments(path, const []),
        isFalse,
      );
    });

    test('removes only the final PDF extension from scan display titles', () {
      expect(ScanDocumentService.displayTitleFromPdfFileName('scan.pdf'), 'scan');
      expect(ScanDocumentService.displayTitleFromPdfFileName('SCAN.PDF'), 'SCAN');
      expect(ScanDocumentService.displayTitleFromPdfFileName('my.scan.pdf'), 'my.scan');
      expect(ScanDocumentService.displayTitleFromPdfFileName('scan.jpg'), 'scan.jpg');
      expect(ScanDocumentService.displayTitleFromPdfFileName('  scan.pdf  '), 'scan');
    });

    test('combines recognized pages in order and separates page text', () {
      expect(
        ScanDocumentService.combineRecognizedPages([
          'প্রথম পৃষ্ঠা',
          '  Second page  ',
          '   ',
          'Third page',
        ]),
        'প্রথম পৃষ্ঠা\n\nSecond page\n\nThird page',
      );
    });

    test('preserves recognized page order while ignoring blank OCR pages', () {
      expect(
        ScanDocumentService.combineRecognizedPages([
          'Page one', '', '  ', 'Page three',
        ]),
        'Page one\n\nPage three',
      );
    });

    test('returns empty text when every page has no recognized text', () {
      expect(
        ScanDocumentService.combineRecognizedPages(['', '  ', '\n']),
        isEmpty,
      );
    });

    test('accepts multiple supported image pages for imported scans', () {
      expect(
        () => ScanDocumentService.validateImportedImages([
          (name: 'page-1.jpg', bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9])),
          (name: 'page-2.PNG', bytes: Uint8List.fromList([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          ])),
        ]),
        returnsNormally,
      );
    });

    test('rejects empty, excessive, unsupported and empty imported pages', () {
      expect(
        () => ScanDocumentService.validateImportedImages([]),
        throwsFormatException,
      );
      expect(
        () => ScanDocumentService.validateImportedImages(
          List.generate(
            ScanDocumentService.maxPages + 1,
            (index) => (name: 'page-$index.jpg', bytes: Uint8List.fromList([1])),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => ScanDocumentService.validateImportedImages([
          (name: 'page.gif', bytes: Uint8List.fromList([1])),
        ]),
        throwsFormatException,
      );
      expect(
        () => ScanDocumentService.validateImportedImages([
          (name: 'page.png', bytes: Uint8List(0)),
        ]),
        throwsFormatException,
      );
      expect(
        () => ScanDocumentService.validateImportedImages([
          (name: 'mislabelled.jpg', bytes: Uint8List.fromList([1, 2, 3, 4])),
        ]),
        throwsFormatException,
      );
      expect(
        () => ScanDocumentService.validateImportedImages([
          (name: 'mislabelled.png', bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF])),
        ]),
        throwsFormatException,
      );
    });

    test('rejects empty, malformed, oversized and out-of-range scan output', () {
      final valid = Uint8List.fromList('%PDF-1.7'.codeUnits);
      expect(() => ScanDocumentService.validateCapturedPdf(valid, 1), returnsNormally);
      expect(() => ScanDocumentService.validateCapturedPdf(valid, 0), throwsFormatException);
      expect(
        () => ScanDocumentService.validateCapturedPdf(
          Uint8List.fromList('%PDF-9.9'.codeUnits), 1,
        ),
        throwsFormatException,
      );
      expect(() => ScanDocumentService.validateCapturedPdf(valid, 51), throwsFormatException);
      expect(() => ScanDocumentService.validateCapturedPdf(Uint8List(0), 1), throwsFormatException);
      expect(
        () => ScanDocumentService.validateCapturedPdf(
          Uint8List(ScanDocumentService.maxPdfBytes + 1),
          1,
        ),
        throwsFormatException,
      );
    });

  });
}
