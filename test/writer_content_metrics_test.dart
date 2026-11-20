import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_content_metrics.dart';

void main() {
  group('WriterContentMetrics', () {
    const pageHeight = 100.0;

    test('measures actual Quill text and wraps to the available width', () {
      final short = WriterContentMetrics.estimateHeight(
        delta: [{'insert': 'Short line\n'}],
        maxWidth: 300,
        pageContentHeight: pageHeight,
      );
      final narrow = WriterContentMetrics.estimateHeight(
        delta: [{'insert': 'A long line of text that must wrap over multiple lines\n'}],
        maxWidth: 55,
        pageContentHeight: pageHeight,
      );
      expect(short, greaterThan(0));
      expect(narrow, greaterThan(short));
    });

    test('larger inline font sizes increase the estimated document height', () {
      final normal = WriterContentMetrics.estimateHeight(
        delta: [{'insert': 'বাংলা English\n'}],
        maxWidth: 300,
        pageContentHeight: pageHeight,
      );
      final large = WriterContentMetrics.estimateHeight(
        delta: [
          {'insert': 'বাংলা English', 'attributes': {'size': '48'}},
          {'insert': '\n'},
        ],
        maxWidth: 300,
        pageContentHeight: pageHeight,
      );
      expect(large, greaterThan(normal));
    });

    test('image and table embeds reserve space in the page estimate', () {
      final text = WriterContentMetrics.estimateHeight(
        delta: [{'insert': 'Text\n'}],
        maxWidth: 300,
        pageContentHeight: pageHeight,
      );
      final withImage = WriterContentMetrics.estimateHeight(
        delta: [
          {'insert': 'Text\n'},
          {'insert': {'image': '/private/image.png'}},
        ],
        maxWidth: 300,
        pageContentHeight: pageHeight,
      );
      final withTable = WriterContentMetrics.estimateHeight(
        delta: [
          {'insert': 'Text\n'},
          {'insert': {'offynexbd-writer-table': '{"rows":[["A","B"],["long cell text","C"]]}' }},
        ],
        maxWidth: 300,
        pageContentHeight: pageHeight,
      );
      expect(withImage, greaterThan(text));
      expect(withTable, greaterThan(text));
    });

    test('explicit page break advances the estimate to the next page', () {
      final height = WriterContentMetrics.estimateHeight(
        delta: [
          {'insert': 'First page\n'},
          {'insert': {'offynexbd-writer-page-break': 'page'}},
          {'insert': 'Second page\n'},
        ],
        maxWidth: 300,
        pageContentHeight: pageHeight,
      );
      expect(height, greaterThanOrEqualTo(pageHeight));
    });

    test('calculates page count from content-aware estimate', () {
      expect(WriterContentMetrics.estimatePageCount(
        delta: [{'insert': 'Short paragraph\\n'}],
        maxWidth: 300, pageContentHeight: 1000,
      ), 1);
      expect(WriterContentMetrics.estimatePageCount(
        delta: [{'insert': List.filled(100, 'বাংলা লেখা\\n').join()}],
        maxWidth: 100, pageContentHeight: 100,
      ), greaterThan(1));
    });

    test('rejects invalid layout dimensions', () {
      expect(
        () => WriterContentMetrics.estimateHeight(
          delta: [{'insert': 'Text\n'}],
          maxWidth: 0,
          pageContentHeight: pageHeight,
        ),
        throwsArgumentError,
      );
    });
  });
}
