import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'slides_pdf_export_service.dart';
import 'slides_preview_screen.dart';
import 'scan_document_service.dart';
import 'database_rows_dialog.dart';
import 'database_field_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'portable_workspace_backup_service.dart';

import '../pdf/pdf_to_document_service.dart';
import '../pdf/pdf_reader_screen.dart';
import 'workspace_backup_codec.dart';
import 'workspace_record_codec.dart';
import 'forms_response_csv_codec.dart';
import 'forms_question_codec.dart';
import '../writer/writer_screen.dart';
import '../../theme/offynex_theme.dart';

/// Offline-first workspaces shared by Slides, Fonts, AI, Cloud, Forms,
/// Scan and Database. Each module stores its own versioned records.
class OfficeWorkspaceScreen extends StatefulWidget {
  const OfficeWorkspaceScreen({
    super.key,
    required this.module,
    required this.isBangla,
  });

  final String module;
  final bool isBangla;

  @override
  State<OfficeWorkspaceScreen> createState() => _OfficeWorkspaceScreenState();
}

class _OfficeWorkspaceScreenState extends State<OfficeWorkspaceScreen> {
  static const _modules = <String, (String, String, IconData)>{
    'Slides': ('স্লাইডস', 'Presentations', Icons.slideshow_rounded),
    'Fonts': ('ফন্টস', 'Font library', Icons.font_download_rounded),
    'AI Assistant': ('এআই সহকারী', 'AI Assistant', Icons.auto_awesome_rounded),
    'Cloud': ('ক্লাউড', 'Backup & Sync', Icons.cloud_rounded),
    'Forms': ('ফর্মস', 'Forms', Icons.dynamic_form_rounded),
    'Scan': ('স্ক্যান', 'Document Scan', Icons.document_scanner_rounded),
    'Database': ('ডেটাবেস', 'Database', Icons.storage_rounded),
  };

  bool get _bn => widget.isBangla;
  String get _key => 'offynex_workspace_${widget.module.toLowerCase().replaceAll(' ', '_')}_v1';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _busy = false;
  bool _workspaceDataBlocked = false;
  String? _workspaceRecoveryKey;
  String _searchQuery = '';
  final _backupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _backupController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    var loaded = <Map<String, dynamic>>[];
    var dataBlocked = false;
    String? recoveryKey;
    String? recoveryMessage;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          throw const FormatException('Workspace record root must be a list.');
        }
        final ids = <String>{};
        loaded = decoded.map((item) {
          if (item is! Map) {
            throw const FormatException('Workspace record must be an object.');
          }
          final record = Map<String, dynamic>.from(item);
          final id = record['id'];
          final title = record['title'];
          final content = record['content'];
          final updatedAt = record['updatedAt'];
          if (id is! String ||
              id.trim().isEmpty ||
              !ids.add(id) ||
              title is! String ||
              title.trim().isEmpty ||
              content is! String ||
              updatedAt is! String ||
              DateTime.tryParse(updatedAt) == null) {
            throw const FormatException('Workspace contains an invalid or duplicate record.');
          }
          return record;
        }).toList(growable: false);
      } catch (error) {
        dataBlocked = true;
        final candidateKey =
            '${_key}_recovery_${DateTime.now().microsecondsSinceEpoch}';
        final preserved = await prefs.setString(candidateKey, raw);
        if (preserved) recoveryKey = candidateKey;
        recoveryMessage = preserved
            ? (_bn
                ? 'এই মডিউলের ডেটা যাচাই করা যায়নি। মূল ডেটা অপরিবর্তিত এবং Recovery Copy রাখা হয়েছে: $candidateKey'
                : 'Workspace data could not be validated. Original data is unchanged and a recovery copy was saved: $candidateKey')
            : (_bn
                ? 'ডেটা যাচাই করা যায়নি এবং Recovery Copy সংরক্ষণ ব্যর্থ। মূল ডেটা সুরক্ষার জন্য সম্পাদনা বন্ধ রাখা হয়েছে: $error'
                : 'Workspace data could not be validated and the recovery copy could not be saved. Editing is blocked to protect the original data: $error');
        loaded = <Map<String, dynamic>>[];
      }
    }
    if (!mounted) return;
    setState(() {
      _items = loaded;
      _workspaceDataBlocked = dataBlocked;
      _workspaceRecoveryKey = recoveryKey;
      _loading = false;
    });
    if (recoveryMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(recoveryMessage), duration: const Duration(seconds: 10)),
      );
    }
  }

  Future<void> _save([List<Map<String, dynamic>>? candidate]) async {
    if (_workspaceDataBlocked) {
      throw StateError('Workspace editing is blocked because the original data is damaged.');
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(candidate ?? _items));
    if (!saved) throw StateError('Workspace data could not be saved.');
  }

  Future<void> _editItem({Map<String, dynamic>? item}) async {
    if (_workspaceDataBlocked) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _WorkspaceItemDialog(
        isBangla: _bn,
        title: item?['title']?.toString() ?? '',
        content: item?['content']?.toString() ?? '',
        contentLabel: _contentLabel,
        isNew: item == null,
      ),
    );
    if (result == null || result['title']!.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final updated = _items.map((entry) => Map<String, dynamic>.from(entry)).toList();
    if (item == null) {
      updated.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': result['title']!.trim(),
        'content': result['content'] ?? '',
        'updatedAt': now,
      });
    } else {
      final index = updated.indexWhere((entry) => entry['id'] == item['id']);
      if (index < 0) return;
      updated[index] = {
        ...updated[index],
        'title': result['title']!.trim(),
        'content': result['content'] ?? '',
        'updatedAt': now,
      };
    }
    await _save(updated);
    if (mounted) setState(() => _items = updated);
  }

  Future<void> _exportRecords() async {
    if (_workspaceDataBlocked) return;
    try {
      final json = WorkspaceRecordCodec.encode(widget.module, _items);
      final safeModule = widget.module.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-$safeModule-records.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        dialogTitle: _bn ? 'ডেটা Export সংরক্ষণ' : 'Save workspace export',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'ডেটা Export সম্পন্ন হয়েছে।' : 'Workspace export completed.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_bn ? 'Export ব্যর্থ' : 'Export failed'}: $e'),
        ));
      }
    }
  }

  Future<void> _importRecords() async {
    if (_workspaceDataBlocked) return;
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('Workspace file must be between 1 byte and 10 MB.');
      }
      final imported = WorkspaceRecordCodec.decode(
        utf8.decode(bytes, allowMalformed: false),
        expectedModule: widget.module,
      );
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_bn ? 'ডেটা Import করবেন?' : 'Import workspace data?'),
          content: Text(_bn
              ? '${imported.length}টি আইটেম পাওয়া গেছে। একই ID আগে থাকলে পুরোনো আইটেম অপরিবর্তিত থাকবে; নতুনগুলো যোগ হবে।'
              : '${imported.length} records found. Existing IDs will be kept unchanged; only new records will be added.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_bn ? 'বাতিল' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_bn ? 'Import' : 'Import'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      final existingIds = _items.map((item) => item['id']?.toString()).toSet();
      final additions = imported.where((item) => !existingIds.contains(item['id'])).toList();
      if (additions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'নতুন কোনো আইটেম পাওয়া যায়নি।' : 'No new records to import.'),
        ));
        return;
      }
      final updated = [...additions, ..._items];
      await _save(updated);
      if (mounted) setState(() => _items = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? '${additions.length}টি নতুন আইটেম Import হয়েছে।' : '${additions.length} new records imported.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_bn ? 'Import ব্যর্থ' : 'Import failed'}: $e'),
        ));
      }
    }
  }

  String get _contentLabel {
    switch (widget.module) {
      case 'Slides': return _bn ? 'স্লাইডের বিষয়বস্তু (প্রতি স্লাইড নতুন লাইনে)' : 'Slide content (one slide per line)';
      case 'Forms': return _bn ? 'প্রশ্নগুলো (প্রতি লাইনে একটি)' : 'Questions (one per line)';
      case 'Database': return _bn ? 'ফিল্ড / কলাম (কমা দিয়ে আলাদা)' : 'Fields / columns (comma separated)';
      case 'Fonts': return _bn ? 'ফন্টের বিবরণ / নোট' : 'Font details / notes';
      case 'AI Assistant': return _bn ? 'আপনার লেখা বা নির্দেশনা' : 'Your text or instruction';
      default: return _bn ? 'বিবরণ' : 'Description';
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    if (_workspaceDataBlocked) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_bn ? 'মুছে ফেলবেন?' : 'Delete item?'),
        content: Text(item['title']?.toString() ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_bn ? 'না' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_bn ? 'মুছুন' : 'Delete')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final updated = _items.where((entry) => entry['id'] != item['id']).toList();
    await _save(updated);
    if (mounted) {
      setState(() => _items = updated);
    }
    final path = item['scanPdfPath'];
    if (widget.module == 'Scan' && path is String && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text((_bn ? 'তালিকা থেকে সরানো হয়েছে; PDF মুছতে পারেনি: ' : 'Removed from list; PDF delete failed: ') + error.toString()),
          ));
        }
      }
    }
  }

  Future<void> _reviewScanText(Map<String, dynamic> item) async {
    if (_workspaceDataBlocked) return;
    final controller = TextEditingController(text: item['content']?.toString() ?? '');
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_bn ? 'OCR লেখা যাচাই ও সংশোধন' : 'Review and correct OCR text'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 6,
            maxLines: 14,
            maxLength: 100000,
            decoration: InputDecoration(
              hintText: _bn ? 'স্ক্যান থেকে পাওয়া লেখা সংশোধন করুন' : 'Correct the recognized scan text',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_bn ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_bn ? 'সংরক্ষণ' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || !mounted) return;
    try {
      final writerId = item['writerDocumentId']?.toString().trim().isNotEmpty == true
          ? item['writerDocumentId'].toString()
          : DateTime.now().microsecondsSinceEpoch.toString();
      final updatedItem = <String, dynamic>{
        ...item,
        'content': edited,
        'updatedAt': DateTime.now().toIso8601String(),
        if (edited.trim().isNotEmpty) 'writerDocumentId': writerId,
      };
      final updatedItems = _items
          .map((entry) => entry['id'] == item['id'] ? updatedItem : entry)
          .toList(growable: false);
      await _save(updatedItems);
      if (!mounted) return;
      setState(() => _items = updatedItems);

      final documents = await loadDocuments();
      final index = documents.indexWhere((document) => document['id']?.toString() == writerId);
      final writerRecord = <String, dynamic>{
        if (index >= 0) ...documents[index],
        'id': writerId,
        'title': updatedItem['title']?.toString() ?? 'Scanned document',
        'content': PdfToDocumentService.plainTextToDelta(edited),
        'updated': DateTime.now().toIso8601String(),
        'source': 'native_document_scan',
        'scanPdfPath': updatedItem['scanPdfPath'],
      };
      if (index >= 0) {
        documents[index] = writerRecord;
      } else if (edited.trim().isNotEmpty) {
        documents.add(writerRecord);
      }
      await storeDocuments(documents);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_bn ? 'OCR লেখা সংশোধন করে সংরক্ষণ হয়েছে।' : 'Corrected OCR text saved.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((_bn ? 'OCR লেখা সংরক্ষণ ব্যর্থ: ' : 'Could not save OCR text: ') + error.toString())),
        );
      }
    }
  }

  Future<void> _openScanPdf(Map<String, dynamic> item) async {
    final path = item['scanPdfPath'];
    if (path is! String || path.isEmpty) return;
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw const FileSystemException('Saved scan PDF was not found.');
      }
      final bytes = Uint8List.fromList(await file.readAsBytes());
      PdfToDocumentService.validatePdfBytes(bytes);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfReaderScreen(
            bytes: bytes,
            fileName: file.uri.pathSegments.isEmpty
                ? 'OFFYNEXBD-Scan.pdf'
                : file.uri.pathSegments.last,
            isBangla: _bn,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((_bn ? 'স্ক্যান PDF খোলা যায়নি: ' : 'Could not open scan PDF: ') + error.toString())),
        );
      }
    }
  }

  Future<void> _shareScan(Map<String, dynamic> item) async {
    final path = item['scanPdfPath'];
    if (path is! String || path.isEmpty) return;
    try {
      final file = File(path);
      if (!await file.exists()) throw const FileSystemException('Saved scan PDF was not found.');
      await Printing.sharePdf(
        bytes: Uint8List.fromList(await file.readAsBytes()),
        filename: '${item['title']?.toString().trim().isNotEmpty == true ? item['title'].toString().trim() : 'OFFYNEXBD-Scan'}.pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((_bn ? 'PDF শেয়ার ব্যর্থ: ' : 'PDF share failed: ') + error.toString()),
        ));
      }
    }
  }

  Future<void> _scanImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (Platform.isAndroid) {
        final captured = await ScanDocumentService.captureAndroid();
        if (captured == null) return;
        final writerDocumentId = captured.recognizedText.trim().isEmpty
            ? null
            : DateTime.now().microsecondsSinceEpoch.toString();
        final scanRecord = <String, dynamic>{
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'writerDocumentId': ?writerDocumentId,
          'title': captured.fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
          'content': captured.recognizedText,
          'updatedAt': DateTime.now().toIso8601String(),
          'source': 'native_document_scan',
          'scanPdfPath': captured.pdfPath,
          'pageCount': captured.pageCount,
          'ocrLanguage': 'ben+eng',
        };
        final updatedScans = [scanRecord, ..._items];
        await _save(updatedScans);
        if (!mounted) return;
        setState(() => _items = updatedScans);
        if (captured.recognizedText.trim().isNotEmpty) {
          final documents = await loadDocuments();
          documents.add({
            'id': writerDocumentId!,

            'title': scanRecord['title'],
            'content': PdfToDocumentService.plainTextToDelta(captured.recognizedText),
            'updated': DateTime.now().toIso8601String(),
            'source': 'native_document_scan',
            'scanPdfPath': captured.pdfPath,
            'pageCount': captured.pageCount,
            'ocrLanguage': 'ben+eng',
          });
          await storeDocuments(documents);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn
              ? '${captured.pageCount} পৃষ্ঠা স্ক্যান PDF হিসেবে সংরক্ষিত হয়েছে। ${captured.recognizedText.trim().isEmpty ? 'OCR লেখা পাওয়া যায়নি।' : 'লেখা Writer-এও সংরক্ষিত হয়েছে।'}'
              : '${captured.pageCount} pages saved as a scanned PDF. ${captured.recognizedText.trim().isEmpty ? 'No OCR text was detected.' : 'Recognized text was also saved to Writer.'}'),
          action: SnackBarAction(
            label: _bn ? 'PDF শেয়ার' : 'Share PDF',
            onPressed: () => _shareScan(scanRecord),
          ),
          duration: const Duration(seconds: 8),
        ));
        return;
      }

      // Keep the existing gallery OCR route on platforms without the Android scanner.
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'tif', 'tiff'],
      );
      if (file == null) return;
      final size = file.lengthSync() ?? await file.length();
      if (size == null || size == 0 || size > 30 * 1024 * 1024) {
        throw FormatException(_bn ? 'ছবির সাইজ ১ বাইট থেকে ৩০ MB হতে হবে।' : 'Image must be between 1 byte and 30 MB.');
      }
      final Uint8List bytes = await file.readAsBytes();
      final converted = await PdfToDocumentService.convertImage(bytes, sourceName: file.name);
      final documents = await loadDocuments();
      documents.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': converted.title,
        'content': converted.writerDelta,
        'updated': DateTime.now().toIso8601String(),
        'source': 'scan_ocr',
        'sourceImageName': file.name,
        'conversion': {'pageCount': converted.pageCount, 'ocrUsed': true},
      });
      await storeDocuments(documents);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn ? 'স্ক্যানের লেখা Writer-এ সংরক্ষিত হয়েছে।' : 'Scanned text saved to Writer.'),
        action: SnackBarAction(
          label: _bn ? 'Writer খুলুন' : 'Open Writer',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WriterScreen(isBangla: _bn))),
        ),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('offynex_')).toList()..sort();
    final data = <String, dynamic>{};
    for (final key in keys) {
      // Pass every OFFYNEXBD preference to the strict backup codec.
      // Never silently omit an unfamiliar value and produce an incomplete backup.
      data[key] = prefs.get(key);
    }
    _backupController.text = WorkspaceBackupCodec.encode(data);
    if (mounted) setState(() {});
  }

  Future<void> _exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('offynex_')).toList()..sort();
      final data = <String, Object?>{for (final key in keys) key: prefs.get(key)};
      final support = await getApplicationSupportDirectory();
      final documents = await getApplicationDocumentsDirectory();
      final bytes = await PortableWorkspaceBackupService.exportArchive(
        data,
        writerImageDirectory: Directory('${support.path}/offynexbd_images'),
        scanDirectory: Directory('${documents.path}/OFFYNEXBD/Scans'),
      );
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-Portable-Backup.offynex',
        bytes: bytes,
        mimeType: 'application/zip',
        dialogTitle: _bn ? 'সম্পূর্ণ ব্যাকআপ সংরক্ষণ' : 'Save portable backup',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'ডকুমেন্ট, স্ক্যান ও অ্যাপ ডেটাসহ ব্যাকআপ সংরক্ষিত হয়েছে।' : 'Backup saved with documents, scans and app data.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_bn ? 'ব্যাকআপ সংরক্ষণ ব্যর্থ' : 'Backup export failed'}: $e'),
        ));
      }
    }
  }

  Future<void> _importBackupFile() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['offynex', 'zip', 'json'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty || bytes.length > WorkspaceBackupCodec.maxBackupBytes) {
        throw const FormatException('Backup file must be between 1 byte and 25 MB.');
      }
      Map<String, Object?> data;
      if (picked.extension?.toLowerCase() == 'json') {
        final source = utf8.decode(bytes, allowMalformed: false);
        data = WorkspaceBackupCodec.decode(source);
        _backupController.text = source;
      } else {
        final support = await getApplicationSupportDirectory();
        final documents = await getApplicationDocumentsDirectory();
        data = await PortableWorkspaceBackupService.importArchive(
          bytes,
          writerImageDirectory: Directory('${support.path}/offynexbd_images'),
          scanDirectory: Directory('${documents.path}/OFFYNEXBD/Scans'),
        );
      }
      if (!mounted) return;
      await _restoreBackupData(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_bn ? 'ব্যাকআপ ফাইল পড়া যায়নি' : 'Could not import backup file'}: $e'),
        ));
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final data = WorkspaceBackupCodec.decode(_backupController.text);
      await _restoreBackupData(data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_bn ? 'ব্যাকআপ ত্রুটি' : 'Backup error'}: $e')));
    }
  }

  Future<void> _restoreBackupData(Map<String, Object?> data) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_bn ? 'ব্যাকআপ পুনরুদ্ধার?' : 'Restore backup?'),
        content: Text(_bn
            ? 'শুধু OFFYNEXBD-এর সংরক্ষিত ডেটা পুনরুদ্ধার হবে। একই কী থাকলে সেটি প্রতিস্থাপিত হবে।'
            : 'Only OFFYNEXBD app data will be restored. Matching keys will be replaced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_bn ? 'বাতিল' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_bn ? 'পুনরুদ্ধার' : 'Restore')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await WorkspaceBackupRestore.restore(prefs, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'লোকাল ব্যাকআপ পুনরুদ্ধার হয়েছে।' : 'Local backup restored.'),
        ));
        await _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_bn ? 'ব্যাকআপ ত্রুটি' : 'Backup error'}: $e')));
    }
  }

  Widget _cloudPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_bn ? 'লোকাল ব্যাকআপ / পুনরুদ্ধার' : 'Local backup / restore',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_bn
            ? 'এটি ডিভাইসের OFFYNEXBD ডেটার JSON ব্যাকআপ। অনলাইন Cloud Sync এখনো সংযুক্ত নয়।'
            : 'This is a JSON backup of OFFYNEXBD data on this device. Online Cloud Sync is not connected yet.'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _createBackup,
            icon: const Icon(Icons.backup),
            label: Text(_bn ? 'ব্যাকআপ তৈরি' : 'Create backup'),
          ),
          OutlinedButton.icon(
            onPressed: _exportBackup,
            icon: const Icon(Icons.save_alt),
            label: Text(_bn ? 'সম্পূর্ণ ব্যাকআপ (.offynex)' : 'Portable backup (.offynex)'),
          ),
          OutlinedButton.icon(
            onPressed: _importBackupFile,
            icon: const Icon(Icons.folder_open),
            label: Text(_bn ? 'ব্যাকআপ ফাইল খুলুন' : 'Import backup file'),
          ),
        ]),
        TextField(
          controller: _backupController,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: _bn ? 'ব্যাকআপ JSON এখানে আসবে বা পেস্ট করুন' : 'Backup JSON appears here or paste it',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _backupController.text.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: _backupController.text)),
            icon: const Icon(Icons.copy), label: Text(_bn ? 'কপি' : 'Copy'),
          ),
          FilledButton.icon(
            onPressed: _backupController.text.trim().isEmpty ? null : _restoreBackup,
            icon: const Icon(Icons.restore), label: Text(_bn ? 'পুনরুদ্ধার' : 'Restore'),
          ),
        ]),
      ]),
    ),
  );

  Widget _moduleHelp() {
    final help = switch (widget.module) {
      'Slides' => _bn
          ? 'প্রতি লাইনে একটি স্লাইডের লেখা দিন। Export Slides PDF দিয়ে প্রতিটি স্লাইড আলাদা Landscape PDF পৃষ্ঠায় সংরক্ষণ করুন। PPTX ও পূর্ণ Slideshow renderer এখনো বাকি।'
          : 'Enter one slide per line. Export Slides PDF saves each slide on a separate landscape PDF page. PPTX and the full slideshow renderer are still pending.',
      'Fonts' => _bn
          ? 'এখানে ফন্টের তালিকা ও নোট রাখা যায়। প্রকৃত TTF/OTF ইনস্টল ও সব এডিটরে প্রয়োগ এখনো যুক্ত হয়নি।'
          : 'Keep a font catalogue and notes here. Actual TTF/OTF installation and editor-wide activation are not connected yet.',
      'AI Assistant' => _bn
          ? 'বাংলা/ইংরেজি নির্দেশনা ও কাজের খসড়া সংরক্ষণ করুন। প্রকৃত AI উত্তর পেতে নিরাপদ AI service connection প্রয়োজন; এখনো সংযুক্ত নয়।'
          : 'Save Bangla/English prompts and drafts. A secure AI service connection is required for generated answers and is not connected yet.',
      'Forms' => _bn
          ? 'প্রতি লাইনে একটি প্রশ্ন লিখুন। সাধারণ লেখা optional short-answer। প্রয়োজন হলে `required text: নাম`, `email: ইমেইল`, `number: বয়স`, `date: তারিখ`, অথবা `choice: বিভাগ | বিকল্প ১ | বিকল্প ২` ব্যবহার করুন। উত্তর স্থানীয়ভাবে সংরক্ষিত হবে; অনলাইন শেয়ারিং এখনো যুক্ত হয়নি।'
          : 'Enter one question per line. Plain lines remain optional short answers. You can use `required text: Name`, `email: Email`, `number: Age`, `date: Date`, or `choice: Department | Sales | Support`. Responses are saved locally; online sharing is not connected yet.',
      'Database' => _bn
          ? 'পুরোনো কমা-আলাদা Field-ও চলবে। Typed Field: `required Name:text, Age:number, Email:email, Joined:date, Department:choice|Sales|Support`। Row ও CSV Import-এ Number, Email, Date, Choice যাচাই হবে। SQL/relational query engine এখনো যুক্ত হয়নি।'
          : 'Legacy comma-separated fields still work. Typed fields: `required Name:text, Age:number, Email:email, Joined:date, Department:choice|Sales|Support`. Row editing and CSV import validate number, email, date and choice values. A SQL/relational query engine is not connected yet.',
      _ => '',
    };
    if (help.isEmpty) return const SizedBox.shrink();
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(help, style: Theme.of(context).textTheme.bodyMedium),
    ));
  }

  Future<void> _manageDatabaseRows(Map<String, dynamic> table) async {
    late final List<DatabaseField> schema;
    try {
      schema = DatabaseFieldCodec.parse(table['content']?.toString() ?? '');
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_bn ? 'Database Field সংজ্ঞা ভুল' : 'Invalid database field definition'}: ${error.message}'),
      ));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    const storageKey = 'offynex_database_rows_v1';
    final raw = prefs.getString(storageKey);
    final allRows = <String, dynamic>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException('Database store must be an object.');
        }
        final validated = <String, dynamic>{};
        for (final entry in decoded.entries) {
          if (entry.key is! String || entry.value is! List) {
            throw const FormatException('Invalid database table row collection.');
          }
          final rowIds = <String>{};
          final rows = <Map<String, dynamic>>[];
          for (final item in entry.value as List) {
            if (item is! Map) {
              throw const FormatException('Database row must be an object.');
            }
            final row = Map<String, dynamic>.from(item);
            final id = row['id'];
            final values = row['values'];
            if (id is! String || id.trim().isEmpty || !rowIds.add(id) || values is! Map) {
              throw const FormatException('Database row has an invalid ID or values.');
            }
            final safeValues = <String, String>{};
            for (final value in values.entries) {
              if (value.key is! String || value.value is! String) {
                throw const FormatException('Database row fields must contain text values.');
              }
              safeValues[value.key as String] = value.value as String;
            }
            rows.add({'id': id, 'values': safeValues});
          }
          validated[entry.key as String] = rows;
        }
        allRows.addAll(validated);
      } catch (error) {
        final recoveryKey =
            'offynex_database_rows_recovery_${DateTime.now().microsecondsSinceEpoch}';
        final preserved = await prefs.setString(recoveryKey, raw);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(preserved
              ? (_bn
                  ? 'ক্ষতিগ্রস্ত Database Rows-এর Recovery Copy রাখা হয়েছে। মূল ডেটা অপরিবর্তিত আছে; নিরাপদে পড়া না গেলে সম্পাদনা বন্ধ রাখা হয়েছে।'
                  : 'Damaged database rows were copied for recovery. Original data is unchanged; editing was stopped.')
              : (_bn
                  ? 'Recovery Copy সংরক্ষণ ব্যর্থ হয়েছে। মূল ডেটা অপরিবর্তিত রাখা হয়েছে।'
                  : 'Recovery copy failed. Original data was left unchanged.')),
        ));
        return;
      }
    }
    if (!mounted) return;
    final tableId = table['id']?.toString() ?? '';
    final existing = allRows[tableId];
    final initialRows = existing is List
        ? existing.map((row) => Map<String, dynamic>.from(row as Map)).toList()
        : <Map<String, dynamic>>[];
    final updated = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => DatabaseRowsDialog(
        isBangla: _bn,
        tableName: table['title']?.toString() ?? '',
        schema: schema,
        initialRows: initialRows,
      ),
    );
    if (updated == null || !mounted) return;
    allRows[tableId] = updated;
    final saved = await prefs.setString(storageKey, jsonEncode(allRows));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved
          ? (_bn ? 'টেবিলের ${updated.length}টি Row সংরক্ষণ হয়েছে।' : '${updated.length} table rows saved.')
          : (_bn ? 'Database Row সংরক্ষণ হয়নি।' : 'Database rows could not be saved.')),
    ));
  }

  Future<void> _previewSlides(Map<String, dynamic> presentation) async {
    final slides = (presentation['content']?.toString() ?? '')
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (slides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn ? 'প্রিভিউয়ের আগে স্লাইডের লেখা যোগ করুন।' : 'Add slide content before opening the preview.'),
      ));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SlidesPreviewScreen(
          title: presentation['title']?.toString() ?? '',
          slides: slides,
          isBangla: _bn,
        ),
      ),
    );
  }

  Future<void> _exportSlidePdf(Map<String, dynamic> slide) async {
    try {
      final title = slide['title']?.toString().trim() ?? '';
      final slideTexts = (slide['content']?.toString() ?? '')
          .split(RegExp(r'\r?\n'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final bytes = await SlidesPdfExportService.build(
        title: title,
        slideTexts: slideTexts,
      );
      final safeName = (title.isEmpty ? 'OFFYNEXBD-Slides' : title)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final saved = await FilePicker.saveFile(
        fileName: '$safeName.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: _bn ? 'স্লাইড PDF সংরক্ষণ' : 'Export slides as PDF',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'স্লাইড PDF তৈরি হয়েছে।' : 'Slides PDF exported.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_bn ? 'PDF Export ব্যর্থ' : 'PDF export failed'}: $error'),
        ));
      }
    }
  }

  Future<List<Map<String, dynamic>>?> _readFormResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_forms_responses_v1');
    if (raw == null) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Forms response archive must be a list.');
      }
      final ids = <String>{};
      return decoded.map((item) {
        if (item is! Map) {
          throw const FormatException('Forms response entry must be an object.');
        }
        final response = Map<String, dynamic>.from(item);
        final id = response['id'];
        final formId = response['formId'];
        final formTitle = response['formTitle'];
        final submittedAt = response['submittedAt'];
        final answers = response['answers'];
        if (id is! String ||
            id.trim().isEmpty ||
            !ids.add(id) ||
            formId is! String ||
            formId.trim().isEmpty ||
            formTitle is! String ||
            submittedAt is! String ||
            DateTime.tryParse(submittedAt) == null ||
            answers is! List) {
          throw const FormatException('Forms response entry has invalid fields.');
        }
        for (final answer in answers) {
          if (answer is! Map ||
              answer['question'] is! String ||
              answer['answer'] is! String) {
            throw const FormatException('Forms response contains an invalid answer.');
          }
        }
        return response;
      }).toList(growable: true);
    } catch (error) {
      final key =
          'offynex_forms_responses_recovery_${DateTime.now().microsecondsSinceEpoch}';
      var preserved = false;
      try {
        preserved = await prefs.setString(key, raw);
      } catch (_) {
        preserved = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(preserved
              ? (_bn
                  ? 'ফর্মের পুরোনো উত্তর ক্ষতিগ্রস্ত। মূল ডেটা অপরিবর্তিত রেখে Recovery Copy রাখা হয়েছে: $key'
                  : 'The Forms response archive is damaged. Original data is unchanged; a recovery copy was saved: $key')
              : (_bn
                  ? 'ফর্মের উত্তর যাচাই করা যায়নি এবং Recovery Copy সংরক্ষণ ব্যর্থ। মূল ডেটা সুরক্ষায় কাজ বন্ধ রাখা হয়েছে।'
                  : 'Forms responses could not be validated and the recovery copy failed. The operation was stopped to protect the original data.')),
        ));
      }
      return null;
    }
  }

  Future<void> _collectFormResponse(Map<String, dynamic> form) async {
    late final List<Map<String, dynamic>> questions;
    try {
      questions = FormsQuestionCodec.parse(form['content']?.toString() ?? '');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text((_bn ? 'ফর্মের প্রশ্নে সমস্যা: ' : 'Invalid form questions: ') + error.toString()),
      ));
      return;
    }
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn ? 'আগে ফর্মে প্রশ্ন যোগ করুন।' : 'Add questions to this form first.'),
      ));
      return;
    }
    final answers = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (_) => _FormResponseDialog(
        isBangla: _bn,
        formTitle: form['title']?.toString() ?? '',
        questions: questions,
      ),
    );
    if (answers == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final responses = await _readFormResponses();
    if (responses == null) return;
    responses.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'formId': form['id']?.toString() ?? '',
      'formTitle': form['title']?.toString() ?? '',
      'submittedAt': DateTime.now().toIso8601String(),
      'answers': answers,
    });
    final saved = await prefs.setString('offynex_forms_responses_v1', jsonEncode(responses));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved
          ? (_bn ? 'উত্তর সংরক্ষণ হয়েছে।' : 'Response saved locally.')
          : (_bn ? 'উত্তর সংরক্ষণ করা যায়নি।' : 'Could not save response.')),
    ));
  }

  Future<void> _exportFormResponses() async {
    try {
      final decoded = await _readFormResponses();
      if (decoded == null) return;
      if (decoded.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_bn ? 'Export করার মতো কোনো উত্তর নেই।' : 'There are no responses to export.'),
          ));
        }
        return;
      }
      final archive = const JsonEncoder.withIndent('  ').convert({
        'format': 'OFFYNEXBD_FORMS_RESPONSES',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'responses': decoded,
      });
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-Forms-responses.json',
        bytes: Uint8List.fromList(utf8.encode(archive)),
        mimeType: 'application/json',
        dialogTitle: _bn ? 'ফর্মের উত্তর Export' : 'Export form responses',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'ফর্মের উত্তর Export হয়েছে।' : 'Form responses exported.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_bn ? 'Export ব্যর্থ' : 'Export failed'}: $error'),
        ));
      }
    }
  }

  Future<void> _exportFormResponsesCsv() async {
    try {
      final decoded = await _readFormResponses();
      if (decoded == null) return;
      if (decoded.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_bn ? 'Export করার মতো কোনো উত্তর নেই।' : 'There are no responses to export.'),
          ));
        }
        return;
      }
      final csv = FormsResponseCsvCodec.encode(decoded);
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-Forms-responses.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        dialogTitle: _bn ? 'ফর্মের উত্তর CSV Export' : 'Export form responses as CSV',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'ফর্মের উত্তর CSV Export হয়েছে।' : 'Form responses exported as CSV.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_bn ? 'CSV Export ব্যর্থ' : 'CSV export failed'}: $error'),
        ));
      }
    }
  }

  Future<void> _showFormResponses() async {
    final responses = await _readFormResponses();
    if (responses == null || !mounted) return;
    final searchController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = FormsResponseCsvCodec.filter(
              responses,
              searchController.text,
            ).reversed.toList(growable: false);
            final formCount = responses
                .map((response) => response['formId'])
                .whereType<String>()
                .toSet()
                .length;
            return AlertDialog(
              title: Text(_bn ? 'জমা দেওয়া উত্তর' : 'Form responses'),
              content: SizedBox(
                width: 520,
                height: MediaQuery.sizeOf(context).height * 0.58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _bn
                          ? 'মোট উত্তর: ${responses.length}  •  ফর্ম: $formCount'
                          : 'Responses: ${responses.length}  •  Forms: $formCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: _bn
                            ? 'ফর্ম, প্রশ্ন বা উত্তর খুঁজুন'
                            : 'Search forms, questions or answers',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: responses.isEmpty
                          ? Center(
                              child: Text(_bn
                                  ? 'এখনো কোনো উত্তর জমা হয়নি।'
                                  : 'No responses yet.'),
                            )
                          : filtered.isEmpty
                              ? Center(
                                  child: Text(_bn
                                      ? 'কোনো মিল পাওয়া যায়নি।'
                                      : 'No matching responses.'),
                                )
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final response = filtered[index];
                                    final answers = response['answers'] is List
                                        ? response['answers'] as List
                                        : const [];
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              response['formTitle']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            for (final answer in answers)
                                              if (answer is Map)
                                                Text(
                                                  '${answer['question'] ?? ''}: ${answer['answer'] ?? ''}',
                                                ),
                                            Text(
                                              response['submittedAt']?.toString() ?? '',
                                              style: Theme.of(context)
                                                  .textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    if (searchController.text.trim().isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _bn
                              ? '${filtered.length}টি উত্তর পাওয়া গেছে'
                              : '${filtered.length} matching responses',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _exportFormResponses,
                  child: const Text('Export JSON'),
                ),
                TextButton(
                  onPressed: _exportFormResponsesCsv,
                  child: const Text('Export CSV'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_bn ? 'বন্ধ' : 'Close'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = _modules[widget.module]!;
    final title = _bn ? module.$1 : module.$2;
    final query = _searchQuery.trim().toLowerCase();
    final visibleItems = _items.where((item) {
      if (query.isEmpty) return true;
      final title = item['title']?.toString().toLowerCase() ?? '';
      final content = item['content']?.toString().toLowerCase() ?? '';
      return title.contains(query) || content.contains(query);
    }).toList(growable: false);
    return Scaffold(
      floatingActionButtonLocation: widget.module == 'Database'
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        backgroundColor: OFFYNEXTheme.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(color: OFFYNEXTheme.ink, fontWeight: FontWeight.w800)),
        // Creation is exposed only by the floating action button below.
        // Keeping a single entry point avoids duplicate Create commands.
        actions: const [],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: OFFYNEXTheme.border)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(color: OFFYNEXTheme.blueSoft, borderRadius: BorderRadius.circular(17)),
                        child: Icon(module.$3, size: 30, color: OFFYNEXTheme.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(color: OFFYNEXTheme.ink, fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(_bn ? 'অফলাইন-প্রথম কর্মক্ষেত্র' : 'Offline-first workspace', style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 12)),
                      ])),
                    ]),
                  ),
                ),
                _moduleHelp(),
                if (_workspaceDataBlocked)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _bn
                                ? 'মডিউলের ডেটা ক্ষতিগ্রস্ত বা অবৈধ। মূল ডেটা সুরক্ষার জন্য সম্পাদনা ও Import বন্ধ রাখা হয়েছে।'
                                : 'Workspace records are damaged or invalid. Editing and importing are disabled to protect the original data.',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (_workspaceRecoveryKey != null) ...[
                            const SizedBox(height: 6),
                            SelectableText(
                              '${_bn ? 'Recovery Copy' : 'Recovery copy'}: $_workspaceRecoveryKey',
                            ),
                          ] else
                            Text(
                              _bn
                                  ? 'Recovery Copy সংরক্ষণ করা যায়নি; মূল ডেটা অপরিবর্তিত রাখা হয়েছে।'
                                  : 'The recovery copy could not be saved; the original data has been left unchanged.',
                            ),
                        ],
                      ),
                    ),
                  ),
                if (widget.module == 'Scan')
                  FilledButton.icon(
                    onPressed: _busy ? null : _scanImage,
                    icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.document_scanner),
                    label: Text(_busy ? (_bn ? 'স্ক্যান হচ্ছে…' : 'Scanning…') : (_bn ? 'ছবি নির্বাচন করে OCR স্ক্যান' : 'Select image and OCR scan')),
                  ),
                if (widget.module == 'Cloud') _cloudPanel(),
                if (widget.module == 'AI Assistant')
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_bn
                          ? 'দ্রুত নির্দেশনা: “এই লেখাটি সংক্ষিপ্ত করো”, “ইংরেজিতে অনুবাদ করো”, “একটি অফিস চিঠির খসড়া তৈরি করো”। নির্দেশনা সংরক্ষণ করে পরে AI সংযোগে ব্যবহার করতে পারবেন।'
                          : 'Prompt ideas: “Summarize this text”, “Translate to Bengali”, “Draft a formal office letter”. Save prompts for use when AI is connected.'),
                    ),
                  ),
                if (widget.module != 'Cloud' && !_workspaceDataBlocked) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text(_bn ? 'সংরক্ষিত আইটেম' : 'Saved items',
                        style: Theme.of(context).textTheme.titleMedium)),
                    Text('${visibleItems.length} / ${_items.length}'),
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (widget.module == 'Forms')
                      OutlinedButton.icon(
                        onPressed: _showFormResponses,
                        icon: const Icon(Icons.inbox_outlined),
                        label: Text(_bn ? 'জমা উত্তর' : 'Responses'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _exportRecords,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(_bn ? 'Export JSON' : 'Export JSON'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importRecords,
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(_bn ? 'Import JSON' : 'Import JSON'),
                    ),
                  ]),
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: _bn ? 'শিরোনাম বা লেখা খুঁজুন' : 'Search titles or content',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: OFFYNEXTheme.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: OFFYNEXTheme.border)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text(_bn ? 'এখনো কিছু সংরক্ষণ করা হয়নি।' : 'Nothing saved yet.')),
                    ),
                  if (_items.isNotEmpty && visibleItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text(_bn ? 'কোনো মিল পাওয়া যায়নি।' : 'No matching records found.')),
                    ),
                  ...visibleItems.map((item) => Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: OFFYNEXTheme.border)),
                    child: ListTile(
                      leading: Icon(widget.module == 'Slides'
                          ? Icons.slideshow
                          : widget.module == 'Forms'
                              ? Icons.assignment
                              : widget.module == 'Database'
                                  ? Icons.table_chart
                                  : widget.module == 'Fonts'
                                      ? Icons.text_fields
                                      : Icons.auto_awesome),
                      title: Text(item['title']?.toString() ?? ''),
                      subtitle: Text(item['content']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => widget.module == 'Scan'
                          ? _openScanPdf(item)
                          : _editItem(item: item),
                      trailing: widget.module == 'Forms'
                          ? Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  tooltip: _bn ? 'উত্তর নিন' : 'Collect response',
                                  icon: const Icon(Icons.assignment_turned_in_outlined),
                                  onPressed: () => _collectFormResponse(item),
                                ),
                                IconButton(
                                  tooltip: _bn ? 'মুছুন' : 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteItem(item),
                                ),
                              ],
                            )
                          : widget.module == 'Slides'
                              ? Wrap(
                                  spacing: 0,
                                  children: [
                                    IconButton(
                                      tooltip: _bn ? 'স্লাইড প্রিভিউ' : 'Preview presentation',
                                      icon: const Icon(Icons.slideshow_outlined),
                                      onPressed: () => _previewSlides(item),
                                    ),
                                    IconButton(
                                      tooltip: _bn ? 'PDF Export' : 'Export Slides PDF',
                                      icon: const Icon(Icons.picture_as_pdf_outlined),
                                      onPressed: () => _exportSlidePdf(item),
                                    ),
                                    IconButton(
                                      tooltip: _bn ? 'মুছুন' : 'Delete',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteItem(item),
                                    ),
                                  ],
                                )
                              : widget.module == 'Scan'
                                  ? Wrap(spacing: 0, children: [
                                      IconButton(
                                        tooltip: _bn ? 'OCR লেখা যাচাই' : 'Review OCR text',
                                        icon: const Icon(Icons.text_snippet_outlined),
                                        onPressed: () => _reviewScanText(item),
                                      ),
                                      IconButton(
                                        tooltip: _bn ? 'PDF দেখুন' : 'View PDF',
                                        icon: const Icon(Icons.picture_as_pdf_outlined),
                                        onPressed: () => _openScanPdf(item),
                                      ),
                                      IconButton(
                                        tooltip: _bn ? 'PDF শেয়ার' : 'Share PDF',
                                        icon: const Icon(Icons.share_outlined),
                                        onPressed: () => _shareScan(item),
                                      ),
                                      IconButton(
                                        tooltip: _bn ? 'মুছুন' : 'Delete',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteItem(item),
                                      ),
                                    ])
                              : widget.module == 'Database'
                                  ? Wrap(
                                      spacing: 0,
                                      children: [
                                        IconButton(
                                          tooltip: _bn ? 'টেবিলের Row' : 'Manage table rows',
                                          icon: const Icon(Icons.table_rows_outlined),
                                          onPressed: () => _manageDatabaseRows(item),
                                        ),
                                        IconButton(
                                          tooltip: _bn ? 'মুছুন' : 'Delete',
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () => _deleteItem(item),
                                        ),
                                      ],
                                    )
                                  : IconButton(
                                      tooltip: _bn ? 'মুছুন' : 'Delete',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteItem(item),
                                    ),
                    ),
                  )),
                ],
                const SizedBox(height: 28),
              ],
            ),
      floatingActionButton: widget.module == 'Scan' || widget.module == 'Cloud' || _workspaceDataBlocked
          ? null
          : FloatingActionButton.extended(
              backgroundColor: OFFYNEXTheme.blue,
              foregroundColor: Colors.white,
              onPressed: () => _editItem(),
              icon: const Icon(Icons.add),
              label: Text(_bn ? 'নতুন তৈরি' : 'Create new'),
            ),
    );
  }
}


class _FormResponseDialog extends StatefulWidget {
  const _FormResponseDialog({
    required this.isBangla,
    required this.formTitle,
    required this.questions,
  });

  final bool isBangla;
  final String formTitle;
  final List<Map<String, dynamic>> questions;

  @override
  State<_FormResponseDialog> createState() => _FormResponseDialogState();
}

class _FormResponseDialogState extends State<_FormResponseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  late final List<String?> _choices;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.questions.length, (_) => TextEditingController());
    _choices = List<String?>.filled(widget.questions.length, null);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(int index, String? raw) {
    final question = widget.questions[index];
    final value = (raw ?? '').trim();
    if (question['required'] == true && value.isEmpty) {
      return widget.isBangla ? 'এই ঘরটি পূরণ করুন' : 'This field is required';
    }
    if (value.isEmpty) return null;
    switch (question['type']) {
      case 'email':
        final at = value.indexOf('@');
        final dot = value.lastIndexOf('.');
        if (at <= 0 || dot <= at + 1 || dot == value.length - 1 || value.contains(' ')) {
          return widget.isBangla ? 'সঠিক Email দিন' : 'Enter a valid email address';
        }
        break;
      case 'number':
        if (num.tryParse(value) == null) {
          return widget.isBangla ? 'শুধু সংখ্যা দিন' : 'Enter a valid number';
        }
        break;
      case 'date':
        if (DateTime.tryParse(value) == null) {
          return widget.isBangla ? 'সঠিক তারিখ নির্বাচন করুন' : 'Enter a valid date';
        }
        break;
    }
    return null;
  }

  Future<void> _chooseDate(int index) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_controllers[index].text) ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      _controllers[index].text =
          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      List<Map<String, String>>.generate(widget.questions.length, (index) {
        final question = widget.questions[index];
        return {
          'question': question['label'] as String,
          'answer': question['type'] == 'choice'
              ? (_choices[index] ?? '')
              : _controllers[index].text.trim(),
          'type': question['type'] as String,
          'required': question['required'] == true ? 'true' : 'false',
        };
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.formTitle),
      content: SizedBox(
        width: 520,
        height: 380,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              for (var index = 0; index < widget.questions.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Builder(builder: (context) {
                    final question = widget.questions[index];
                    final type = question['type'] as String;
                    final label = question['label'] as String;
                    final required = question['required'] == true;
                    final title = required ? '$label *' : label;
                    if (type == 'choice') {
                      final options = (question['options'] as List).cast<String>();
                      return DropdownButtonFormField<String>(
                        initialValue: _choices[index],
                        decoration: InputDecoration(
                          labelText: title,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final option in options)
                            DropdownMenuItem(value: option, child: Text(option)),
                        ],
                        onChanged: (value) => setState(() => _choices[index] = value),
                        validator: (value) => required && value == null
                            ? (widget.isBangla ? 'একটি বিকল্প বেছে নিন' : 'Choose an option')
                            : null,
                      );
                    }
                    return TextFormField(
                      controller: _controllers[index],
                      readOnly: type == 'date',
                      onTap: type == 'date' ? () => _chooseDate(index) : null,
                      keyboardType: type == 'email'
                          ? TextInputType.emailAddress
                          : type == 'number'
                              ? const TextInputType.numberWithOptions(decimal: true)
                              : TextInputType.text,
                      validator: (value) => _validate(index, value),
                      decoration: InputDecoration(
                        labelText: title,
                        border: const OutlineInputBorder(),
                        suffixIcon: type == 'date'
                            ? IconButton(
                                tooltip: widget.isBangla ? 'তারিখ বাছাই' : 'Choose date',
                                onPressed: () => _chooseDate(index),
                                icon: const Icon(Icons.calendar_month_outlined),
                              )
                            : null,
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isBangla ? 'উত্তর সংরক্ষণ' : 'Save response'),
        ),
      ],
    );
  }
}

class _WorkspaceItemDialog extends StatefulWidget {
  const _WorkspaceItemDialog({
    required this.isBangla,
    required this.title,
    required this.content,
    required this.contentLabel,
    required this.isNew,
  });

  final bool isBangla;
  final String title;
  final String content;
  final String contentLabel;
  final bool isNew;

  @override
  State<_WorkspaceItemDialog> createState() => _WorkspaceItemDialogState();
}

class _WorkspaceItemDialogState extends State<_WorkspaceItemDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _contentController = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;
    return AlertDialog(
      title: Text(widget.isNew
          ? (bn ? 'নতুন তৈরি করুন' : 'Create new')
          : (bn ? 'সম্পাদনা' : 'Edit')),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: bn ? 'নাম / শিরোনাম' : 'Name / title',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            minLines: 4,
            maxLines: 9,
            decoration: InputDecoration(
              labelText: widget.contentLabel,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(bn ? 'বাতিল' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'title': _titleController.text,
            'content': _contentController.text,
          }),
          child: Text(bn ? 'সংরক্ষণ' : 'Save'),
        ),
      ],
    );
  }
}
