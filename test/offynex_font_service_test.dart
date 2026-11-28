import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/fonts/offynex_font_service.dart';

void main() {
  group('OffynexFontService', () {
    test('rejects empty, oversized and unsupported font data', () {
      expect(() => OffynexFontService.validateAndReadFamily(Uint8List(0)),
          throwsFormatException);
      expect(
        () => OffynexFontService.validateAndReadFamily(
          Uint8List(OffynexFontService.maxFontBytes + 1),
        ),
        throwsFormatException,
      );
      expect(
        () => OffynexFontService.validateAndReadFamily(
          Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        ),
        throwsFormatException,
      );
    });

    test('rejects truncated table directories and out-of-bounds tables', () {
      final truncated = Uint8List(12)
        ..[0] = 0
        ..[1] = 1
        ..[2] = 0
        ..[3] = 0
        ..[4] = 0
        ..[5] = 1;
      expect(() => OffynexFontService.validateAndReadFamily(truncated),
          throwsFormatException);
    });
  });
}
