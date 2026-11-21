import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'pdf_to_document_service.dart';
import '../../theme/offynex_theme.dart';

/// Read-only PDF preview with native print/share actions.
/// Editing and page-structure operations are deliberately not advertised here.
class PdfReaderScreen extends StatelessWidget {
  const PdfReaderScreen({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.isBangla,
  });

  final Uint8List bytes;
  final String fileName;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    PdfToDocumentService.validatePdfBytes(bytes);
    final safeName = fileName.trim().isEmpty ? 'OFFYNEXBD.pdf' : fileName;
    return Scaffold(
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        title: const Text('PDF Reader'),
        backgroundColor: OFFYNEXTheme.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: safeName,
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        useActions: true,
        loadingWidget: Center(
          child: Text(isBangla ? 'PDF প্রস্তুত হচ্ছে…' : 'Preparing PDF…'),
        ),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              (isBangla ? 'PDF খোলা যায়নি: ' : 'Could not open PDF: ') + error.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
