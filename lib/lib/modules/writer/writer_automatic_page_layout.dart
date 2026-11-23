import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'writer_content_metrics.dart';

/// A measured visual fragment that still points to the canonical Quill Delta.
class WriterPageLayoutFragment {
  const WriterPageLayoutFragment({
    required this.sourceOperationIndex,
    required this.documentOffset,
    required this.sourceTextStart,
    required this.sourceTextEnd,
    required this.pageIndex,
    required this.top,
    required this.height,
    required this.kind,
  });

  final int sourceOperationIndex;
  final int documentOffset;
  final int sourceTextStart;
  final int sourceTextEnd;
  final int pageIndex;
  final double top;
  final double height;
  final String kind;

  int get documentLength => sourceTextEnd - sourceTextStart;
}

/// One physical page in the measured projection. It never owns or mutates
/// document content; every fragment maps back to the original Quill operation.
class WriterPageLayoutPage {
  const WriterPageLayoutPage({
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
    required this.fragments,
    required this.usedHeight,
  });

  final int pageIndex;
  final int startOffset;
  final int endOffset;
  final List<WriterPageLayoutFragment> fragments;
  final double usedHeight;
}

/// Measures line wrapping with Flutter's text engine and packs visual lines
/// onto pages. This is a layout projection, not a replacement editor renderer:
/// the canonical Quill Delta remains the sole editable and saved document.
class WriterAutomaticPageLayout {
  const WriterAutomaticPageLayout._({
    required this.pages,
    required this.documentLength,
  });

  final List<WriterPageLayoutPage> pages;
  final int documentLength;

  int get pageCount => pages.length;

  factory WriterAutomaticPageLayout.fromDelta({
    required List<Map<String, dynamic>> delta,
    required double maxWidth,
    required double pageContentHeight,
    TextDirection textDirection = TextDirection.ltr,
    double defaultFontSize = 16,
  }) {
    if (!maxWidth.isFinite ||
        !pageContentHeight.isFinite ||
        maxWidth <= 0 ||
        pageContentHeight <= 0 ||
        !defaultFontSize.isFinite ||
        defaultFontSize <= 0) {
      throw ArgumentError('Writer page dimensions must be positive.');
    }

    final mutablePages = <_MutablePage>[_MutablePage(0, 0)];
    var pageIndex = 0;
    var pageTop = 0.0;
    var documentOffset = 0;
    var paragraph = <_WriterTextRun>[];
    var paragraphTextLength = 0;

    void nextPage({int? nextOffset}) {
      final current = mutablePages[pageIndex];
      final pageStartOffset = nextOffset ?? documentOffset;
      current.endOffset = math.max(current.endOffset, pageStartOffset);
      pageIndex++;
      pageTop = 0;
      mutablePages.add(_MutablePage(pageIndex, pageStartOffset));
    }

    void ensureRoom(double height, {int? nextOffset}) {
      if (pageTop > 0 && pageTop + height > pageContentHeight) {
        nextPage(nextOffset: nextOffset);
      }
    }

    void addFragment({
      required int operationIndex,
      required int documentStart,
      required int localStart,
      required int localEnd,
      required double height,
      required String kind,
    }) {
      final current = mutablePages[pageIndex];
      current.fragments.add(WriterPageLayoutFragment(
        sourceOperationIndex: operationIndex,
        documentOffset: documentStart,
        sourceTextStart: localStart,
        sourceTextEnd: localEnd,
        pageIndex: pageIndex,
        top: pageTop,
        height: height,
        kind: kind,
      ));
      current.endOffset = math.max(
        current.endOffset,
        documentStart + (localEnd - localStart),
      );
    }

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final spans = paragraph.map((run) => TextSpan(
        text: run.text,
        style: _styleFor(run.attributes, defaultFontSize),
      )).toList(growable: false);
      final painter = TextPainter(
        text: TextSpan(children: spans),
        textDirection: textDirection,
      )..layout(maxWidth: maxWidth);
      final lines = painter.computeLineMetrics();

      if (lines.isEmpty) {
        paragraph.clear();
        paragraphTextLength = 0;
        return;
      }

      for (final line in lines) {
        final lineHeight = math.max(line.height, defaultFontSize * 1.2);
        final lineStart = line.startIndex;
        final lineEnd = math.max(line.endIndex, lineStart + 1);
        int? lineDocumentStart;
        for (final run in paragraph) {
          final intersectionStart = math.max(lineStart, run.paragraphStart);
          final intersectionEnd = math.min(lineEnd, run.paragraphEnd);
          if (intersectionEnd <= intersectionStart) continue;
          final localStart = run.localStart +
              intersectionStart - run.paragraphStart;
          final runDocumentStart = run.documentOffset + localStart;
          lineDocumentStart = lineDocumentStart == null
              ? runDocumentStart
              : math.min(lineDocumentStart, runDocumentStart);
        }
        ensureRoom(
          lineHeight,
          nextOffset: lineDocumentStart ?? documentOffset,
        );

        for (final run in paragraph) {
          final intersectionStart = math.max(lineStart, run.paragraphStart);
          final intersectionEnd = math.min(lineEnd, run.paragraphEnd);
          if (intersectionEnd <= intersectionStart) continue;
          final localStart = run.localStart +
              intersectionStart - run.paragraphStart;
          final localEnd = run.localStart +
              intersectionEnd - run.paragraphStart;
          addFragment(
            operationIndex: run.operationIndex,
            documentStart: run.documentOffset + localStart,
            localStart: localStart,
            localEnd: localEnd,
            height: lineHeight,
            kind: 'text',
          );
        }
        pageTop += lineHeight;
      }

      pageTop += 4;
      mutablePages[pageIndex].endOffset = math.max(
        mutablePages[pageIndex].endOffset,
        paragraph.fold<int>(
          0,
          (end, run) => math.max(end, run.documentOffset + run.text.length),
        ),
      );
      paragraph.clear();
      paragraphTextLength = 0;
    }

    for (var operationIndex = 0;
        operationIndex < delta.length;
        operationIndex++) {
      final operation = delta[operationIndex];
      final insert = operation['insert'];
      if (insert is String) {
        final operationStart = documentOffset;
        var localOffset = 0;
        final segments = insert.split('\n');
        for (var index = 0; index < segments.length; index++) {
          final hasNewline = index < segments.length - 1;
          final text = hasNewline ? '${segments[index]}\n' : segments[index];
          if (text.isNotEmpty) {
            final attributes = operation['attributes'] is Map
                ? Map<String, dynamic>.from(operation['attributes'] as Map)
                : <String, dynamic>{};
            paragraph.add(_WriterTextRun(
              operationIndex: operationIndex,
              documentOffset: operationStart,
              localStart: localOffset,
              text: text,
              attributes: attributes,
              paragraphStart: paragraphTextLength,
            ));
            paragraphTextLength += text.length;
          }
          localOffset += text.length;
          if (hasNewline) flushParagraph();
        }
        documentOffset += insert.length;
      } else if (insert is Map) {
        flushParagraph();
        final isPageBreak =
            insert.containsKey('offynexbd-writer-page-break');
        if (isPageBreak) {
          addFragment(
            operationIndex: operationIndex,
            documentStart: documentOffset,
            localStart: 0,
            localEnd: 1,
            height: 0,
            kind: 'pageBreak',
          );
          documentOffset++;
          nextPage();
          continue;
        }

        final embedHeight = WriterContentMetrics.estimateHeight(
          delta: [operation],
          maxWidth: maxWidth,
          pageContentHeight: pageContentHeight,
          textDirection: textDirection,
          defaultFontSize: defaultFontSize,
        );
        ensureRoom(embedHeight, nextOffset: documentOffset);
        addFragment(
          operationIndex: operationIndex,
          documentStart: documentOffset,
          localStart: 0,
          localEnd: 1,
          height: embedHeight,
          kind: insert.containsKey('image')
              ? 'image'
              : insert.containsKey('offynexbd-writer-table')
                  ? 'table'
                  : 'embed',
        );
        pageTop += embedHeight;
        documentOffset++;
      }
    }

    flushParagraph();
    mutablePages[pageIndex].endOffset = math.max(
      mutablePages[pageIndex].endOffset,
      documentOffset,
    );

    final pages = mutablePages.map((page) => WriterPageLayoutPage(
      pageIndex: page.pageIndex,
      startOffset: page.startOffset,
      endOffset: page.endOffset,
      fragments: List.unmodifiable(page.fragments),
      usedHeight: page.fragments.fold<double>(
        0,
        (height, fragment) => math.max(
          height,
          fragment.top + fragment.height,
        ),
      ),
    )).toList(growable: false);

    return WriterAutomaticPageLayout._(
      pages: List.unmodifiable(pages),
      documentLength: documentOffset,
    );
  }

  static TextStyle _styleFor(
    Map<String, dynamic> attributes,
    double defaultFontSize,
  ) {
    final rawSize = attributes['size'];
    final parsedSize = rawSize is num
        ? rawSize.toDouble()
        : double.tryParse(rawSize?.toString() ?? '');
    final fontSize = parsedSize != null && parsedSize.isFinite
        ? (parsedSize * 0.75).clamp(6.0, 96.0).toDouble()
        : defaultFontSize;
    return TextStyle(
      fontSize: fontSize,
      fontFamily: WriterContentMetrics.fontFamilyFromAttributes(attributes),
      fontWeight: attributes['bold'] == true
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: attributes['italic'] == true
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: attributes['underline'] == true
          ? TextDecoration.underline
          : null,
    );
  }
}

class _WriterTextRun {
  const _WriterTextRun({
    required this.operationIndex,
    required this.documentOffset,
    required this.localStart,
    required this.text,
    required this.attributes,
    required this.paragraphStart,
  });

  final int operationIndex;
  final int documentOffset;
  final int localStart;
  final String text;
  final Map<String, dynamic> attributes;
  final int paragraphStart;

  int get paragraphEnd => paragraphStart + text.length;
}

class _MutablePage {
  _MutablePage(this.pageIndex, this.startOffset)
      : endOffset = startOffset;

  final int pageIndex;
  final int startOffset;
  int endOffset;
  final List<WriterPageLayoutFragment> fragments = [];
}
