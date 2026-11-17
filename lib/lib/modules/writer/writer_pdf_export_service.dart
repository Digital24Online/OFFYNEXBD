import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:bangla_pdf/widgets.dart' as pw;

/// Builds Writer print/PDF output with HarfBuzz-compatible OpenType Bengali shaping.
class WriterPdfExportService {
  static Future<Uint8List> build({
    required String title,
    required List<Map<String, dynamic>> delta,
    required ByteData sansFontData,
    required ByteData serifFontData,
    required PdfPageFormat pageFormat,
    required double marginTop,
    required double marginBottom,
    required double marginLeft,
    required double marginRight,
  }) async {
    final sansFont = pw.Font.ttf(sansFontData);
    final serifFont = pw.Font.ttf(serifFontData);
    final widgets = <pw.Widget>[
      pw.Text(title, style: pw.TextStyle(font: sansFont, fontSize: 18)),
      pw.SizedBox(height: 14),
    ];
    final spans = <pw.TextSpan>[];

    pw.Font fontFor(Map<String, dynamic> attributes) =>
        attributes['font']?.toString() == 'serif' ? serifFont : sansFont;

    pw.TextStyle styleFor(Map<String, dynamic> attributes) {
      final rawSize = double.tryParse(attributes['size']?.toString() ?? '');
      final size = rawSize == null ? 12.0 : (rawSize * 0.75).clamp(5.0, 144.0).toDouble();
      final decoration = attributes['underline'] == true
          ? pw.TextDecoration.underline
          : attributes['strike'] == true
              ? pw.TextDecoration.lineThrough
              : null;
      return pw.TextStyle(
        font: fontFor(attributes),
        fontSize: size,
        fontWeight: attributes['bold'] == true
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
      if (spans.isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
      } else {
        final alignment = switch (paragraphAttributes?['align']?.toString()) {
          'center' => pw.TextAlign.center,
          'right' => pw.TextAlign.right,
          'justify' => pw.TextAlign.justify,
          _ => pw.TextAlign.left,
        };
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.RichText(
              text: pw.TextSpan(children: List<pw.TextSpan>.from(spans)),
              textAlign: alignment,
            ),
          ),
        );
      }
      spans.clear();
    }

    void appendText(String value, Map<String, dynamic> attributes) {
      if (value.isNotEmpty) {
        spans.add(pw.TextSpan(text: value, style: styleFor(attributes)));
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
        } else if (insert.containsKey('offynexbd-writer-table')) {
          widgets.add(_tableWidget(
            insert['offynexbd-writer-table']?.toString() ?? '{}',
            sansFont,
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
        build: (_) => widgets,
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  static pw.Widget _tableWidget(String raw, pw.Font font) {
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
      return pw.Text('Table data unavailable', style: pw.TextStyle(font: font));
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
                    font: font,
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
}
