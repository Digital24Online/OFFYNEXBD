import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart' as dc;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
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
  static const int maxPdfBytes = 50 * 1024 * 1024;
  static const int maxPdfPages = 1000;
  static const int maxImageBytes = 30 * 1024 * 1024;

  static void validatePdfBytes(Uint8List bytes) {
    final header = bytes.length >= 8
        ? String.fromCharCodes(bytes.take(8))
        : '';
    if (bytes.length < 8 ||
        bytes.length > maxPdfBytes ||
        !RegExp(r'^%PDF-(?:1\.[0-7]|2\.0)$').hasMatch(header)) {
      throw const FormatException('PDF is invalid, empty or exceeds the 50 MB limit.');
    }
  }

  static void validatePageCount(int pageCount) {
    if (pageCount < 1 || pageCount > maxPdfPages) {
      throw FormatException('PDF page count must be between 1 and $maxPdfPages.');
    }
  }

  static bool isValidDocxBytes(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  static List<Map<String, dynamic>> plainTextToDelta(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final value = normalized.isEmpty || normalized.endsWith('\n')
        ? normalized.isEmpty ? '\n' : normalized
        : '$normalized\n';
    return <Map<String, dynamic>>[<String, dynamic>{'insert': value}];
  }

  static Future<PdfConversionResult> convert(
    Uint8List bytes, {
    required String sourceName,
    bool runOcr = true,
  }) async {
    validatePdfBytes(bytes);
    final dynamic pdf = await dc.PdfReader.loadFromBytes(bytes);
    final text = (pdf.text as String? ?? '').trim();
    final pageCount = (pdf.pageCount as int?) ?? 0;
    validatePageCount(pageCount);
    final images = ((pdf.images as Iterable?) ?? const []).toList();
    final dynamic docx = pdf.toDocx();
    final dynamic exported = await dc.DocxExporter().exportToBytes(docx);
    var docxBytes = exported is Uint8List
        ? exported
        : Uint8List.fromList(List<int>.from(exported as List));
    if (!isValidDocxBytes(docxBytes)) {
      throw const FormatException('PDF conversion did not produce a valid DOCX archive.');
    }

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
            // The PDF parser's initial DOCX contains no selectable text for
            // image-only PDFs. Rebuild the DOCX from OCR output as well as the
            // Writer Delta, so both exported formats contain the same text.
            docxBytes = await buildDocxFromPlainText(recognized.trim());
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
    final title = sourceName.replaceFirst(
      RegExp(r'\.pdf$', caseSensitive: false), '',
    );
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

  /// Builds an editable DOCX from OCR text, retaining paragraph breaks.
  /// This is used when the source PDF contains only page images.
  static Future<Uint8List> buildDocxFromPlainText(String text) async {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final paragraphs = normalized.split('\n');
    final html = paragraphs
        .map((paragraph) => '<p>${_escapeHtml(paragraph)}</p>')
        .join();
    final nodes = await dc.DocxParser.fromHtml(html);
    final document = dc.DocxBuiltDocument(elements: nodes);
    final Uint8List bytes =
        await dc.DocxExporter().exportToBytes(document);
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw StateError('OCR DOCX export did not produce a valid DOCX file.');
    }
    return bytes;
  }

  static String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  static bool isSupportedImageName(String name) =>
      RegExp(r'\.(png|jpe?g|webp|bmp|tif?f)$', caseSensitive: false)
          .hasMatch(name);

  /// Validates image container bytes independently of the file extension.
  static bool hasValidImageSignature(Uint8List bytes, String sourceName) {
    if (bytes.isEmpty) return false;
    switch (sourceName.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return bytes.length >= 3 && bytes[0] == 0xFF &&
            bytes[1] == 0xD8 && bytes[2] == 0xFF;
      case 'png':
        return bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 &&
            bytes[2] == 0x4E && bytes[3] == 0x47 && bytes[4] == 0x0D &&
            bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A;
      case 'webp':
        return bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      case 'bmp':
        return bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D;
      case 'tif':
      case 'tiff':
        return bytes.length >= 4 &&
            ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0) ||
             (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0 && bytes[3] == 0x2A));
      default:
        return false;
    }
  }

  static Future<PdfConversionResult> convertImage(
    Uint8List imageBytes, {
    required String sourceName,
  }) async {
    if (imageBytes.isEmpty || imageBytes.length > maxImageBytes ||
        !isSupportedImageName(sourceName) ||
        !hasValidImageSignature(imageBytes, sourceName)) {
      throw const FormatException(
        'সমর্থিত ছবি নির্বাচন করুন: JPG, JPEG, PNG, WEBP, BMP বা TIFF।',
      );
    }
    final recognized = await recognizeImageBytes(
      imageBytes,
      sourceName: sourceName,
    );
    final fontData = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final font = pw.Font.ttf(fontData);
    final intermediatePdf = pw.Document();
    intermediatePdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => [
          pw.Text(recognized.trim(), style: pw.TextStyle(font: font, fontSize: 11)),
        ],
      ),
    );
    final pdfBytes = Uint8List.fromList(await intermediatePdf.save());
    final title = sourceName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final converted = await convert(
      pdfBytes,
      sourceName: '${title.isEmpty ? 'Image Document' : title}.pdf',
      runOcr: false,
    );
    return PdfConversionResult(
      title: title.isEmpty ? 'Image Document' : title,
      pageCount: converted.pageCount,
      imageCount: 1,
      writerDelta: plainTextToDelta(recognized.trim()),
      docxBytes: converted.docxBytes,
      ocrUsed: true,
    );
  }

  static Future<String> recognizeImageBytes(
    Uint8List imageBytes, {
    required String sourceName,
  }) async {
    if (imageBytes.isEmpty ||
        !isSupportedImageName(sourceName) ||
        !hasValidImageSignature(imageBytes, sourceName)) {
      throw const FormatException(
        'ছবির ফাইলের ধরন ও প্রকৃত ডেটা মিলছে না অথবা ছবি বৈধ নয়।',
      );
    }
    if (imageBytes.length > maxImageBytes) {
      throw const FormatException('ছবির সর্বোচ্চ সাইজ ৩০ MB।');
    }
    if (Platform.isWindows) {
      throw UnsupportedError(
        'এই Windows সংস্করণে OCR ইঞ্জিন এখনো যুক্ত হয়নি।',
      );
    }
    final temp = await getTemporaryDirectory();
    final extension = sourceName.split('.').last.toLowerCase();
    final imageFile = File(
      '${temp.path}/offynex_image_ocr_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    try {
      await imageFile.writeAsBytes(imageBytes, flush: true);
      final recognized = await TesseractOcr.extractText(
        imageFile.path,
        config: OCRConfig(
          language: 'ben+eng',
          engine: OCREngine.tesseract,
          options: const {'preserve_interword_spaces': '1'},
        ),
      );
      if (recognized.trim().isEmpty) {
        throw const FormatException(
          'ছবি থেকে কোনো লেখা শনাক্ত হয়নি। পরিষ্কার ও সোজা ছবি ব্যবহার করুন।',
        );
      }
      return recognized.trim();
    } finally {
      if (await imageFile.exists()) await imageFile.delete();
    }
  }

  /// Detects the actual image container before passing embedded PDF images
  /// to OCR. PDF parsers may return JPEG, PNG, WEBP, BMP or TIFF bytes.
  static String? _imageExtensionFromSignature(Uint8List bytes) {
    for (final extension in const ['jpg', 'png', 'webp', 'bmp', 'tif']) {
      if (hasValidImageSignature(bytes, 'image.$extension')) return extension;
    }
    return null;
  }

  static bool _isEmpty(List<Map<String, dynamic>> delta) =>
      delta.every((op) =>
          op['insert'] is String && (op['insert'] as String).trim().isEmpty);

  static Future<String> _ocrImages(List<dynamic> images) async {
    final temp = await getTemporaryDirectory();
    final results = <String>[];
    for (var i = 0; i < images.length; i++) {
      final bytes = Uint8List.fromList(List<int>.from(images[i].bytes as List));
      if (bytes.isEmpty || bytes.length > maxImageBytes) continue;
      final extension = _imageExtensionFromSignature(bytes);
      if (extension == null) continue;
      final file = File(
        '${temp.path}/offynex_ocr_${DateTime.now().microsecondsSinceEpoch}_$i.$extension',
      );
      try {
        await file.writeAsBytes(bytes, flush: true);
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

  static Future<List<Map<String, dynamic>>> _toWriterDelta(
    dynamic elements,
  ) async {
    final delta = <Map<String, dynamic>>[];
    void addText(String value, [Map<String, dynamic>? attrs]) {
      if (value.isEmpty) return;
      delta.add(<String, dynamic>{
        'insert': value,
        if (attrs != null && attrs.isNotEmpty) 'attributes': attrs,
      });
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
          final support = await getApplicationSupportDirectory();
          final imageDir = Directory('${support.path}/offynexbd_images');
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
    if (delta.isNotEmpty &&
        (delta.last['insert'] is! String ||
            !(delta.last['insert'] as String).endsWith('\n'))) {
      addText('\n');
    }
    return delta;
  }
}
