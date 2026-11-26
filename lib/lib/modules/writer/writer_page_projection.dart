import 'dart:math' as math;
import 'writer_automatic_page_layout.dart';

// Deep-copy helpers keep the page projection isolated from mutable source Delta data.

Object? _freezeProjectionValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _freezeProjectionValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeProjectionValue));
  }
  return value;
}

Map<String, dynamic> _freezeProjectionOperation(Map<String, dynamic> source) {
  return _freezeProjectionValue(source) as Map<String, dynamic>;
}
///
/// This deliberately does not rewrite, split, or mutate the saved Delta. Each
/// projected operation retains its original source-operation index and UTF-16
/// document offset so a future paged editor can map selections back to the
/// single canonical Quill document.
class WriterPageProjectionOperation {
  const WriterPageProjectionOperation({
    required this.sourceOperationIndex,
    required this.documentOffset,
    required this.length,
    required this.operation,
    required this.isPageBreak,
  });

  final int sourceOperationIndex;
  final int documentOffset;
  final int length;
  final Map<String, dynamic> operation;
  final bool isPageBreak;

  int get endOffset => documentOffset + length;
}

class WriterProjectedPage {
  const WriterProjectedPage({
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
    required this.operations,
    required this.endsWithExplicitBreak,
  });

  final int pageIndex;
  final int startOffset;
  final int endOffset;
  final List<WriterPageProjectionOperation> operations;
  final bool endsWithExplicitBreak;
}

class WriterPageProjectionLocation {
  const WriterPageProjectionLocation({
    required this.pageIndex,
    required this.pageOffset,
    required this.operationIndex,
    required this.sourceOperationIndex,
    required this.operationOffset,
  });

  final int pageIndex;
  final int pageOffset;
  final int? operationIndex;
  final int? sourceOperationIndex;
  final int? operationOffset;
}

class WriterPageProjection {
  const WriterPageProjection._(this.pages, this.documentLength);

  final List<WriterProjectedPage> pages;
  final int documentLength;

  int get pageCount => pages.length;

  /// Projects explicit page-break embeds only. Automatic visual page
  /// boundaries must be supplied by measured render layout, not guessed from
  /// estimated text heights here.
  factory WriterPageProjection.fromDelta(
    List<Map<String, dynamic>> delta,
  ) {
    final pages = <WriterProjectedPage>[];
    var pageOperations = <WriterPageProjectionOperation>[];
    var offset = 0;
    var pageStart = 0;

    void finishPage({required bool explicitBreak}) {
      pages.add(WriterProjectedPage(
        pageIndex: pages.length,
        startOffset: pageStart,
        endOffset: offset,
        operations: List.unmodifiable(pageOperations),
        endsWithExplicitBreak: explicitBreak,
      ));
      pageOperations = <WriterPageProjectionOperation>[];
      pageStart = offset;
    }

    for (var index = 0; index < delta.length; index++) {
      final source = delta[index];
      final rawInsert = source['insert'];
      final isBreak = rawInsert is Map &&
          rawInsert.containsKey('offynexbd-writer-page-break');
      final length = rawInsert is String ? rawInsert.length : 1;
      if (length <= 0) continue;

      pageOperations.add(WriterPageProjectionOperation(
        sourceOperationIndex: index,
        documentOffset: offset,
        length: length,
        operation: _freezeProjectionOperation(source),
        isPageBreak: isBreak,
      ));
      offset += length;

      if (isBreak) finishPage(explicitBreak: true);
    }

    // Always expose one page for an empty document and preserve the empty
    // page after a trailing or consecutive explicit break.
    if (pageOperations.isNotEmpty || pages.isEmpty || pageStart == offset) {
      finishPage(explicitBreak: false);
    }

    return WriterPageProjection._(
      List.unmodifiable(pages),
      offset,
    );
  }

  /// Builds editable page fragments from measured automatic pagination.
  ///
  /// Text fragments are sliced from their original Delta operation using
  /// UTF-16 offsets; attributes and embeds are retained. The source Delta is
  /// never mutated, so callers can create per-page editing documents while
  /// keeping the original document as the canonical save format.
  factory WriterPageProjection.fromMeasuredLayout({
    required List<Map<String, dynamic>> delta,
    required WriterAutomaticPageLayout layout,
  }) {
    var sourceLength = 0;
    for (final operation in delta) {
      final insert = operation['insert'];
      if (insert is String) {
        sourceLength += insert.length;
      } else if (insert is Map) {
        sourceLength++;
      } else {
        throw const FormatException('Writer Delta contains an unsupported insert.');
      }
    }
    if (sourceLength != layout.documentLength) {
      throw ArgumentError('Measured page layout does not match the source Delta.');
    }

    final projectedPages = <WriterProjectedPage>[];
    for (final page in layout.pages) {
      final operations = <WriterPageProjectionOperation>[];
      for (final fragment in page.fragments) {
        if (fragment.sourceOperationIndex < 0 ||
            fragment.sourceOperationIndex >= delta.length) {
          throw StateError('Writer page fragment references a missing Delta operation.');
        }
        final source = delta[fragment.sourceOperationIndex];
        final insert = source['insert'];
        Map<String, dynamic> projected;
        if (fragment.kind == 'text') {
          if (insert is! String ||
              fragment.sourceTextStart < 0 ||
              fragment.sourceTextEnd > insert.length ||
              fragment.sourceTextEnd <= fragment.sourceTextStart) {
            throw StateError('Writer text fragment has an invalid source range.');
          }
          projected = <String, dynamic>{
            'insert': insert.substring(
              fragment.sourceTextStart,
              fragment.sourceTextEnd,
            ),
            if (source['attributes'] is Map)
              'attributes': Map<String, dynamic>.from(
                source['attributes'] as Map,
              ),
          };
        } else {
          if (insert is! Map || fragment.documentLength != 1) {
            throw StateError('Writer embed fragment has an invalid source operation.');
          }
          projected = Map<String, dynamic>.from(source);
        }
        operations.add(WriterPageProjectionOperation(
          sourceOperationIndex: fragment.sourceOperationIndex,
          documentOffset: fragment.documentOffset,
          length: fragment.documentLength,
          operation: _freezeProjectionOperation(projected),
          isPageBreak: fragment.kind == 'pageBreak',
        ));
      }
      projectedPages.add(WriterProjectedPage(
        pageIndex: page.pageIndex,
        startOffset: page.startOffset,
        endOffset: page.endOffset,
        operations: List.unmodifiable(operations),
        endsWithExplicitBreak: page.fragments.isNotEmpty &&
            page.fragments.last.kind == 'pageBreak',
      ));
    }

    return WriterPageProjection._(
      List.unmodifiable(projectedPages),
      layout.documentLength,
    );
  }

  /// Resolves a canonical Quill offset to its visual page and source Delta
  /// operation. At a split-operation boundary, the following fragment wins;
  /// the final document-end offset stays attached to the final fragment.
  WriterPageProjectionLocation locationForOffset(int documentOffset) {
    final safeOffset = documentOffset.clamp(0, documentLength).toInt();
    final pageIndex = pageIndexForOffset(safeOffset);
    final page = pages[pageIndex];
    final pageOffset = (safeOffset - page.startOffset)
        .clamp(0, math.max(0, page.endOffset - page.startOffset))
        .toInt();
    for (var index = 0; index < page.operations.length; index++) {
      final operation = page.operations[index];
      if (safeOffset < operation.endOffset ||
          safeOffset == operation.documentOffset) {
        return WriterPageProjectionLocation(
          pageIndex: pageIndex,
          pageOffset: pageOffset,
          operationIndex: index,
          sourceOperationIndex: operation.sourceOperationIndex,
          operationOffset: (safeOffset - operation.documentOffset)
              .clamp(0, operation.length)
              .toInt(),
        );
      }
      if (safeOffset == operation.endOffset) {
        final hasFollowingFragment = index + 1 < page.operations.length &&
            page.operations[index + 1].documentOffset == safeOffset;
        if (hasFollowingFragment) continue;
        return WriterPageProjectionLocation(
          pageIndex: pageIndex,
          pageOffset: pageOffset,
          operationIndex: index,
          sourceOperationIndex: operation.sourceOperationIndex,
          operationOffset: operation.length,
        );
      }
    }
    return WriterPageProjectionLocation(
      pageIndex: pageIndex,
      pageOffset: pageOffset,
      operationIndex: null,
      sourceOperationIndex: null,
      operationOffset: null,
    );
  }

  /// Finds the projected page containing a canonical document offset.
  /// A boundary offset belongs to the following page, except at document end.
  int pageIndexForOffset(int documentOffset) {
    final safeOffset = documentOffset.clamp(0, documentLength);
    // Prefer the page whose first projected fragment starts at this exact
    // canonical offset. This handles repeated/empty page ranges and ensures
    // a page-start caret is resolved against that page's own source fragment.
    for (var index = pages.length - 1; index > 0; index--) {
      final page = pages[index];
      if (page.startOffset == safeOffset && page.operations.isNotEmpty) {
        return index;
      }
    }
    // The document-end caret belongs to the final page, including an empty
    // trailing page after the last visual fragment.
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
}
