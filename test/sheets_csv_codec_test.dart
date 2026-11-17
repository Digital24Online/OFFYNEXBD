import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_csv_codec.dart';

void main() {
  group('SheetsCsvCodec', () {
    test('round-trips commas, quotes, newlines and Bengali text', () {
      const source = 'Name,Note\r\n"Rahim","said ""hello"", world"\r\n"বাংলা","প্রথম লাইন\nদ্বিতীয় লাইন"';
      final decoded = SheetsCsvCodec.decode(source);
      expect(decoded, [
        ['Name', 'Note'],
        ['Rahim', 'said "hello", world'],
        ['বাংলা', 'প্রথম লাইন\nদ্বিতীয় লাইন'],
      ]);
      expect(SheetsCsvCodec.decode(SheetsCsvCodec.encode(decoded)), decoded);
    });

    test('accepts UTF-8 BOM and CRLF without adding an extra row', () {
      expect(
        SheetsCsvCodec.decode('\uFEFFA,B\r\n1,2\r\n'),
        [['A', 'B'], ['1', '2']],
      );
    });

    test('preserves empty fields and trailing empty columns', () {
      expect(SheetsCsvCodec.decode('A,,C\n1,2,'), [
        ['A', '', 'C'],
        ['1', '2', ''],
      ]);
    });

    test('returns no rows for an empty file', () {
      expect(SheetsCsvCodec.decode(''), isEmpty);
    });

    test('rejects malformed quoted fields', () {
      expect(() => SheetsCsvCodec.decode('"unfinished'), throwsA(isA<FormatException>()));
      expect(() => SheetsCsvCodec.decode('ab"cd'), throwsA(isA<FormatException>()));
      expect(() => SheetsCsvCodec.decode('"ok"x'), throwsA(isA<FormatException>()));
    });
  });
}
