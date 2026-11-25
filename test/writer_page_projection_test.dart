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

    test('projects measured automatic pages into source-mapped editable Delta fragments', () {
      const sourceText = 'First line wraps onto the next visual page with stable offsets.\\n';
      final delta = <Map<String, dynamic>>[
        {'insert': sourceText, 'attributes': {'bold': true}},
      ];
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: delta,
        maxWidth: 72,
        pageContentHeight: 30,
      );

      expect(layout.pageCount, greaterThan(1));
      final projection = WriterPageProjection.fromMeasuredLayout(
        delta: delta,
        layout: layout,
      );

      expect(projection.pageCount, layout.pageCount);
      expect(projection.documentLength, sourceText.length);
      final projected = projection.pages
          .expand((page) => page.operations)
          .toList()
        ..sort((a, b) => a.documentOffset.compareTo(b.documentOffset));
      expect(projected.map((operation) => operation.documentOffset),
          orderedEquals(projected.map((operation) => operation.documentOffset).toList()..sort()));
      expect(projected.map((operation) => operation.operation['insert']).join(),
          sourceText);
      expect(projected.every((operation) =>
          operation.operation['attributes']['bold'] == true), isTrue);
      expect(projection.pageIndexForOffset(projection.pages[1].startOffset), 1);
    });

    test('rejects a measured layout created from a different Delta length', () {
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: [{'insert': 'original\\n'}],
        maxWidth: 200,
        pageContentHeight: 200,
      );
      expect(
        () => WriterPageProjection.fromMeasuredLayout(
          delta: [{'insert': 'different\\n'}],
          layout: layout,
        ),
        throwsArgumentError,
      );
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


    test('deeply snapshots nested attributes and embed data', () {
      final attributes = <String, dynamic>{'bold': true, 'custom': <String>['one']};
      final embed = <String, dynamic>{'payload': <String, dynamic>{'alt': 'original'}};
      final operation = <String, dynamic>{
        'insert': embed,
        'attributes': attributes,
      };
      final projection = WriterPageProjection.fromDelta([operation]);
      final projected = projection.pages.single.operations.single.operation;

      attributes['bold'] = false;
      (attributes['custom'] as List<String>).add('two');
      (embed['payload'] as Map<String, dynamic>)['alt'] = 'changed';

      expect(projected['attributes']['bold'], isTrue);
      expect(projected['attributes']['custom'], ['one']);
      expect(projected['insert']['payload']['alt'], 'original');
      expect(
        () => (projected['attributes'] as Map<String, dynamic>)['bold'] = false,
        throwsUnsupportedError,
      );
      expect(
        () => (projected['insert']['payload'] as Map<String, dynamic>)['alt'] = 'changed',
        throwsUnsupportedError,
      );
    });

    test('uses UTF-16 code-unit offsets for supplementary Unicode characters', () {
      const firstLine = 'বাংলা 😀 লেখা';
      final projection = WriterPageProjection.fromDelta([
        {'insert': firstLine},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
        {'insert': 'পরের পৃষ্ঠা'},
      ]);

      // Quill selections and Dart String.length both use UTF-16 code units.
      expect(projection.documentLength, firstLine.length + 1 + 'পরের পৃষ্ঠা'.length);
      expect(projection.pages.first.operations.first.length, firstLine.length);
      expect(projection.pages[1].startOffset, firstLine.length + 1);
      expect(projection.pageIndexForOffset(firstLine.length + 1), 1);
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
