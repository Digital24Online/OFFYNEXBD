import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:bangla_pdf/widgets.dart' as pw;

/// Generates printable Sheets output with OpenType-shaped Bengali text.
class SheetsPdfExportService {
  static Future<Uint8List> build({
    required String sheetName,
    required List<List<String>> values,
    required List<List<Map<String, dynamic>>> styles,
    required ByteData sansFontData,
    required ByteData serifFontData,
    required ByteData latinFontData,
    required bool showGridlines,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    if (values.isEmpty || values.every((row) => row.every((cell) => cell.isEmpty))) {
      throw const FormatException('শিটে প্রিন্ট করার মতো কোনো তথ্য নেই।');
    }
    final sans = pw.Font.ttf(sansFontData);
    final serif = pw.Font.ttf(serifFontData);
    final latin = pw.Font.ttf(latinFontData);
    final columnCount = values.fold<int>(1, (max, row) => row.length > max ? row.length : max);
    final rows = <pw.TableRow>[];
    for (var r = 0; r < values.length; r++) {
      rows.add(pw.TableRow(
        children: List<pw.Widget>.generate(columnCount, (c) {
          final value = c < values[r].length ? values[r][c] : '';
          final style = r < styles.length && c < styles[r].length
              ? styles[r][c]
              : const <String, dynamic>{};
          final font = style['fontFamily'] == 'serif' ? serif : sans;
          final size = ((style['fontSize'] as num?)?.toDouble() ?? 9).clamp(6.0, 24.0).toDouble();
          final color = _color(style['fontColor']?.toString()) ?? PdfColors.black;
          final fill = _color(style['fillColor']?.toString()) ?? PdfColors.white;
          final horizontal = switch (style['align']) {
            'center' => 0.0,
            'right' => 1.0,
            _ => -1.0,
          };
          final vertical = switch (style['verticalAlign']) {
            'top' => -1.0,
            'bottom' => 1.0,
            _ => 0.0,
          };
          final border = style['border'] == true
              ? pw.Border.all(color: PdfColors.blueGrey700, width: 1.2)
              : showGridlines
                  ? pw.Border.all(color: PdfColors.grey600, width: 0.45)
                  : null;
          return pw.Container(
            alignment: pw.Alignment(horizontal, vertical),
            decoration: pw.BoxDecoration(color: fill, border: border),
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: pw.Text(
              value,
              textAlign: switch (style['align']) {
                'center' => pw.TextAlign.center,
                'right' => pw.TextAlign.right,
                _ => pw.TextAlign.left,
              },
              maxLines: style['wrapText'] == true ? 3 : 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                font: font,
                fontFallback: [latin],
                fontSize: size,
                color: color,
                fontWeight: style['bold'] == true ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontStyle: style['italic'] == true ? pw.FontStyle.italic : pw.FontStyle.normal,
                decoration: style['underline'] == true ? pw.TextDecoration.underline : null,
              ),
            ),
          );
        }),
      ));
    }
    final document = pw.Document();
    document.addPage(pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(sheetName, style: pw.TextStyle(font: sans, fontFallback: [latin], fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(font: sans, fontFallback: [latin], fontSize: 8, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Table(
          columnWidths: {for (var i = 0; i < columnCount; i++) i: const pw.FlexColumnWidth(1)},
          children: rows,
        ),
      ],
    ));
    return Uint8List.fromList(await document.save());
  }

  static PdfColor? _color(String? value) {
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceAll('#', '');
    if (hex.length == 8) hex = hex.substring(2);
    if (hex.length != 6) return null;
    final number = int.tryParse(hex, radix: 16);
    if (number == null) return null;
    return PdfColor(((number >> 16) & 255) / 255, ((number >> 8) & 255) / 255, (number & 255) / 255);
  }
}
