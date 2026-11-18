import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'slides_pdf_export_service.dart';
import 'scan_document_service.dart';
import 'database_rows_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pdf/pdf_to_document_service.dart';
import 'workspace_backup_codec.dart';
import 'workspace_record_codec.dart';
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

  Future<void> _save() async {
    if (_workspaceDataBlocked) {
      throw StateError('Workspace editing is blocked because the original data is damaged.');
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(_items));
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
    setState(() {
      if (item == null) {
        _items.insert(0, {
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': result['title']!.trim(),
          'content': result['content'] ?? '',
          'updatedAt': now,
        });
      } else {
        item['title'] = result['title']!.trim();
        item['content'] = result['content'] ?? '';
        item['updatedAt'] = now;
      }
    });
    await _save();
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
      setState(() => _items.insertAll(0, additions));
      await _save();
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
    if (yes == true) {
      setState(() => _items.removeWhere((e) => e['id'] == item['id']));
      await _save();
    }
  }

  Future<void> _scanImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (Platform.isAndroid) {
        final captured = await ScanDocumentService.captureAndroid();
        if (captured == null) return;
        if (captured.recognizedText.trim().isNotEmpty) {
          final documents = await loadDocuments();
          documents.add({
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
            'title': captured.fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
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
            onPressed: () async {
              await Printing.sharePdf(
                bytes: captured.pdfBytes,
                filename: captured.fileName,
              );
            },
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
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WriterScreen())),
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
      final value = prefs.get(key);
      if (value is String || value is bool || value is int || value is double || value is List<String>) {
        data[key] = value;
      }
    }
    _backupController.text = WorkspaceBackupCodec.encode(data);
    if (mounted) setState(() {});
  }

  Future<void> _exportBackup() async {
    try {
      await _createBackup();
      if (!mounted || _backupController.text.trim().isEmpty) return;
      final bytes = Uint8List.fromList(utf8.encode(_backupController.text));
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-backup.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: _bn ? 'ব্যাকআপ ফাইল সংরক্ষণ' : 'Save backup file',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_bn ? 'ব্যাকআপ ফাইল সংরক্ষিত হয়েছে।' : 'Backup file saved.'),
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
        allowedExtensions: const ['json'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
        throw const FormatException('Backup file must be between 1 byte and 25 MB.');
      }
      final source = utf8.decode(bytes, allowMalformed: false);
      WorkspaceBackupCodec.decode(source);
      _backupController.text = source;
      if (mounted) setState(() {});
      await _restoreBackup();
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
      if (yes != true) return;
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
            label: Text(_bn ? 'JSON ফাইল সংরক্ষণ' : 'Export JSON file'),
          ),
          OutlinedButton.icon(
            onPressed: _importBackupFile,
            icon: const Icon(Icons.folder_open),
            label: Text(_bn ? 'JSON ফাইল খুলুন' : 'Import JSON file'),
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
          ? 'ফর্মের নাম ও প্রতি লাইনে একটি করে প্রশ্ন লিখুন। Collect response দিয়ে উত্তর নিন এবং Responses থেকে স্থানীয়ভাবে সংরক্ষিত উত্তর দেখুন। অনলাইন শেয়ারিং এখনো যুক্ত হয়নি।'
          : 'Create a form with one question per line. Collect responses and review locally saved submissions. Online sharing is not connected yet.',
      'Database' => _bn
          ? 'টেবিলের নাম ও কমা দিয়ে Field লিখুন। Manage table rows দিয়ে Offline-এ Row তৈরি, সম্পাদনা ও মুছতে পারবেন। SQL/relational query engine এখনো যুক্ত হয়নি।'
          : 'Define table names and comma-separated fields. Manage table rows to create, edit and delete offline records. A SQL/relational query engine is not connected yet.',
      _ => '',
    };
    if (help.isEmpty) return const SizedBox.shrink();
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(help, style: Theme.of(context).textTheme.bodyMedium),
    ));
  }

  Future<void> _manageDatabaseRows(Map<String, dynamic> table) async {
    final fields = (table['content']?.toString() ?? '')
        .split(',')
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (fields.isEmpty || fields.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn
            ? 'টেবিলে ১ থেকে ৪০টি কমা দিয়ে আলাদা করা Field লিখুন।'
            : 'Define between 1 and 40 comma-separated fields first.'),
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
            if (id is! String ||
                id.trim().isEmpty ||
                !rowIds.add(id) ||
                values is! Map) {
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
        fields: fields,
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

  Future<void> _collectFormResponse(Map<String, dynamic> form) async {
    final questions = (form['content']?.toString() ?? '')
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
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
    final raw = prefs.getString('offynex_forms_responses_v1');
    final responses = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) responses.add(Map<String, dynamic>.from(item));
          }
        }
      } catch (_) {
        // Preserve a malformed response archive before starting a new one.
        final key = 'offynex_forms_responses_recovery_${DateTime.now().microsecondsSinceEpoch}';
        await prefs.setString(key, raw);
      }
    }
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offynex_forms_responses_v1');
      final decoded = raw == null ? <dynamic>[] : jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Forms response archive must be a list.');
      }
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

  Future<void> _showFormResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_forms_responses_v1');
    final responses = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) responses.add(Map<String, dynamic>.from(item));
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_bn ? 'জমা দেওয়া উত্তর' : 'Form responses'),
        content: SizedBox(
          width: 520,
          child: responses.isEmpty
              ? Text(_bn ? 'এখনো কোনো উত্তর জমা হয়নি।' : 'No responses yet.')
              : ListView(
                  shrinkWrap: true,
                  children: responses.reversed.map((response) {
                    final answers = response['answers'] is List
                        ? (response['answers'] as List)
                        : const [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(response['formTitle']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            for (final answer in answers)
                              if (answer is Map)
                                Text('${answer['question'] ?? ''}: ${answer['answer'] ?? ''}'),
                            Text(response['submittedAt']?.toString() ?? '',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: _exportFormResponses,
            child: Text(_bn ? 'Export JSON' : 'Export JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_bn ? 'বন্ধ' : 'Close'),
          ),
        ],
      ),
    );
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
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        backgroundColor: OFFYNEXTheme.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(color: OFFYNEXTheme.ink, fontWeight: FontWeight.w800)),
        actions: [
          if (widget.module != 'Scan' && widget.module != 'Cloud' && !_workspaceDataBlocked)
            IconButton(
              tooltip: _bn ? 'নতুন তৈরি' : 'Create new',
              onPressed: () => _editItem(),
              icon: const Icon(Icons.add),
            ),
        ],
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
                if (widget.module != 'Scan' && widget.module != 'Cloud' && !_workspaceDataBlocked) ...[
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
                      onTap: () => _editItem(item: item),
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
  final List<String> questions;

  @override
  State<_FormResponseDialog> createState() => _FormResponseDialogState();
}

class _FormResponseDialogState extends State<_FormResponseDialog> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.questions.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.formTitle),
      content: SizedBox(
        width: 520,
        height: 360,
        child: ListView(
          children: [
            for (var index = 0; index < widget.questions.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controllers[index],
                  decoration: InputDecoration(
                    labelText: widget.questions[index],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            List<Map<String, String>>.generate(
              widget.questions.length,
              (index) => {
                'question': widget.questions[index],
                'answer': _controllers[index].text,
              },
            ),
          ),
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