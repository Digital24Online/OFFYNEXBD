import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Estimates Writer's continuous editing canvas height from the actual Quill
/// operations, including inline formatting, block spacing, images, tables and
/// explicit page breaks. This is a layout estimate, not a replacement for the
/// final PDF renderer's pagination.
class WriterContentMetrics {
  const WriterContentMetrics._();

  /// Returns the exact custom font family saved in a Quill Delta. Built-in
  /// generic families remain unchanged; imported font names are not reduced
  /// to a serif/sans-serif approximation when estimating Writer layout.
  static String fontFamilyFromAttributes(Map<String, dynamic> attributes) {
    final family = attributes['font']?.toString().trim();
    if (family == null || family.isEmpty) return 'sans-serif';
    if (family.toLowerCase() == 'serif') return 'serif';
    if (family.toLowerCase() == 'sans-serif') return 'sans-serif';
    return family;
  }

  static double estimateHeight({
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
      throw ArgumentError('Writer content dimensions must be positive.');
    }

    var totalHeight = 0.0;
    final paragraph = <InlineSpan>[];
    var paragraphAttributes = <String, dynamic>{};

    void flushParagraph() {
      final indentValue = paragraphAttributes['indent'];
      final indent = indentValue is num
          ? indentValue.toDouble()
          : double.tryParse(indentValue?.toString() ?? '') ?? 0;
      final width = math.max(24.0, maxWidth - indent.clamp(0, 8) * 24).toDouble();
      final spans = paragraph.isEmpty
          ? <InlineSpan>[TextSpan(text: ' ', style: TextStyle(fontSize: defaultFontSize))]
          : List<InlineSpan>.of(paragraph);
      final painter = TextPainter(
        text: TextSpan(children: spans),
        textDirection: textDirection,
      )..layout(maxWidth: width);
      final height = math.max(defaultFontSize * 1.35, painter.height).toDouble();
      totalHeight += height + 4;
      paragraph.clear();
      paragraphAttributes = <String, dynamic>{};
    }

    void addText(String value, Map<String, dynamic> attributes) {
      if (value.isEmpty) return;
      final rawSize = attributes['size'];
      final parsedSize = rawSize is num
          ? rawSize.toDouble()
          : double.tryParse(rawSize?.toString() ?? '');
      final fontSize = parsedSize != null && parsedSize.isFinite
          ? (parsedSize * 0.75).clamp(6.0, 96.0).toDouble()
          : defaultFontSize;
      final color = _parseColor(attributes['color']);
      final background = _parseColor(attributes['background']);
      final fontFamily = fontFamilyFromAttributes(attributes);
      paragraph.add(TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: attributes['bold'] == true ? FontWeight.bold : FontWeight.normal,
          fontStyle: attributes['italic'] == true ? FontStyle.italic : FontStyle.normal,
          decoration: _decoration(attributes),
          color: color,
          backgroundColor: background,
          fontFamily: fontFamily,
        ),
      ));
    }

    for (final operation in delta) {
      final rawAttributes = operation['attributes'];
      final attributes = rawAttributes is Map
          ? Map<String, dynamic>.from(rawAttributes)
          : <String, dynamic>{};
      final insert = operation['insert'];

      if (insert is String) {
        final segments = insert.split('\n');
        for (var index = 0; index < segments.length; index++) {
          addText(segments[index], attributes);
          if (index < segments.length - 1) {
            paragraphAttributes = attributes;
            flushParagraph();
          }
        }
      } else if (insert is Map) {
        if (insert.containsKey('image')) {
          flushParagraph();
          // The image embed builder constrains the rendered image; reserve a
          // conservative editing height until the image's intrinsic size is
          // measured by the actual widget layout.
          totalHeight += 224;
        } else if (insert.containsKey('offynexbd-writer-table')) {
          flushParagraph();
          totalHeight += _estimateTableHeight(
            insert['offynexbd-writer-table'],
            maxWidth,
            textDirection,
            defaultFontSize,
          );
        } else if (insert.containsKey('offynexbd-writer-page-break')) {
          flushParagraph();
          final remainder = totalHeight % pageContentHeight;
          if (remainder > 0.5) totalHeight += pageContentHeight - remainder;
        }
      }
    }

    if (paragraph.isNotEmpty || totalHeight == 0) flushParagraph();
    return math.max(totalHeight, defaultFontSize * 1.35).toDouble();
  }

  /// Content-aware page estimate for the editing canvas. PDF export performs
  /// its own final pagination.
  static int estimatePageCount({
    required List<Map<String, dynamic>> delta,
    required double maxWidth,
    required double pageContentHeight,
    TextDirection textDirection = TextDirection.ltr,
    double defaultFontSize = 16,
  }) {
    final height = estimateHeight(
      delta: delta,
      maxWidth: maxWidth,
      pageContentHeight: pageContentHeight,
      textDirection: textDirection,
      defaultFontSize: defaultFontSize,
    );
    return math.max(1, (height / pageContentHeight).ceil());
  }

  static double _estimateTableHeight(
    Object? raw,
    double maxWidth,
    TextDirection direction,
    double defaultFontSize,
  ) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map || decoded['rows'] is! List) return 48;
      // Keep estimates bounded for unusually large embeds without ignoring
      // ordinary tables that contain more than 20 rows or 10 columns.
      final rows = (decoded['rows'] as List).take(1000).toList();
      final rawHeights = decoded['rowHeights'];
      var height = 0.0;
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final rawRow = rows[rowIndex];
        final cells = rawRow is List ? rawRow.take(100) : <Object?>[rawRow];
        final storedHeight = rawHeights is List && rowIndex < rawHeights.length
            ? (rawHeights[rowIndex] as num?)?.toDouble()
            : null;
        if (storedHeight != null && storedHeight.isFinite && storedHeight > 0) {
          height += storedHeight;
          continue;
        }
        final cellCount = math.max(1, cells.length);
        final cellWidth = math.max(24.0, maxWidth / cellCount - 12).toDouble();
        var rowHeight = 36.0;
        for (final cell in cells) {
          final painter = TextPainter(
            text: TextSpan(
              text: cell?.toString() ?? '',
              style: TextStyle(fontSize: defaultFontSize),
            ),
            textDirection: direction,
          )..layout(maxWidth: cellWidth);
          rowHeight = math.max(rowHeight, painter.height + 16).toDouble();
        }
        height += rowHeight;
      }
      return height + 8;
    } catch (_) {
      return 48;
    }
  }

  static TextDecoration? _decoration(Map<String, dynamic> attributes) {
    final values = <TextDecoration>[];
    if (attributes['underline'] == true) values.add(TextDecoration.underline);
    if (attributes['strike'] == true) values.add(TextDecoration.lineThrough);
    if (values.isEmpty) return null;
    return TextDecoration.combine(values);
  }

  static Color? _parseColor(Object? value) {
    if (value is! String) return null;
    final raw = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(raw)) {
      return null;
    }
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    return Color(raw.length == 8 ? parsed : 0xFF000000 | parsed);
  }
}
