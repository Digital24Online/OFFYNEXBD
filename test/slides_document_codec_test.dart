import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/slides_document_codec.dart';

void main() {
  group('SlidesDocumentCodec', () {
    test('reads legacy one-slide-per-line documents', () {
      expect(
        SlidesDocumentCodec.decode('Title\r\nFirst slide\r\n\r\nSecond slide  '),
        ['Title', 'First slide', 'Second slide'],
      );
    });

    test('round-trips structured slides in their saved order, including blank slides', () {
      final encoded = SlidesDocumentCodec.encode(['Opening', '', 'বাংলা উপস্থাপনা']);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['format'], SlidesDocumentCodec.format);
      expect(decoded['version'], SlidesDocumentCodec.version);
      expect(SlidesDocumentCodec.decode(encoded), ['Opening', '', 'বাংলা উপস্থাপনা']);
    });

    test('rejects an unsupported structured document version', () {
      final source = jsonEncode({
        'format': SlidesDocumentCodec.format,
        'version': 99,
        'slides': ['Slide'],
      });
      expect(() => SlidesDocumentCodec.decode(source), throwsFormatException);
    });

    test('rejects more than 200 legacy slides', () {
      final source = List<String>.generate(201, (index) => 'Slide $index').join('\n');
      expect(() => SlidesDocumentCodec.decode(source), throwsFormatException);
    });

    test('rejects invalid slide count and non-text entries', () {
      expect(() => SlidesDocumentCodec.encode([]), throwsFormatException);
      expect(
        () => SlidesDocumentCodec.decode(jsonEncode({
          'format': SlidesDocumentCodec.format,
          'version': SlidesDocumentCodec.version,
          'slides': [1],
        })),
        throwsFormatException,
      );
    });
  });
}
