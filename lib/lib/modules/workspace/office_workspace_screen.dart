import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pdf/pdf_to_document_service.dart';
import '../writer/writer_screen.dart';

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
    final decoded = raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _items = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items));
  }

  Future<void> _editItem({Map<String, dynamic>? item}) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final content = TextEditingController(text: item?['content']?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null
            ? (_bn ? 'নতুন তৈরি করুন' : 'Create new')
            : (_bn ? 'সম্পাদনা' : 'Edit')),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: InputDecoration(labelText: _bn ? 'নাম / শিরোনাম' : 'Name / title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: content,
              minLines: 4,
              maxLines: 9,
              decoration: InputDecoration(
                labelText: _contentLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_bn ? 'বাতিল' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_bn ? 'সংরক্ষণ' : 'Save')),
        ],
      ),
    );
    if (result == true && title.text.trim().isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      setState(() {
        if (item == null) {
          _items.insert(0, {
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
            'title': title.text.trim(),
            'content': content.text,
            'updatedAt': now,
          });
        } else {
          item['title'] = title.text.trim();
          item['content'] = content.text;
          item['updatedAt'] = now;
        }
      });
      await _save();
    }
    title.dispose();
    content.dispose();
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
    _backupController.text = const JsonEncoder.withIndent('  ').convert({
      'format': 'OFFYNEXBD_LOCAL_BACKUP',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'data': data,
    });
    if (mounted) setState(() {});
  }

  Future<void> _restoreBackup() async {
    try {
      final decoded = jsonDecode(_backupController.text) as Map<String, dynamic>;
      if (decoded['format'] != 'OFFYNEXBD_LOCAL_BACKUP' || decoded['version'] != 1 ||
          decoded['data'] is! Map) {
        throw const FormatException('Unsupported OFFYNEXBD backup.');
      }
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
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      for (final entry in data.entries) {
        if (!entry.key.startsWith('offynex_')) continue;
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is List) {
          await prefs.setStringList(entry.key, value.cast<String>());
        }
      }
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
        OutlinedButton.icon(
          onPressed: _createBackup,
          icon: const Icon(Icons.backup),
          label: Text(_bn ? 'ব্যাকআপ তৈরি' : 'Create backup'),
        ),
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
          ? 'প্রেজেন্টেশনের শিরোনাম ও স্লাইডের লেখা সংরক্ষণ করুন। PPTX/PDF export ও slideshow renderer পরবর্তী ইন্টিগ্রেশন ধাপ।'
          : 'Save presentation titles and slide text. PPTX/PDF export and slideshow rendering are next integration steps.',
      'Fonts' => _bn
          ? 'এখানে ফন্টের তালিকা ও নোট রাখা যায়। প্রকৃত TTF/OTF ইনস্টল ও সব এডিটরে প্রয়োগ এখনো যুক্ত হয়নি।'
          : 'Keep a font catalogue and notes here. Actual TTF/OTF installation and editor-wide activation are not connected yet.',
      'AI Assistant' => _bn
          ? 'বাংলা/ইংরেজি নির্দেশনা ও কাজের খসড়া সংরক্ষণ করুন। প্রকৃত AI উত্তর পেতে নিরাপদ AI service connection প্রয়োজন; এখনো সংযুক্ত নয়।'
          : 'Save Bangla/English prompts and drafts. A secure AI service connection is required for generated answers and is not connected yet.',
      'Forms' => _bn
          ? 'ফর্মের নাম ও প্রশ্নের তালিকা তৈরি/সম্পাদনা করুন। response collection ও sharing পরবর্তী ধাপ।'
          : 'Create and edit form names and question lists. Response collection and sharing are next steps.',
      'Database' => _bn
          ? 'ডেটা টেবিলের নাম, ফিল্ড ও স্কিমা নোট সংরক্ষণ করুন। প্রকৃত relational database engine এখনো যুক্ত হয়নি।'
          : 'Save table names, fields and schema notes. A relational database engine is not connected yet.',
      _ => '',
    };
    if (help.isEmpty) return const SizedBox.shrink();
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(help, style: Theme.of(context).textTheme.bodyMedium),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final module = _modules[widget.module]!;
    final title = _bn ? module.$1 : module.$2;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.module != 'Scan' && widget.module != 'Cloud')
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(module.$3, size: 34, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: Theme.of(context).textTheme.titleLarge),
                        Text(_bn ? 'অফলাইন-প্রথম কর্মক্ষেত্র' : 'Offline-first workspace'),
                      ])),
                    ]),
                  ),
                ),
                _moduleHelp(),
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
                if (widget.module != 'Scan' && widget.module != 'Cloud') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text(_bn ? 'সংরক্ষিত আইটেম' : 'Saved items',
                        style: Theme.of(context).textTheme.titleMedium)),
                    Text('${_items.length}'),
                  ]),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text(_bn ? 'এখনো কিছু সংরক্ষণ করা হয়নি।' : 'Nothing saved yet.')),
                    ),
                  ..._items.map((item) => Card(
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
                      trailing: IconButton(
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
      floatingActionButton: widget.module == 'Scan' || widget.module == 'Cloud'
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editItem(),
              icon: const Icon(Icons.add),
              label: Text(_bn ? 'নতুন তৈরি' : 'Create new'),
            ),
    );
  }
}
