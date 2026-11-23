/// A non-destructive page projection of Writer's canonical Quill Delta.

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

  /// Finds the projected page containing a canonical document offset.
  /// A boundary offset belongs to the following page, except at document end.
  int pageIndexForOffset(int documentOffset) {
    final safeOffset = documentOffset.clamp(0, documentLength);
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      if (safeOffset < page.endOffset) return index;
      if (safeOffset == page.endOffset &&
          (index == pages.length - 1 || !page.endsWithExplicitBreak)) {
        return index;
      }
    }
    return pages.length - 1;
  }
}
