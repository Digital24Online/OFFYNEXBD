import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_table.dart';

void main() {
  group('Writer table header-row metadata', () {
    test('defaults older tables to a header row', () {
      expect(
        WriterTableBlockEmbed.hasHeaderRow(const <String, dynamic>{'rows': []}),
        isTrue,
      );
    });

    test('preserves an explicit header row setting', () {
      expect(
        WriterTableBlockEmbed.hasHeaderRow(const <String, dynamic>{
          'rows': [],
          'headerRow': false,
        }),
        isFalse,
      );
      expect(
        WriterTableBlockEmbed.hasHeaderRow(const <String, dynamic>{
          'rows': [],
          'headerRow': true,
        }),
        isTrue,
      );
    });
  });
}
