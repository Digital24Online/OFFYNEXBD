import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Creates a portable landscape PDF presentation from one-line-per-slide text.
class SlidesPdfExportService {
  static Future<Uint8List> build({
    required String title,
    required List<String> slideTexts,
  }) async {
    final slides = slideTexts
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (slides.isEmpty) {
      throw const FormatException('A presentation needs at least one slide.');
    }
    if (slides.length > 200) {
      throw const FormatException('A presentation can contain up to 200 slides.');
    }
    final fontData = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final font = pw.Font.ttf(fontData);
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: font),
      margin: const pw.EdgeInsets.all(30),
      build: (context) => [
        for (var index = 0; index < slides.length; index++) ...[
          if (index > 0) pw.NewPage(),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey300, width: 1.2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.trim().isEmpty ? 'OFFYNEXBD Presentation' : title.trim(),
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'SLIDE ${index + 1} / ${slides.length}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600),
                ),
                pw.Divider(color: PdfColors.blueGrey300),
                pw.SizedBox(height: 12),
                pw.Text(
                  slides[index],
                  style: const pw.TextStyle(fontSize: 25, lineSpacing: 8),
                ),
              ],
            ),
          ),
        ],
      ],
    ));
    return Uint8List.fromList(await pdf.save());
  }
}
