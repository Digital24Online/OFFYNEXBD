import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_automatic_page_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WriterAutomaticPageLayout', () {
    test('wraps text into measured visual lines and additional pages', () {
      const text =
          'বাংলা লেখার একটি দীর্ঘ অনুচ্ছেদ যা ছোট পৃষ্ঠার প্রস্থে অনেকগুলো লাইনে '
          'ভেঙে যাবে এবং পৃষ্ঠার উচ্চতা কম থাকলে পরের পাতায় যাবে।\n';
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: [{'insert': text}],
        maxWidth: 72,
        pageContentHeight: 42,
      );

      expect(layout.pageCount, greaterThan(1));
      expect(layout.documentLength, text.length);
      expect(
        layout.pages.skip(1).every(
          (page) => page.startOffset > 0 && page.startOffset < text.length,
        ),
        isTrue,
      );
      expect(
        layout.pages.expand((page) => page.fragments)
            .where((fragment) => fragment.kind == 'text'),
        isNotEmpty,
      );
    });

    test('maps caret offsets to the following page at automatic boundaries', () {
      const text =
          'একটি দীর্ঘ বাংলা অনুচ্ছেদ যা ছোট পৃষ্ঠায় একাধিক লাইনে বিভক্ত হয়ে '
          'পরবর্তী পৃষ্ঠায় প্রবাহিত হবে।\\n';
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: [{'insert': text}],
        maxWidth: 68,
        pageContentHeight: 38,
      );

      expect(layout.pageCount, greaterThan(1));
      final boundary = layout.pages[1].startOffset;
      expect(layout.pages.first.endOffset, boundary);
      expect(layout.pageIndexForOffset(boundary), 1);
      expect(layout.pageIndexForOffset(0), 0);
      expect(layout.pageIndexForOffset(layout.documentLength), layout.pageCount - 1);
    });

    test('maps formatted text runs back to their source Delta offsets', () {
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: [
          {'insert': 'বাংলা ', 'attributes': {'bold': true}},
          {'insert': 'English paragraph\n'},
        ],
        maxWidth: 500,
        pageContentHeight: 500,
      );
      final fragments = layout.pages.single.fragments;

      expect(fragments.any((item) => item.sourceOperationIndex == 0), isTrue);
      expect(fragments.any((item) => item.sourceOperationIndex == 1), isTrue);
      expect(
        fragments.where((item) => item.sourceOperationIndex == 1)
            .every((item) => item.documentOffset >= 'বাংলা '.length),
        isTrue,
      );
      expect(layout.documentLength, 'বাংলা English paragraph\n'.length);
    });

    test('heading block formatting increases measured line height', () {
      final normal = WriterAutomaticPageLayout.fromDelta(
        delta: [{'insert': 'শিরোনাম\n'}],
        maxWidth: 300,
        pageContentHeight: 500,
      );
      final heading = WriterAutomaticPageLayout.fromDelta(
        delta: [
          {'insert': 'শিরোনাম'},
          {'insert': '\n', 'attributes': {'header': 1}},
        ],
        maxWidth: 300,
        pageContentHeight: 500,
      );

      expect(
        heading.pages.single.fragments.first.height,
        greaterThan(normal.pages.single.fragments.first.height),
      );
    });

    test('paragraph indentation reduces available line width', () {
      const text = 'বাংলা অনুচ্ছেদের দীর্ঘ লেখা যা নির্দিষ্ট প্রস্থে একাধিক লাইনে '
          'ভাঙবে এবং ইন্ডেন্ট থাকলে আরও বেশি জায়গা নেবে।';
      final normal = WriterAutomaticPageLayout.fromDelta(
        delta: [{'insert': '$text\n'}],
        maxWidth: 100,
        pageContentHeight: 52,
      );
      final indented = WriterAutomaticPageLayout.fromDelta(
        delta: [
          {'insert': text},
          {'insert': '\n', 'attributes': {'indent': 2}},
        ],
        maxWidth: 100,
        pageContentHeight: 52,
      );

      expect(indented.pageCount, greaterThanOrEqualTo(normal.pageCount));
      expect(
        indented.pages.expand((page) => page.fragments).length,
        greaterThan(normal.pages.expand((page) => page.fragments).length),
      );
    });

    test('blank paragraphs consume measured page height and retain source offsets', () {
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: [{'insert': '\n\n'}],
        maxWidth: 300,
        pageContentHeight: 25,
      );

      expect(layout.pageCount, 2);
      expect(layout.pages[0].fragments.single.documentOffset, 0);
      expect(layout.pages[0].fragments.single.sourceTextStart, 0);
      expect(layout.pages[0].fragments.single.sourceTextEnd, 1);
      expect(layout.pages[1].startOffset, 1);
      expect(layout.pages[1].fragments.single.documentOffset, 1);
      expect(layout.documentLength, 2);
    });

    test('blank heading paragraphs reserve the heading line height', () {
      final normal = WriterAutomaticPageLayout.fromDelta(
        delta: [{'insert': '\n'}],
        maxWidth: 300,
        pageContentHeight: 500,
      );
      final heading = WriterAutomaticPageLayout.fromDelta(
        delta: [
          {'insert': '\n', 'attributes': {'header': 1}},
        ],
        maxWidth: 300,
        pageContentHeight: 500,
      );

      expect(
        heading.pages.single.fragments.single.height,
        greaterThan(normal.pages.single.fragments.single.height),
      );
    });

    test('explicit page breaks create structural pages including trailing empties', () {
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: [
          {'insert': 'প্রথম পৃষ্ঠা\n'},
          {'insert': {'offynexbd-writer-page-break': 'page'}},
        ],
        maxWidth: 300,
        pageContentHeight: 500,
      );

      expect(layout.pageCount, 2);
      expect(layout.pages.first.fragments.last.kind, 'pageBreak');
      expect(layout.pages.last.fragments, isEmpty);
      expect(layout.documentLength, 'প্রথম পৃষ্ঠা\n'.length + 1);
    });

    test('image and table embeds remain indivisible mapped blocks', () {
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: [
          {'insert': 'Text\n'},
          {'insert': {'image': '/private/image.png'}},
          {
            'insert': {
              'offynexbd-writer-table': {
                'rows': [['A', 'B'], ['C', 'D']],
              },
            },
          },
        ],
        maxWidth: 300,
        pageContentHeight: 120,
      );

      final embeds = layout.pages.expand((page) => page.fragments)
          .where((fragment) => fragment.kind == 'image' ||
              fragment.kind == 'table')
          .toList();
      expect(embeds.map((fragment) => fragment.kind), ['image', 'table']);
      expect(embeds.every((fragment) => fragment.documentLength == 1), isTrue);
      expect(layout.documentLength, 'Text\n'.length + 2);
    });

    test('rejects invalid page dimensions', () {
      expect(
        () => WriterAutomaticPageLayout.fromDelta(
          delta: [{'insert': 'text'}],
          maxWidth: 0,
          pageContentHeight: 100,
        ),
        throwsArgumentError,
      );
    });

    test('empty documents still expose one editable page', () {
      final layout = WriterAutomaticPageLayout.fromDelta(
        delta: const [],
        maxWidth: 300,
        pageContentHeight: 500,
      );
      expect(layout.pageCount, 1);
      expect(layout.documentLength, 0);
      expect(layout.pages.single.fragments, isEmpty);
    });
  });
}
