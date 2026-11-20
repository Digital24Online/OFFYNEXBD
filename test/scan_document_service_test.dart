import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/scan_document_service.dart';

void main() {
  group('ScanDocumentService', () {
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

    test('returns empty text when every page has no recognized text', () {
      expect(
        ScanDocumentService.combineRecognizedPages(['', '  ', '\n']),
        isEmpty,
      );
    });

    test('accepts multiple supported image pages for imported scans', () {
      expect(
        () => ScanDocumentService.validateImportedImages([
          (name: 'page-1.jpg', bytes: Uint8List.fromList([1, 2, 3])),
          (name: 'page-2.PNG', bytes: Uint8List.fromList([4, 5, 6])),
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
    });

    test('rejects empty, malformed, oversized and out-of-range scan output', () {
      final valid = Uint8List.fromList('%PDF-1.7'.codeUnits);
      expect(() => ScanDocumentService.validateCapturedPdf(valid, 1), returnsNormally);
      expect(() => ScanDocumentService.validateCapturedPdf(valid, 0), throwsFormatException);
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
