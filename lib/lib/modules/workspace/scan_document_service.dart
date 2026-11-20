import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../pdf/pdf_to_document_service.dart';

class ScanCaptureResult {
  const ScanCaptureResult({
    required this.pdfBytes,
    required this.pdfPath,
    required this.fileName,
    required this.pageCount,
    required this.recognizedText,
  });

  final Uint8List pdfBytes;
  final String pdfPath;
  final String fileName;
  final int pageCount;
  final String recognizedText;
}

/// Android's native ML Kit document scanner: auto capture, edge detection,
/// crop/perspective correction, rotation, filters and multi-page PDF output.
class ScanDocumentService {
  static const int maxPages = 50;
  static const int maxPdfBytes = 50 * 1024 * 1024;
  static const int maxOcrImageBytes = 30 * 1024 * 1024;

  static void validateCapturedPdf(Uint8List bytes, int pageCount) {
    if (pageCount < 1 || pageCount > maxPages) {
      throw FormatException('Scan page count must be between 1 and $maxPages.');
    }
    if (bytes.length < 8 ||
        bytes.length > maxPdfBytes ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const FormatException('Scan output is not a valid PDF or exceeds 50 MB.');
    }
  }

  static String combineRecognizedPages(Iterable<String> pages) => pages
      .map((page) => page.trim())
      .where((page) => page.isNotEmpty)
      .join('\n\n');

  static void validateImportedImages(
    List<({String name, Uint8List bytes})> images,
  ) {
    if (images.isEmpty || images.length > maxPages) {
      throw FormatException('Imported scan must contain 1 to $maxPages images.');
    }
    var totalBytes = 0;
    for (final image in images) {
      final extension = image.name.split('.').last.toLowerCase();
      if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
        throw const FormatException('Imported scan supports JPEG and PNG images only.');
      }
      if (image.bytes.isEmpty || image.bytes.length > maxOcrImageBytes) {
        throw const FormatException('Each scan image must be between 1 byte and 30 MB.');
      }
      totalBytes += image.bytes.length;
      if (totalBytes > maxPdfBytes) {
        throw const FormatException('Combined scan images exceed 50 MB.');
      }
    }
  }

  /// Creates a multi-page scan PDF from imported images on platforms where
  /// the native ML Kit scanner is unavailable. JPEG/PNG originals are embedded
  /// in the PDF; OCR failures never discard the saved scan.
  static Future<ScanCaptureResult> captureImportedImages(
    List<({String name, Uint8List bytes})> images,
  ) async {
    validateImportedImages(images);

    final document = pw.Document();
    for (final image in images) {
      final memoryImage = pw.MemoryImage(image.bytes);
      document.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(
          child: pw.Image(memoryImage, fit: pw.BoxFit.contain),
        ),
      ));
    }
    final pdfBytes = Uint8List.fromList(await document.save());
    validateCapturedPdf(pdfBytes, images.length);

    final savedFile = await _savePdf(pdfBytes);
    final recognizedPages = <String>[];
    for (var index = 0; index < images.length; index++) {
      try {
        final text = await PdfToDocumentService.recognizeImageBytes(
          images[index].bytes,
          sourceName: images[index].name,
        );
        if (text.trim().isNotEmpty) recognizedPages.add(text.trim());
      } catch (_) {
        // Keep the complete PDF even if OCR fails on one or more pages.
      }
    }

    return ScanCaptureResult(
      pdfBytes: pdfBytes,
      pdfPath: savedFile.path,
      fileName: savedFile.uri.pathSegments.last,
      pageCount: images.length,
      recognizedText: combineRecognizedPages(recognizedPages),
    );
  }

  static Future<File> _savePdf(Uint8List bytes) async {
    final documents = await getApplicationDocumentsDirectory();
    final scansDirectory = Directory('${documents.path}/OFFYNEXBD/Scans');
    await scansDirectory.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final savedFile = File('${scansDirectory.path}/OFFYNEXBD_Scan_$stamp.pdf');
    final pendingFile = File('${savedFile.path}.pending');
    try {
      await pendingFile.writeAsBytes(bytes, flush: true);
      if (await pendingFile.length() != bytes.length) {
        throw const FileSystemException('Scan PDF could not be fully written.');
      }
      return await pendingFile.rename(savedFile.path);
    } catch (_) {
      if (await pendingFile.exists()) await pendingFile.delete();
      rethrow;
    }
  }

  static Future<ScanCaptureResult?> captureAndroid() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Native document scanning is currently available on Android only.',
      );
    }

    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg, DocumentFormat.pdf},
        mode: ScannerMode.full,
        pageLimit: maxPages,
        isGalleryImport: true,
      ),
    );

    late final DocumentScanningResult result;
    try {
      result = await scanner.scanDocument();
    } on PlatformException catch (error) {
      if (error.code.toLowerCase().contains('cancel') ||
          error.message?.toLowerCase().contains('operation cancelled') == true) {
        return null;
      }
      rethrow;
    } finally {
      await scanner.close();
    }

    final pdf = result.pdf;
    if (pdf == null || pdf.uri.trim().isEmpty) {
      throw const FormatException('স্ক্যান থেকে PDF তৈরি হয়নি।');
    }

    final sourcePdf = File(pdf.uri);
    if (!await sourcePdf.exists()) {
      throw const FileSystemException('স্ক্যান করা PDF ফাইল পাওয়া যায়নি।');
    }
    final pdfBytes = await sourcePdf.readAsBytes();
    validateCapturedPdf(pdfBytes, pdf.pageCount);

    // Preserve the captured PDF before OCR, so a recognition failure cannot
    // discard the user's scan.
    // Save the PDF before OCR so recognition failures cannot discard the scan.
    final savedFile = await _savePdf(pdfBytes);
    final fileName = savedFile.uri.pathSegments.last;

    final recognizedPages = <String>[];
    final imagePaths = result.images ?? const <String>[];
    for (var index = 0; index < imagePaths.length; index++) {
      final imageFile = File(imagePaths[index]);
      if (!await imageFile.exists()) continue;
      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty || imageBytes.length > maxOcrImageBytes) {
        continue;
      }
      try {
        final text = await PdfToDocumentService.recognizeImageBytes(
          imageBytes,
          sourceName: 'scan_page_${index + 1}.jpg',
        );
        if (text.trim().isNotEmpty) recognizedPages.add(text.trim());
      } catch (_) {
        // Keep the captured PDF even if OCR fails on an individual page.
      }
    }

    return ScanCaptureResult(
      pdfBytes: pdfBytes,
      pdfPath: savedFile.path,
      fileName: fileName,
      pageCount: pdf.pageCount,
      recognizedText: combineRecognizedPages(recognizedPages),
    );
  }
}
