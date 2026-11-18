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
  });
}
