import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:bangla_pdf/widgets.dart' as pw;
import 'writer_page_break.dart';
import 'writer_table.dart';

/// Builds Writer print/PDF output with HarfBuzz-compatible OpenType Bengali shaping.
class WriterPdfExportService {
  static Future<Uint8List> build({
    required String title,
    required List<Map<String, dynamic>> delta,
    required ByteData sansFontData,
    required ByteData serifFontData,
    required ByteData latinFontData,
    required PdfPageFormat pageFormat,
    required double marginTop,
    required double marginBottom,
    required double marginLeft,
    required double marginRight,
    String headerText = '',
    String footerText = '',
    Map<String, ByteData> customFontData = const <String, ByteData>{},
  }) async {
    final sansFont = pw.Font.ttf(sansFontData);
    final serifFont = pw.Font.ttf(serifFontData);
    final latinFont = pw.Font.ttf(latinFontData);
    final customFonts = <String, pw.Font>{};
    for (final entry in customFontData.entries) {
      try {
        customFonts[entry.key] = pw.Font.ttf(entry.value);
      } catch (_) {
        // Unsupported optional font files fall back to the bundled Bengali font.
      }
    }
    final titleAlreadyInBody = _firstParagraphText(delta).trim() == title.trim() &&
        title.trim().isNotEmpty;
    final widgets = <pw.Widget>[];
    if (!titleAlreadyInBody && title.trim().isNotEmpty) {
      widgets
        ..add(pw.Text(title, style: pw.TextStyle(
          font: _containsBangla(title) ? sansFont : latinFont,
          fontFallback: _containsBangla(title) ? [latinFont] : const [],
          fontSize: 18,
        )))
        ..add(pw.SizedBox(height: 14));
    }
    final spans = <_WriterPdfTextSegment>[];
    var orderedListNumber = 0;

    pw.Font fontFor(Map<String, dynamic> attributes, String text) {
      if (!_containsBangla(text)) return latinFont;
      final family = attributes['font']?.toString();
      final custom = family == null ? null : customFonts[family];
      if (custom != null) return custom;
      return family == 'serif' ? serifFont : sansFont;
    }

    pw.TextStyle styleFor(
      Map<String, dynamic> attributes,
      String text, {
      int? heading,
    }) {
      final rawSize = double.tryParse(attributes['size']?.toString() ?? '');
      const headingSizes = <int, double>{
        1: 24, 2: 20, 3: 18, 4: 16, 5: 14, 6: 12,
      };
      final size = rawSize != null
          ? (rawSize * 0.75).clamp(5.0, 144.0).toDouble()
          : headingSizes[heading] ?? 12.0;
      final decoration = textDecorationForAttributes(attributes);
      final highlightColor = highlightColorForAttributes(attributes);
      return pw.TextStyle(
        font: fontFor(attributes, text),
        fontFallback: _containsBangla(text) ? [latinFont] : const [],
        fontSize: size,
        fontWeight: attributes['bold'] == true || heading != null
            ? pw.FontWeight.bold
            : pw.FontWeight.normal,
        fontStyle: attributes['italic'] == true
            ? pw.FontStyle.italic
            : pw.FontStyle.normal,
        color: _parseColor(attributes['color']?.toString()) ?? PdfColors.black,
        background: highlightColor == null
            ? null
            : pw.BoxDecoration(color: highlightColor),
        decoration: decoration,
      );
    }

    void flushParagraph([Map<String, dynamic>? paragraphAttributes]) {
      final attributes = paragraphAttributes ?? const <String, dynamic>{};
      final rawHeading = attributes['header'];
      final heading = rawHeading is num
          ? rawHeading.toInt().clamp(1, 6).toInt()
          : int.tryParse(rawHeading?.toString() ?? '')?.clamp(1, 6).toInt();
      final listType = attributes['list']?.toString();
      final isBullet = listType == 'bullet';
      final isOrdered = listType == 'ordered';
      final rawIndent = attributes['indent'];
      final indentLevel = (rawIndent is num
              ? rawIndent.toInt()
              : int.tryParse(rawIndent?.toString() ?? '') ?? 0)
          .clamp(0, 8)
          .toInt();
      if (isOrdered) {
        orderedListNumber++;
      } else if (!isBullet) {
        orderedListNumber = 0;
      }

      if (spans.isEmpty && !isBullet && !isOrdered) {
        widgets.add(pw.SizedBox(height: 8));
      } else {
        final alignment = switch (attributes['align']?.toString()) {
          'center' => pw.TextAlign.center,
          'right' => pw.TextAlign.right,
          'justify' => pw.TextAlign.justify,
          _ => pw.TextAlign.left,
        };
        final paragraphSpans = <pw.TextSpan>[];
        if (isBullet || isOrdered) {
          final marker = isBullet ? '•  ' : '$orderedListNumber.  ';
          paragraphSpans.add(
            pw.TextSpan(
              text: marker,
              style: pw.TextStyle(
                font: latinFont,
                fontSize: 12,
                fontWeight: isBullet || isOrdered
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          );
        }
        paragraphSpans.addAll(spans.map((segment) => pw.TextSpan(
          text: segment.text,
          style: styleFor(segment.attributes, segment.text, heading: heading),
        )));
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(
              bottom: 5,
              left: indentLevel * 18.0,
            ),
            child: pw.RichText(
              text: pw.TextSpan(children: paragraphSpans),
              textAlign: alignment,
            ),
          ),
        );
      }
      spans.clear();
    }

    void appendText(String value, Map<String, dynamic> attributes) {
      if (value.isNotEmpty) {
        spans.add(_WriterPdfTextSegment(value, Map<String, dynamic>.from(attributes)));
      }
    }

    for (final operation in delta) {
      final insert = operation['insert'];
      final rawAttributes = operation['attributes'];
      final attributes = rawAttributes is Map
          ? Map<String, dynamic>.from(rawAttributes)
          : <String, dynamic>{};
      if (insert is String) {
        final pieces = insert
            .replaceAll(String.fromCharCode(13), '')
            .split(String.fromCharCode(10));
        for (var i = 0; i < pieces.length; i++) {
          appendText(pieces[i], attributes);
          if (i < pieces.length - 1) flushParagraph(attributes);
        }
      } else if (insert is Map) {
        flushParagraph();
        if (insert.containsKey('image')) {
          final path = insert['image']?.toString() ?? '';
          final file = File(path);
          if (!await file.exists()) {
            throw StateError('Writer image file is missing: $path');
          }
          final imageBytes = await file.readAsBytes();
          if (imageBytes.isNotEmpty) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  width: imageContentWidth(
                    pageFormat: pageFormat,
                    marginLeft: marginLeft,
                    marginRight: marginRight,
                  ),
                  fit: pw.BoxFit.contain,
                ),
              ),
            );
          }
        } else if (insert.containsKey(WriterPageBreakEmbed.embedType)) {
          widgets.add(pw.NewPage());
        } else if (insert.containsKey('offynexbd-writer-table')) {
          widgets.add(_tableWidget(
            insert['offynexbd-writer-table']?.toString() ?? '{}',
            sansFont,
            latinFont,
            imageContentWidth(
              pageFormat: pageFormat,
              marginLeft: marginLeft,
              marginRight: marginRight,
            ),
          ));
        }
      }
    }
    if (spans.isNotEmpty) flushParagraph();

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          marginLeft, marginTop, marginRight, marginBottom,
        ),
        maxPages: 1000,
        header: headerText.trim().isEmpty
            ? null
            : (context) => pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  headerText,
                  style: pw.TextStyle(font: _containsBangla(headerText) ? sansFont : latinFont,
                    fontFallback: _containsBangla(headerText) ? [latinFont] : const [],
                    fontSize: 9, color: PdfColors.grey700),
                ),
              ),
        footer: footerText.trim().isEmpty
            ? null
            : (context) {
                final rendered = footerText
                    .replaceAll('{page}', context.pageNumber.toString())
                    .replaceAll('{pages}', context.pagesCount.toString());
                return pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    rendered,
                    style: pw.TextStyle(font: _containsBangla(rendered) ? sansFont : latinFont,
                      fontFallback: _containsBangla(rendered) ? [latinFont] : const [],
                      fontSize: 9, color: PdfColors.grey700),
                  ),
                );
              },
        build: (_) => widgets,
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  /// Computes physical PDF cell rectangles from the persisted table grid.
  /// Saved editor widths/heights are scaled to the printable page width; merged
  /// cells occupy the full rectangle and covered grid slots are not painted.
  static List<Map<String, double>> tableCellRectangles({
    required Map<String, dynamic> data,
    required double availableWidth,
  }) {
    final rawRows = data['rows'];
    if (rawRows is! List || rawRows.isEmpty ||
        !availableWidth.isFinite || availableWidth <= 0) {
      return <Map<String, double>>[];
    }
    final rows = rawRows.map<List<String>>((row) =>
      row is List ? row.map((cell) => cell?.toString() ?? '').toList()
                  : <String>[row?.toString() ?? '']
    ).toList();
    final columns = rows.fold<int>(1,
      (maximum, row) => row.length > maximum ? row.length : maximum);
    for (final row in rows) {
      while (row.length < columns) { row.add(''); }
    }

    final rawWidths = data['columnWidths'];
    final sourceWidths = List<double>.generate(columns, (index) {
      final value = rawWidths is List && index < rawWidths.length
          ? rawWidths[index]
          : null;
      return value is num && value.isFinite && value > 0
          ? value.toDouble()
          : 150.0;
    });
    final widthTotal = sourceWidths.fold<double>(0, (sum, value) => sum + value);
    final scale = availableWidth / widthTotal;
    final widths = sourceWidths.map((value) => value * scale).toList();
    final rawHeights = data['rowHeights'];
    final heights = List<double>.generate(rows.length, (index) {
      final value = rawHeights is List && index < rawHeights.length
          ? rawHeights[index]
          : null;
      // The editor stores logical pixels; PDF uses points.
      return value is num && value.isFinite && value > 0
          ? (value.toDouble() * 0.75).clamp(24.0, 180.0).toDouble()
          : 42.0;
    });

    final merges = WriterTableBlockEmbed.normalizedMerges(
      data, rowCount: rows.length, columnCount: columns);
    final anchors = <String, Map<String, int>>{
      for (final merge in merges) '${merge['row']}:${merge['column']}': merge,
    };
    final covered = <String>{};
    for (final merge in merges) {
      for (var row = merge['row']!; row < merge['row']! + merge['rowSpan']!; row++) {
        for (var column = merge['column']!; column < merge['column']! + merge['columnSpan']!; column++) {
          if (row != merge['row'] || column != merge['column']) {
            covered.add('$row:$column');
          }
        }
      }
    }

    // Avoid clipping long cell contents. Estimate wrapped lines from the
    // printable cell width, then enlarge the row (or merged row group) before
    // calculating the final cell positions.
    for (var row = 0; row < rows.length; row++) {
      for (var column = 0; column < columns; column++) {
        if (covered.contains('$row:$column')) continue;
        final merge = anchors['$row:$column'];
        final rowSpan = merge?['rowSpan'] ?? 1;
        final columnSpan = merge?['columnSpan'] ?? 1;
        final cellWidth = widths.skip(column).take(columnSpan)
            .fold<double>(0, (sum, value) => sum + value);
        final usableWidth = (cellWidth - 10).clamp(8.0, availableWidth);
        final charsPerLine = (usableWidth / 5.2).floor().clamp(1, 10000);
        final lines = rows[row][column].split('\n').fold<int>(0, (sum, line) =>
          sum + (line.isEmpty ? 1 : (line.length / charsPerLine).ceil()));
        final requiredHeight = lines * 11.0 + 10.0;
        final currentHeight = heights.skip(row).take(rowSpan)
            .fold<double>(0, (sum, value) => sum + value);
        if (requiredHeight > currentHeight) {
          heights[row + rowSpan - 1] += requiredHeight - currentHeight;
        }
      }
    }

    final x = List<double>.filled(columns + 1, 0);
    final y = List<double>.filled(rows.length + 1, 0);
    for (var column = 0; column < columns; column++) {
      x[column + 1] = x[column] + widths[column];
    }
    for (var row = 0; row < rows.length; row++) {
      y[row + 1] = y[row] + heights[row];
    }
    final rectangles = <Map<String, double>>[];
    for (var row = 0; row < rows.length; row++) {
      for (var column = 0; column < columns; column++) {
        if (covered.contains('$row:$column')) continue;
        final merge = anchors['$row:$column'];
        final rowSpan = merge?['rowSpan'] ?? 1;
        final columnSpan = merge?['columnSpan'] ?? 1;
        rectangles.add(<String, double>{
          'row': row.toDouble(),
          'column': column.toDouble(),
          'left': x[column],
          'top': y[row],
          'width': x[column + columnSpan] - x[column],
          'height': y[row + rowSpan] - y[row],
        });
      }
    }
    return rectangles;
  }

  static pw.Widget _tableWidget(
    String raw,
    pw.Font font,
    pw.Font latinFont,
    double availableWidth,
  ) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }
    final rawRows = data['rows'];
    if (rawRows is! List || rawRows.isEmpty) {
      return pw.Text('Table data unavailable', style: pw.TextStyle(font: latinFont));
    }
    final rows = rawRows.map<List<String>>((row) =>
      row is List ? row.map((cell) => cell?.toString() ?? '').toList()
                  : <String>[row?.toString() ?? '']
    ).toList();
    final columns = rows.fold<int>(1,
      (maximum, row) => row.length > maximum ? row.length : maximum);
    for (final row in rows) {
      while (row.length < columns) { row.add(''); }
    }
    final rectangles = tableCellRectangles(
      data: data,
      availableWidth: availableWidth,
    );
    if (rectangles.isEmpty) {
      return pw.Text('Table data unavailable', style: pw.TextStyle(font: latinFont));
    }
    final totalHeight = rectangles.fold<double>(0, (maximum, cell) =>
      (cell['top']! + cell['height']!) > maximum
          ? cell['top']! + cell['height']!
          : maximum);
    final borderColor = _parseIntColor(data['borderColor']) ?? PdfColors.grey;
    final backgroundColor =
        _parseIntColor(data['backgroundColor']) ?? PdfColors.white;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Container(
        width: availableWidth,
        height: totalHeight,
        child: pw.Stack(
          children: rectangles.map((cell) {
            final row = cell['row']!.toInt();
            final column = cell['column']!.toInt();
            final value = rows[row][column];
            return pw.Positioned(
              left: cell['left'],
              top: cell['top'],
              width: cell['width'],
              height: cell['height'],
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: backgroundColor,
                  border: pw.Border.all(color: borderColor, width: 0.6),
                ),
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    font: _containsBangla(value) ? font : latinFont,
                    fontFallback: _containsBangla(value) ? [latinFont] : const [],
                    fontSize: 9,
                    fontWeight: row == 0 && data['headerRow'] == true
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static String _firstParagraphText(List<Map<String, dynamic>> delta) {
    final paragraph = StringBuffer();
    for (final operation in delta) {
      final insert = operation['insert'];
      if (insert is String) {
        final newline = insert.indexOf('\n');
        paragraph.write(newline < 0 ? insert : insert.substring(0, newline));
        if (newline >= 0) break;
      } else if (insert is Map && paragraph.isEmpty) {
        break;
      }
    }
    return paragraph.toString();
  }

  static bool _containsBangla(String value) =>
      RegExp(r'[\u0980-\u09FF]').hasMatch(value);

  static PdfColor? _parseIntColor(dynamic value) {
    if (value is! int) return null;
    return PdfColor(
      ((value >> 16) & 0xFF) / 255,
      ((value >> 8) & 0xFF) / 255,
      (value & 0xFF) / 255,
    );
  }

  /// Returns the printable image width in PDF points after page margins.
  /// This keeps embedded images inside A5, A4, Letter and landscape pages.
  static double imageContentWidth({
    required PdfPageFormat pageFormat,
    required double marginLeft,
    required double marginRight,
  }) {
    final available = pageFormat.width - marginLeft - marginRight;
    if (!available.isFinite || available <= 0) {
      throw ArgumentError('Writer PDF horizontal margins leave no printable width.');
    }
    return available;
  }

  static PdfColor? highlightColorForAttributes(
    Map<String, dynamic> attributes,
  ) {
    return _parseColor(attributes['background']?.toString());
  }

  static pw.TextDecoration? textDecorationForAttributes(
    Map<String, dynamic> attributes,
  ) {
    final decorations = <pw.TextDecoration>[];
    if (attributes['underline'] == true) {
      decorations.add(pw.TextDecoration.underline);
    }
    if (attributes['strike'] == true) {
      decorations.add(pw.TextDecoration.lineThrough);
    }
    if (decorations.isEmpty) return null;
    return pw.TextDecoration.combine(decorations);
  }

  static PdfColor? _parseColor(String? value) {
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceAll('#', '');
    if (hex.length == 8) hex = hex.substring(2);
    if (hex.length != 6) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return _parseIntColor(0xFF000000 | parsed);
  }
}

class _WriterPdfTextSegment {
  const _WriterPdfTextSegment(this.text, this.attributes);

  final String text;
  final Map<String, dynamic> attributes;
}
