import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../writer/writer_screen.dart';
import 'pdf_to_document_service.dart';
import 'pdf_reader_screen.dart';
import '../../theme/offynex_theme.dart';

class PdfToDocumentScreen extends StatefulWidget {
  const PdfToDocumentScreen({super.key, required this.isBangla});
  final bool isBangla;

  @override
  State<PdfToDocumentScreen> createState() => _PdfToDocumentScreenState();
}

class _PdfToDocumentScreenState extends State<PdfToDocumentScreen> {
  PdfConversionResult? result;
  String? sourceName;
  Map<String, dynamic>? savedDocument;
  Uint8List? sourcePdfBytes;
  String? error;
  bool busy = false;

  Future<void> _convert() async {
    if (busy) return;
    setState(() { busy = true; error = null; result = null; });
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
      if (!mounted) return;
      if (file == null) { setState(() => busy = false); return; }
      final length = file.lengthSync() ?? await file.length();
      if (length == null || length == 0) throw const FormatException('PDF ফাইলটি খালি।');
      if (length > 50 * 1024 * 1024) throw const FormatException('PDF-এর সর্বোচ্চ সাইজ ৫০ MB।');
      final Uint8List bytes = await file.readAsBytes();
      final converted = await PdfToDocumentService.convert(bytes, sourceName: file.name);
      final record = <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': converted.title,
        'content': converted.writerDelta,
        'updated': DateTime.now().toIso8601String(),
        'source': 'pdf_import',
        'sourcePdfName': file.name,
        'conversion': {
          'pageCount': converted.pageCount,
          'imageCount': converted.imageCount,
          'ocrUsed': converted.ocrUsed,
        },
      };
      final documents = await loadDocuments();
      documents.add(record);
      await storeDocuments(documents);
      if (!mounted) return;
      setState(() { sourceName = file.name; sourcePdfBytes = bytes; savedDocument = record; result = converted; busy = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; });
    }
  }


  Future<void> _convertImage() async {
    if (busy) return;
    setState(() { busy = true; error = null; result = null; });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'tif', 'tiff'],
      );
      if (!mounted) return;
      if (file == null) { setState(() => busy = false); return; }
      final length = file.lengthSync() ?? await file.length();
      if (length == null || length == 0) throw const FormatException('ছবির ফাইলটি খালি।');
      if (length > 30 * 1024 * 1024) throw const FormatException('ছবির সর্বোচ্চ সাইজ ৩০ MB।');
      final Uint8List bytes = await file.readAsBytes();
      final converted = await PdfToDocumentService.convertImage(bytes, sourceName: file.name);
      final record = <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': converted.title,
        'content': converted.writerDelta,
        'updated': DateTime.now().toIso8601String(),
        'source': 'image_import',
        'sourceImageName': file.name,
        'conversion': {'pageCount': converted.pageCount, 'imageCount': 1, 'ocrUsed': true},
      };
      final documents = await loadDocuments();
      documents.add(record);
      await storeDocuments(documents);
      if (!mounted) return;
      setState(() {
        sourceName = file.name;
        sourcePdfBytes = null;
        savedDocument = record;
        result = converted;
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; });
    }
  }

  Future<void> _saveDocx() async {
    final value = result;
    if (value == null || busy) return;
    setState(() => busy = true);
    try {
      final name = value.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final saved = await FilePicker.saveFile(
        dialogTitle: widget.isBangla ? 'Word ডকুমেন্ট সংরক্ষণ করুন' : 'Save Word document',
        fileName: '${name.isEmpty ? 'Converted Document' : name}.docx',
        bytes: value.docxBytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved == null
            ? (widget.isBangla ? 'সংরক্ষণ বাতিল হয়েছে।' : 'Save cancelled.')
            : (widget.isBangla ? 'DOCX সংরক্ষণ হয়েছে।' : 'DOCX saved.')),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DOCX save failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openPdfPreview() async {
    final bytes = sourcePdfBytes;
    if (bytes == null || sourceName == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfReaderScreen(
          bytes: bytes,
          fileName: sourceName!,
          isBangla: widget.isBangla,
        ),
      ),
    );
  }

  Future<void> _openWriter() async {
    final value = result;
    if (value == null) return;
    // Open the exact record created by this conversion. Matching by filename
    // could accidentally open an older document with the same filename.
    final doc = savedDocument ??
        <String, dynamic>{
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': value.title,
          'content': value.writerDelta,
        };
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WriterEditorScreen(document: doc, isBangla: widget.isBangla)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;
    return Scaffold(
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        backgroundColor: OFFYNEXTheme.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(bn ? 'PDF থেকে Document' : 'PDF to Document', style: const TextStyle(color: OFFYNEXTheme.ink, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: OFFYNEXTheme.border)), child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.picture_as_pdf, size: 42, color: Color(0xFFE34B50)),
              const SizedBox(height: 12),
              Text(
                bn ? 'PDF-এর লেখা, ছবি ও শনাক্তযোগ্য টেবিল থেকে সম্পাদনাযোগ্য ডকুমেন্ট তৈরি করুন।'
                   : 'Create an editable document from PDF text, images and detected tables.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(bn
                  ? 'স্ক্যান করা PDF হলে বাংলা ও ইংরেজি OCR চেষ্টা করা হবে।'
                  : 'Bengali and English OCR is attempted for scanned PDFs.'),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  onPressed: busy ? null : _convert,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(bn ? 'PDF নির্বাচন করুন' : 'Choose PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : _convertImage,
                  icon: const Icon(Icons.image_search),
                  label: Text(bn ? 'ছবি থেকে Document' : 'Image to Document'),
                ),
              ]),
            ]),
          )),
          if (busy) const Padding(
            padding: EdgeInsets.all(24),
            child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('PDF বিশ্লেষণ ও রূপান্তর হচ্ছে…'),
            ]),
          ),
          if (error != null) Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(padding: const EdgeInsets.all(14), child: Text(error!)),
          ),
          if (result != null) Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: OFFYNEXTheme.border)), child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(bn ? 'রূপান্তর সম্পন্ন' : 'Conversion complete',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ]),
              const SizedBox(height: 8),
              Text(sourceName ?? ''),
              Text('${bn ? 'পৃষ্ঠা' : 'Pages'}: ${result!.pageCount}  •  ${bn ? 'ছবি' : 'Images'}: ${result!.imageCount}'),
              Text(result!.ocrUsed
                  ? (bn ? 'বাংলা/ইংরেজি OCR ব্যবহার হয়েছে' : 'Bengali/English OCR used')
                  : (bn ? 'PDF-এর বিদ্যমান লেখা ব্যবহার হয়েছে' : 'Embedded PDF text used')),
              if (result!.ocrWarning != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(result!.ocrWarning!, style: const TextStyle(color: Colors.deepOrange)),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (sourcePdfBytes != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : _openPdfPreview,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(bn ? 'PDF দেখুন' : 'View PDF'),
                  ),
                FilledButton.icon(
                  onPressed: busy ? null : _openWriter,
                  icon: const Icon(Icons.edit_document),
                  label: Text(bn ? 'Writer-এ খুলুন' : 'Open in Writer'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : _saveDocx,
                  icon: const Icon(Icons.download),
                  label: const Text('Save DOCX'),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                bn ? 'মূল PDF অপরিবর্তিত থাকবে। জটিল কলাম বা টেবিলের বিন্যাস Writer-এ যাচাই করুন।'
                   : 'The original PDF remains unchanged. Review complex columns and tables in Writer.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          )),
        ],
      ),
    );
  }
}
