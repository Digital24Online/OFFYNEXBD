import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:bangla_pdf/widgets.dart' as pw;
import 'writer_page_break.dart';

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
      final decoration = attributes['underline'] == true
          ? pw.TextDecoration.underline
          : attributes['strike'] == true
              ? pw.TextDecoration.lineThrough
              : null;
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
                  width: 430,
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

  static pw.Widget _tableWidget(String raw, pw.Font font, pw.Font latinFont) {
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
    final rows = rawRows.map<List<String>>((row) {
      if (row is List) return row.map((cell) => cell?.toString() ?? '').toList();
      return <String>[row?.toString() ?? ''];
    }).toList();
    final columns = rows.fold<int>(
      1, (maximum, row) => row.length > maximum ? row.length : maximum,
    );
    final borderColor = _parseIntColor(data['borderColor']) ?? PdfColors.grey;
    final backgroundColor =
        _parseIntColor(data['backgroundColor']) ?? PdfColors.white;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: borderColor, width: 0.6),
        children: List.generate(rows.length, (rowIndex) {
          return pw.TableRow(
            children: List.generate(columns, (columnIndex) {
              final value = columnIndex < rows[rowIndex].length
                  ? rows[rowIndex][columnIndex]
                  : '';
              return pw.Container(
                color: backgroundColor,
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    font: _containsBangla(value) ? font : latinFont,
                    fontFallback: _containsBangla(value) ? [latinFont] : const [],
                    fontSize: 9,
                    fontWeight: rowIndex == 0 && data['headerRow'] == true
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              );
            }),
          );
        }),
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

  static PdfColor? _parseColor(String? value) {
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceAll('#', '');
    if (hex.length == 8) hex = hex.substring(2);
    if (hex.length != 6) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return _parseIntColor(0xFF000000 | parsed);
  }

class _WriterPdfTextSegment {
  const _WriterPdfTextSegment(this.text, this.attributes);

  final String text;
  final Map<String, dynamic> attributes;
}
}
