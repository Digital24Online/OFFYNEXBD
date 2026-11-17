import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart' as dc;
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import '../writer/writer_table.dart';

class PdfConversionResult {
  const PdfConversionResult({
    required this.title,
    required this.pageCount,
    required this.imageCount,
    required this.writerDelta,
    required this.docxBytes,
    required this.ocrUsed,
    this.ocrWarning,
  });

  final String title;
  final int pageCount;
  final int imageCount;
  final List<Map<String, dynamic>> writerDelta;
  final Uint8List docxBytes;
  final bool ocrUsed;
  final String? ocrWarning;
}

class PdfToDocumentService {
  static List<Map<String, dynamic>> plainTextToDelta(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return <Map<String, dynamic>>[
      <String, dynamic>{'insert': normalized.isEmpty || normalized.endsWith('\n') ? normalized.isEmpty ? '\n' : normalized : '$normalized\n'},
    ];
  }

  static Future<PdfConversionResult> convert(
    Uint8List bytes, {
    required String sourceName,
    bool runOcr = true,
  }) async {
    if (bytes.length < 8 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const FormatException('নির্বাচিত ফাইলটি সঠিক PDF নয়।');
    }

    final dynamic pdf = await dc.PdfReader.loadFromBytes(bytes);
    final text = (pdf.text as String? ?? '').trim();
    final pageCount = (pdf.pageCount as int?) ?? 0;
    final images = ((pdf.images as Iterable?) ?? const []).toList();
    final dynamic docx = pdf.toDocx();
    final dynamic exported = await dc.DocxExporter().exportToBytes(docx);
    final docxBytes = exported is Uint8List
        ? exported
        : Uint8List.fromList(List<int>.from(exported as List));

    var delta = await _toWriterDelta(pdf.elements);
    var ocrUsed = false;
    String? warning;

    if (text.isEmpty && runOcr) {
      if (Platform.isWindows) {
        warning = 'এই Windows সংস্করণে OCR ইঞ্জিন এখনো যুক্ত হয়নি।';
      } else if (images.isEmpty) {
        warning = 'স্ক্যান পৃষ্ঠা-ছবি পাওয়া যায়নি; OCR করা সম্ভব হয়নি।';
      } else {
        try {
          final recognized = await _ocrImages(images);
          if (recognized.trim().isNotEmpty) {
            delta = plainTextToDelta(recognized.trim());
            ocrUsed = true;
          } else {
            warning = 'OCR কোনো লেখা শনাক্ত করতে পারেনি।';
          }
        } catch (error) {
          warning = 'OCR সম্পন্ন হয়নি: $error';
        }
      }
    }

    if (_isEmpty(delta) && text.isNotEmpty) delta = plainTextToDelta(text);
    if (_isEmpty(delta)) {
      throw const FormatException('PDF থেকে সম্পাদনাযোগ্য লেখা পাওয়া যায়নি।');
    }

    final title = sourceName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
    return PdfConversionResult(
      title: title.isEmpty ? 'Converted PDF' : title,
      pageCount: pageCount,
      imageCount: images.length,
      writerDelta: delta,
      docxBytes: docxBytes,
      ocrUsed: ocrUsed,
      ocrWarning: warning,
    );
  }

  static bool _isEmpty(List<Map<String, dynamic>> delta) =>
      delta.every((op) => op['insert'] is String && (op['insert'] as String).trim().isEmpty);

  static Future<String> _ocrImages(List<dynamic> images) async {
    final temp = await getTemporaryDirectory();
    final results = <String>[];
    for (var i = 0; i < images.length; i++) {
      final bytes = Uint8List.fromList(List<int>.from(images[i].bytes as List));
      if (bytes.isEmpty) continue;
      final file = File('${temp.path}/offynex_ocr_${DateTime.now().microsecondsSinceEpoch}_$i.png');
      await file.writeAsBytes(bytes, flush: true);
      try {
        final text = await TesseractOcr.extractText(
          file.path,
          config: OCRConfig(
            language: 'ben+eng',
            engine: OCREngine.tesseract,
            options: const {'preserve_interword_spaces': '1'},
          ),
        );
        if (text.trim().isNotEmpty) results.add(text.trim());
      } finally {
        if (await file.exists()) await file.delete();
      }
    }
    return results.join('\n\n');
  }

  static Future<List<Map<String, dynamic>>> _toWriterDelta(dynamic elements) async {
    final delta = <Map<String, dynamic>>[];
    final support = await getApplicationSupportDirectory();
    final imageDir = Directory('${support.path}/offynexbd_images');

    void addText(String value, [Map<String, dynamic>? attrs]) {
      if (value.isEmpty) return;
      delta.add(<String, dynamic>{'insert': value, if (attrs != null && attrs.isNotEmpty) 'attributes': attrs});
    }

    String paragraph(dynamic paragraph) {
      final buffer = StringBuffer();
      for (final dynamic child in (paragraph.children as Iterable?) ?? const []) {
        if (!child.runtimeType.toString().contains('DocxText')) continue;
        final value = child.content?.toString() ?? '';
        final attrs = <String, dynamic>{};
        try {
          if (child.fontWeight?.toString().toLowerCase().contains('bold') == true) attrs['bold'] = true;
          if (child.fontStyle?.toString().toLowerCase().contains('italic') == true) attrs['italic'] = true;
          if (child.decoration?.toString().toLowerCase().contains('underline') == true) attrs['underline'] = true;
          if (child.fontSize is num && child.fontSize > 0) attrs['size'] = child.fontSize.toString();
          final color = child.color?.hex?.toString();
          if (color != null && color.isNotEmpty) attrs['color'] = color.startsWith('#') ? color : '#$color';
        } catch (_) {}
        addText(value, attrs);
        buffer.write(value);
      }
      return buffer.toString();
    }

    for (final dynamic element in (elements as Iterable?) ?? const []) {
      final type = element.runtimeType.toString();
      if (type.contains('DocxParagraph')) {
        paragraph(element);
        addText('\n');
      } else if (type.contains('DocxImage')) {
        final imageBytes = Uint8List.fromList(List<int>.from(element.bytes as List));
        if (imageBytes.isNotEmpty) {
          await imageDir.create(recursive: true);
          final path = '${imageDir.path}/offynex_pdf_${DateTime.now().microsecondsSinceEpoch}.png';
          await File(path).writeAsBytes(imageBytes, flush: true);
          delta.add(<String, dynamic>{'insert': <String, dynamic>{'image': path}});
          addText('\n');
        }
      } else if (type.contains('DocxTable')) {
        final rows = <List<String>>[];
        for (final dynamic row in (element.rows as Iterable?) ?? const []) {
          final cells = <String>[];
          for (final dynamic cell in (row.cells as Iterable?) ?? const []) {
            final cellBuffer = StringBuffer();
            for (final dynamic node in (cell.children as Iterable?) ?? const []) {
              if (node.runtimeType.toString().contains('DocxParagraph')) {
                cellBuffer.write(paragraph(node));
              } else if (node.runtimeType.toString().contains('DocxText')) {
                cellBuffer.write(node.content?.toString() ?? '');
              }
            }
            cells.add(cellBuffer.toString().trim());
          }
          if (cells.isNotEmpty) rows.add(cells);
        }
        if (rows.isNotEmpty) {
          final data = <String, dynamic>{
            'rows': rows, 'headerRow': true, 'version': 1,
            'borderColor': 0xFF333333, 'backgroundColor': 0xFFFFFFFF,
          };
          delta.add(<String, dynamic>{
            'insert': <String, dynamic>{WriterTableBlockEmbed.embedType: jsonEncode(data)},
          });
          addText('\n');
        }
      }
    }
    if (delta.isNotEmpty && (delta.last['insert'] is! String || !(delta.last['insert'] as String).endsWith('\n'))) {
      addText('\n');
    }
    return delta;
  }
}
