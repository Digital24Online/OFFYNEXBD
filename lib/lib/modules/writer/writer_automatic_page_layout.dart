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

  /// Maps a canonical Quill UTF-16 offset to its visual page. At an automatic
  /// page boundary the caret belongs to the following page; document-end
  /// offsets remain on the final page.
  int pageIndexForOffset(int documentOffset) {
    final safeOffset = documentOffset.clamp(0, documentLength).toInt();
    // Several consecutive page breaks or a trailing empty page can give
    // multiple pages the same boundary offset. The document-end caret belongs
    // to the final page, never the first page sharing that offset.
    if (safeOffset == documentLength) return pages.length - 1;
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      if (safeOffset < page.endOffset) return index;
      if (safeOffset == page.endOffset) {
        if (index == pages.length - 1) return index;
        if (pages[index + 1].startOffset == safeOffset) return index + 1;
        return index;
      }
    }
    return pages.length - 1;
  }

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
    var paragraphVisibleTextLength = 0;
    var paragraphAttributes = <String, dynamic>{};
    int? paragraphTerminatorOperationIndex;
    int? paragraphTerminatorDocumentOffset;
    int? paragraphTerminatorLocalOffset;

    void nextPage({int? nextOffset}) {
      final current = mutablePages[pageIndex];
      final pageStartOffset = nextOffset ?? documentOffset;
      // Page ranges are half-open: the previous page ends exactly where
      // the next page starts, even when the final line fragment includes its
      // terminating newline in the measured source range.
      current.endOffset = pageStartOffset;
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
      ).toInt();
    }

    void flushParagraph() {
      if (paragraphVisibleTextLength == 0) {
        // A newline with no preceding text is still a real paragraph. Keep a
        // one-character source mapping so blank lines consume vertical space
        // and remain addressable in the canonical Quill document.
        final operationIndex = paragraphTerminatorOperationIndex;
        final documentStart = paragraphTerminatorDocumentOffset;
        final localStart = paragraphTerminatorLocalOffset;
        if (operationIndex != null &&
            documentStart != null &&
            localStart != null) {
          final header = int.tryParse(
            paragraphAttributes['header']?.toString() ?? '',
          );
          final headerScale = switch (header) {
            1 => 2.0,
            2 => 1.5,
            3 => 1.17,
            _ => 1.0,
          };
          final lineHeight = math.max(
            defaultFontSize * 1.2,
            defaultFontSize * headerScale * 1.2,
          ).toDouble();
          ensureRoom(lineHeight, nextOffset: documentStart);
          addFragment(
            operationIndex: operationIndex,
            documentStart: documentStart,
            localStart: localStart,
            localEnd: localStart + 1,
            height: lineHeight,
            kind: 'text',
          );
          pageTop += lineHeight + 4;
        }
        paragraphTextLength = 0;
        paragraphVisibleTextLength = 0;
        paragraph.clear();
        paragraphAttributes = <String, dynamic>{};
        paragraphTerminatorOperationIndex = null;
        paragraphTerminatorDocumentOffset = null;
        paragraphTerminatorLocalOffset = null;
        return;
      }
      final indentValue = paragraphAttributes['indent'];
      final indentLevel = indentValue is num
          ? indentValue.toDouble()
          : double.tryParse(indentValue?.toString() ?? '') ?? 0;
      final listIndent = paragraphAttributes['list'] == null ? 0.0 : 1.0;
      final contentWidth = math.max(
        24.0,
        maxWidth - (indentLevel.clamp(0, 8) + listIndent) * 24,
      ).toDouble();
      final paragraphDirection = paragraphAttributes['direction'] == 'rtl'
          ? TextDirection.rtl
          : paragraphAttributes['direction'] == 'ltr'
              ? TextDirection.ltr
              : textDirection;
      final alignment = switch (paragraphAttributes['align']?.toString()) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => TextAlign.start,
      };
      final spans = paragraph.map((run) => TextSpan(
        text: run.text,
        style: _styleFor(run.attributes, defaultFontSize, paragraphAttributes),
      )).toList(growable: false);
      final painter = TextPainter(
        text: TextSpan(children: spans),
        textDirection: paragraphDirection,
        textAlign: alignment,
      )..layout(maxWidth: contentWidth);
      final lines = painter.computeLineMetrics();

      if (lines.isEmpty) {
        paragraph.clear();
        paragraphTextLength = 0;
        return;
      }

      var measuredSourceOffset = 0;
      final paragraphText = paragraph.map((run) => run.text).join();
      for (final line in lines) {
        final lineHeight = math.max(line.height, defaultFontSize * 1.2).toDouble();

        // Map each measured visual line using its own baseline. TextPainter's
        // line-boundary lookup can return a paragraph-wide range for some
        // complex-script runs; using the measured line geometry avoids treating
        // the whole Bengali paragraph as one source line. Keep ranges
        // sequential so cluster hit-testing cannot create gaps or overlaps.
        final isRtl = paragraphDirection == TextDirection.rtl;
        final startX = isRtl ? line.left + line.width - 0.5 : line.left + 0.5;
        final endX = isRtl ? line.left + 0.5 : line.left + line.width - 0.5;
        final lineY = line.baseline - math.max(1.0, line.descent * 0.25);
        final startPosition = painter.getPositionForOffset(
          Offset(startX, lineY),
        );
        final endPosition = painter.getPositionForOffset(
          Offset(endX, lineY),
        );
        final lineStart = measuredSourceOffset
            .clamp(0, paragraphTextLength)
            .toInt();
        var lineEnd = math.max(
          lineStart,
          endPosition.offset,
        ).clamp(lineStart, paragraphTextLength).toInt();

        // Glyph-edge hit testing may snap to the adjacent Bengali conjunct.
        // The next visual line still starts exactly where this one ended;
        // never move the canonical source cursor backwards.
        if (lineEnd <= lineStart) {
          final boundary = painter.getLineBoundary(TextPosition(
            offset: math.max(lineStart, startPosition.offset)
                .clamp(0, paragraphTextLength)
                .toInt(),
            affinity: TextAffinity.downstream,
          ));
          lineEnd = boundary.end
              .clamp(lineStart, paragraphTextLength)
              .toInt();
        }
        if (lineEnd <= lineStart && lineStart < paragraphTextLength) {
          lineEnd = lineStart + 1;
        }

        if (line.hardBreak &&
            lineEnd < paragraphTextLength &&
            paragraphText.codeUnitAt(lineEnd) == 10) {
          lineEnd++;
        }

        int? lineDocumentStart;
        for (final run in paragraph) {
          final intersectionStart = math.max(lineStart, run.paragraphStart).toInt();
          final intersectionEnd = math.min(lineEnd, run.paragraphEnd).toInt();
          if (intersectionEnd <= intersectionStart) continue;
          final localStart = run.localStart +
              intersectionStart - run.paragraphStart;
          final runDocumentStart = run.documentOffset + localStart;
          if (lineDocumentStart == null ||
              runDocumentStart < lineDocumentStart) {
            lineDocumentStart = runDocumentStart;
          }
        }
        ensureRoom(
          lineHeight,
          nextOffset: lineDocumentStart ??
              (paragraph.isNotEmpty
                  ? paragraph.first.documentOffset +
                      paragraph.first.localStart + lineStart -
                      paragraph.first.paragraphStart
                  : documentOffset),
        );

        for (final run in paragraph) {
          final intersectionStart = math.max(lineStart, run.paragraphStart).toInt();
          final intersectionEnd = math.min(lineEnd, run.paragraphEnd).toInt();
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
        measuredSourceOffset = lineEnd;
        pageTop += lineHeight;
      }
      pageTop += 4;
      mutablePages[pageIndex].endOffset = math.max(
        mutablePages[pageIndex].endOffset,
        paragraph.fold<int>(
          0,
          (end, run) => math.max(end, run.documentOffset + run.text.length).toInt(),
        ),
      );
      paragraph.clear();
      paragraphTextLength = 0;
      paragraphVisibleTextLength = 0;
      paragraphAttributes = <String, dynamic>{};
      paragraphTerminatorOperationIndex = null;
      paragraphTerminatorDocumentOffset = null;
      paragraphTerminatorLocalOffset = null;
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
          final attributes = operation['attributes'] is Map
              ? Map<String, dynamic>.from(operation['attributes'] as Map)
              : <String, dynamic>{};
          if (text.isNotEmpty) {
            paragraph.add(_WriterTextRun(
              operationIndex: operationIndex,
              documentOffset: operationStart,
              localStart: localOffset,
              text: text,
              attributes: attributes,
              paragraphStart: paragraphTextLength,
            ));
            paragraphTextLength += text.length;
            paragraphVisibleTextLength += segments[index].length;
          }
          if (hasNewline) {
            final newlineLocalOffset = localOffset + segments[index].length;
            paragraphTerminatorOperationIndex = operationIndex;
            paragraphTerminatorDocumentOffset =
                operationStart + newlineLocalOffset;
            paragraphTerminatorLocalOffset = newlineLocalOffset;
            paragraphAttributes = {
              for (final key in const [
                'header', 'indent', 'list', 'blockquote', 'code-block',
                'align', 'direction',
              ])
                if (attributes.containsKey(key)) key: attributes[key],
            };
            flushParagraph();
          }
          localOffset += text.length;
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
    ).toInt();

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
        ).toDouble(),
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
    Map<String, dynamic> paragraphAttributes,
  ) {
    final rawSize = attributes['size'];
    final parsedSize = rawSize is num
        ? rawSize.toDouble()
        : double.tryParse(rawSize?.toString() ?? '');
    final header = int.tryParse(paragraphAttributes['header']?.toString() ?? '');
    final headerScale = switch (header) {
      1 => 2.0,
      2 => 1.5,
      3 => 1.17,
      _ => 1.0,
    };
    final fontSize = parsedSize != null && parsedSize.isFinite
        ? (parsedSize * 0.75).clamp(6.0, 96.0).toDouble()
        : (defaultFontSize * headerScale).clamp(6.0, 96.0).toDouble();
    return TextStyle(
      fontSize: fontSize,
      fontFamily: paragraphAttributes.containsKey('code-block')
          ? 'monospace'
          : WriterContentMetrics.fontFamilyFromAttributes(attributes),
      fontWeight: attributes['bold'] == true
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: attributes['italic'] == true
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: attributes['underline'] == true && attributes['strike'] == true
          ? TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough])
          : attributes['underline'] == true
              ? TextDecoration.underline
              : attributes['strike'] == true
                  ? TextDecoration.lineThrough
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
