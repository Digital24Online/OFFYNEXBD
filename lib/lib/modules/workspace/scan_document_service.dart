import 'dart:io';
import 'dart:typed_data';

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
      if (error.message?.toLowerCase().contains('operation cancelled') == true) {
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
    if (pdfBytes.isEmpty || pdfBytes.length > maxPdfBytes) {
      throw const FormatException('স্ক্যান PDF খালি অথবা ৫০ MB-এর বেশি।');
    }

    final recognizedPages = <String>[];
    final imagePaths = result.images ?? const <String>[];
    for (var index = 0; index < imagePaths.length; index++) {
      final imageFile = File(imagePaths[index]);
      if (!await imageFile.exists()) continue;
      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty || imageBytes.length > 30 * 1024 * 1024) {
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

    final documents = await getApplicationDocumentsDirectory();
    final scansDirectory = Directory('${documents.path}/OFFYNEXBD/Scans');
    await scansDirectory.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'OFFYNEXBD_Scan_$stamp.pdf';
    final savedFile = File('${scansDirectory.path}/$fileName');
    await savedFile.writeAsBytes(pdfBytes, flush: true);

    return ScanCaptureResult(
      pdfBytes: pdfBytes,
      pdfPath: savedFile.path,
      fileName: fileName,
      pageCount: pdf.pageCount,
      recognizedText: recognizedPages.join('\n\n'),
    );
  }
}
