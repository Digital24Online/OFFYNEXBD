import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_page_projection.dart';

void main() {
  group('WriterPageProjection', () {
    test('keeps the canonical operation sequence and source offsets intact', () {
      final delta = <Map<String, dynamic>>[
        {'insert': 'বাংলা'},
        {'insert': ' text\n', 'attributes': {'bold': true}},
        {'insert': {'image': 'local-image.png'}},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
        {'insert': 'Next page'},
      ];

      final projection = WriterPageProjection.fromDelta(delta);

      expect(projection.pageCount, 2);
      expect(projection.documentLength, 'বাংলা text\n'.length + 1 + 1 + 'Next page'.length);
      expect(
        projection.pages.expand((page) => page.operations)
            .map((item) => item.sourceOperationIndex).toList(),
        [0, 1, 2, 3, 4],
      );
      expect(
        projection.pages.expand((page) => page.operations)
            .map((item) => item.documentOffset).toList(),
        [0, 'বাংলা'.length, 'বাংলা text\n'.length,
          'বাংলা text\n'.length + 1, 'বাংলা text\n'.length + 2],
      );
      expect(projection.pages.first.endsWithExplicitBreak, isTrue);
      expect(projection.pages.last.operations.last.operation['insert'], 'Next page');
    });

    test('creates an empty trailing page after an explicit final break', () {
      final projection = WriterPageProjection.fromDelta([
        {'insert': 'Page one'},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
      ]);

      expect(projection.pageCount, 2);
      expect(projection.pages.last.operations, isEmpty);
      expect(projection.pages.last.startOffset, projection.documentLength);
    });

    test('preserves empty pages created by consecutive explicit breaks', () {
      final projection = WriterPageProjection.fromDelta([
        {'insert': {'offynexbd-writer-page-break': 'page'}},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
      ]);

      expect(projection.pageCount, 3);
      expect(projection.pages[0].endsWithExplicitBreak, isTrue);
      expect(projection.pages[1].endsWithExplicitBreak, isTrue);
      expect(projection.pages[2].operations, isEmpty);
    });

    test('maps offsets to canonical pages with boundary semantics', () {
      final projection = WriterPageProjection.fromDelta([
        {'insert': 'abc'},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
        {'insert': 'def'},
      ]);

      expect(projection.pageIndexForOffset(0), 0);
      expect(projection.pageIndexForOffset(2), 0);
      expect(projection.pageIndexForOffset(3), 0);
      expect(projection.pageIndexForOffset(4), 1);
      expect(projection.pageIndexForOffset(999), 1);
      expect(projection.pageIndexForOffset(-1), 0);
    });

    test('represents an empty document as one editable page', () {
      final projection = WriterPageProjection.fromDelta([]);

      expect(projection.pageCount, 1);
      expect(projection.documentLength, 0);
      expect(projection.pages.single.operations, isEmpty);
    });

    test('does not mutate source Delta operations', () {
      final operation = <String, dynamic>{'insert': 'keep me'};
      final delta = [operation];

      WriterPageProjection.fromDelta(delta);

      expect(operation, {'insert': 'keep me'});
      expect(delta, [operation]);
    });
  });
}
