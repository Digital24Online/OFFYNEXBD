import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/services.dart';
import 'writer_table.dart';
import 'writer_page_break.dart';
import 'writer_pdf_export_service.dart';
import 'writer_document_codec.dart';
import 'writer_document_backup_service.dart';
import 'writer_docx_export_service.dart';
import 'writer_document_format_service.dart';
import 'writer_viewport.dart';
import 'writer_content_metrics.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../theme/offynex_theme.dart';

const String documentsKey = 'offynex_writer_documents';
String? writerDataRecoveryNotice;
bool writerLibraryDataBlocked = false;

Future<List<Map<String, dynamic>>> loadDocuments() async {
  writerLibraryDataBlocked = false;
  writerDataRecoveryNotice = null;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(documentsKey);

  if (raw == null) return [];

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Writer library root must be a list.');
    }
    final documents = decoded
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Writer document record must be an object.');
          }
          return Map<String, dynamic>.from(item);
        })
        .toList(growable: false);
    return WriterDocumentCodec.validateLibraryRecords(documents);
  } catch (error) {
    writerLibraryDataBlocked = true;
    final recoveryKey =
        'offynex_writer_documents_recovery_${DateTime.now().microsecondsSinceEpoch}';
    final preserved = await prefs.setString(recoveryKey, raw);
    writerDataRecoveryNotice = preserved
        ? 'Writer library could not be read. Original data recovery copy saved: $recoveryKey'
        : 'Writer library could not be read and recovery copy failed: $error';
    return [];
  }
}

Future<void> storeDocuments(
  List<Map<String, dynamic>> documents,
) async {
  if (writerLibraryDataBlocked) {
    throw StateError('Writer library is damaged; original data is protected from overwrite.');
  }
  final validated = WriterDocumentCodec.validateLibraryRecords(documents);
  final prefs = await SharedPreferences.getInstance();
  final saved = await prefs.setString(documentsKey, jsonEncode(validated));
  if (!saved) throw StateError('Writer library could not be saved.');
}

class WriterScreen extends StatefulWidget {
  final bool isBangla;
  const WriterScreen({super.key, this.isBangla = false});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  String _t(String bn, String en) => widget.isBangla ? bn : en;

  List<Map<String, dynamic>> documents = [];
  bool isLoading = true;
  bool isDataBlocked = false;

  @override
  void initState() {
    super.initState();
    refreshDocuments();
  }

  Future<void> refreshDocuments() async {
    final result = await loadDocuments();
    if (!mounted) return;

    setState(() {
      documents = result;
      isLoading = false;
      isDataBlocked = writerLibraryDataBlocked;
    });
    final recoveryNotice = writerDataRecoveryNotice;
    if (recoveryNotice != null) {
      writerDataRecoveryNotice = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(recoveryNotice), duration: const Duration(seconds: 10)),
      );
    }
  }

  Future<void> exportDocuments() async {
    if (isDataBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Writer লাইব্রেরিতে সমস্যা হয়েছে। মূল ডেটা পুনরুদ্ধারের জন্য সংরক্ষিত আছে।', 'Writer library is damaged. Original data has been preserved for recovery.'))),
      );
      return;
    }
    try {
      final appDirectory = await getApplicationSupportDirectory();
      final archive = await WriterDocumentBackupService.exportArchive(
        documents,
        imageDirectory: Directory('${appDirectory.path}/offynexbd_images'),
      );
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-Writer-backup.offynex',
        bytes: archive,
        mimeType: 'application/zip',
        dialogTitle: _t('Writer ব্যাকআপ রপ্তানি', 'Export Writer backup'),
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Writer ডকুমেন্ট সফলভাবে রপ্তানি হয়েছে।', 'Writer documents exported successfully.'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Writer Export ব্যর্থ হয়েছে: $e', 'Writer export failed: $e'))),
        );
      }
    }
  }

  Future<void> importDocuments() async {
    if (isDataBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('মূল ডেটা সুরক্ষার জন্য Import বন্ধ রাখা হয়েছে।', 'Writer library is damaged. Import is blocked to protect the original data.'))),
      );
      return;
    }
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['offynex', 'zip', 'json'],
      );
      if (picked == null) return;
      if (!mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > WriterDocumentBackupService.maxArchiveBytes) {
        throw const FormatException('Writer archive must be between 1 byte and 25 MB.');
      }
      final appDirectory = await getApplicationSupportDirectory();
      final imported = (picked.extension?.toLowerCase() == 'json')
          ? WriterDocumentCodec.decode(utf8.decode(bytes, allowMalformed: false))
          : await WriterDocumentBackupService.importArchive(
              bytes,
              imageDirectory: Directory('${appDirectory.path}/offynexbd_images'),
            );
      if (!mounted) return;
      final existingIds = documents.map((item) => item['id']?.toString()).toSet();
      final additions = imported
          .where((item) => !existingIds.contains(item['id']))
          .toList(growable: false);
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('Writer ডকুমেন্ট Import করবেন?', 'Import Writer documents?')),
          content: Text(
            '${imported.length} documents found. ${additions.length} are new. Existing documents with the same ID will be kept unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('Import করুন', 'Import')),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      if (additions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Import করার মতো নতুন Writer ডকুমেন্ট নেই।', 'No new Writer documents to import.'))),
        );
        return;
      }
      final updated = [...documents, ...additions];
      await storeDocuments(updated);
      if (!mounted) return;
      setState(() => documents = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('${additions.length}টি Writer ডকুমেন্ট Import হয়েছে।', '${additions.length} Writer documents imported.'))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Writer Import ব্যর্থ হয়েছে: $e', 'Writer import failed: $e'))),
        );
      }
    }
  }

  Future<void> addDocument() async {
    if (isDataBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('পুনরুদ্ধার না হওয়া পর্যন্ত নতুন ডকুমেন্ট তৈরি বন্ধ থাকবে।', 'Writer library is damaged. New documents are blocked until recovery.'))),
      );
      return;
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final document = <String, dynamic>{
      'id': id,
      'title': 'Untitled Document',
      'content': '',
      'updated': DateTime.now().toIso8601String(),
    };

    final updated = [...documents, document];
    await storeDocuments(updated);

    if (!mounted) return;
    setState(() => documents = updated);

    openDocument(document);
  }

  Future<void> openDocument(Map<String, dynamic> document) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WriterEditorScreen(
          document: document,
          isBangla: widget.isBangla,
        ),
      ),
    );

    refreshDocuments();
  }

  Future<void> renameDocument(
    Map<String, dynamic> document,
  ) async {
    if (isDataBlocked) return;
    final controller = TextEditingController(
      text: document['title']?.toString() ?? '',
    );

    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('ডকুমেন্টের নাম পরিবর্তন', 'Rename document')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('ডকুমেন্টের নাম', 'Document name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: Text(_t('সংরক্ষণ', 'Save')),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newTitle == null || newTitle.isEmpty) return;

    final updated = documents.map((item) {
      if (item['id'] == document['id']) {
        return {
          ...item,
          'title': newTitle,
          'updated': DateTime.now().toIso8601String(),
        };
      }
      return item;
    }).toList();

    await storeDocuments(updated);
    if (!mounted) return;
    setState(() => documents = updated);
  }

  Future<void> deleteDocument(
    Map<String, dynamic> document,
  ) async {
    if (isDataBlocked) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('ডকুমেন্ট মুছে ফেলবেন?', 'Delete document?')),
        content: Text(
          _t('এই ডকুমেন্টটি স্থায়ীভাবে মুছে যাবে।', 'This document will be permanently deleted.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('মুছুন', 'Delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final updated = documents
        .where((item) => item['id'] != document['id'])
        .toList();

    await storeDocuments(updated);
    if (!mounted) return;
    setState(() => documents = updated);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 900 ? 32.0 : 18.0;
    return Scaffold(
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        backgroundColor: OFFYNEXTheme.canvas,
        titleSpacing: horizontalPadding,
        title: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: OFFYNEXTheme.blueSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_rounded, color: OFFYNEXTheme.blue)),
          const SizedBox(width: 11),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_t('Writer', 'Writer'), style: const TextStyle(color: OFFYNEXTheme.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(_t('ডকুমেন্ট ও লেখালেখি', 'Documents and writing'), style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
        ]),
        actions: [
          IconButton(tooltip: _t('ডকুমেন্ট Import', 'Import documents'), onPressed: importDocuments, icon: const Icon(Icons.file_download_outlined)),
          IconButton(tooltip: _t('ডকুমেন্ট Export', 'Export documents'), onPressed: exportDocuments, icon: const Icon(Icons.file_upload_outlined)),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isDataBlocked ? null : addDocument, backgroundColor: OFFYNEXTheme.blue, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded), label: Text(_t('নতুন ডকুমেন্ট', 'New Document')),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : documents.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Container(
                      width: 520, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: OFFYNEXTheme.border)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 76, height: 76, decoration: BoxDecoration(color: OFFYNEXTheme.blueSoft, borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.description_outlined, size: 38, color: OFFYNEXTheme.blue)),
                        const SizedBox(height: 18),
                        Text(_t('আপনার প্রথম ডকুমেন্ট তৈরি করুন', 'Create your first document'), textAlign: TextAlign.center, style: const TextStyle(color: OFFYNEXTheme.ink, fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(_t('সব লেখা ও ডকুমেন্ট এখানে নিরাপদে সংরক্ষিত থাকবে।', 'Your writing and documents will be saved securely on this device.'), textAlign: TextAlign.center, style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 13, height: 1.5)),

                      ]),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 100),
                  itemCount: documents.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width >= 1100 ? 4 : width >= 700 ? 3 : width >= 360 ? 2 : 1,
                    crossAxisSpacing: 16, mainAxisSpacing: 16,
                    childAspectRatio: width >= 900 ? 1.12 : 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final title = document['title']?.toString() ?? 'Untitled Document';
                    final updated = document['updated']?.toString();
                    return Material(
                      color: Colors.white, borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20), onTap: () => openDocument(document),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20), border: Border.all(color: OFFYNEXTheme.border),
                            boxShadow: [BoxShadow(color: OFFYNEXTheme.ink.withValues(alpha: 0.035), blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 44, height: 50, decoration: BoxDecoration(color: OFFYNEXTheme.blueSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_rounded, color: OFFYNEXTheme.blue, size: 25)),
                              const Spacer(),
                              PopupMenuButton<String>(
                                tooltip: _t('আরও অপশন', 'More options'),
                                onSelected: (value) { if (value == 'rename') renameDocument(document); if (value == 'delete') deleteDocument(document); },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'rename', child: Text(_t('নাম পরিবর্তন', 'Rename'))),
                                  PopupMenuItem(value: 'delete', child: Text(_t('মুছুন', 'Delete'))),
                                ],
                              ),
                            ]),
                            const Spacer(),
                            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: OFFYNEXTheme.ink, fontSize: 15, fontWeight: FontWeight.w800, height: 1.3)),
                            const SizedBox(height: 6),
                            Text(_t('ডিভাইসে সংরক্ষিত', 'Saved on device'), style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 11)),
                            if (updated != null) ...[
                              const SizedBox(height: 4),
                              Text(updated.replaceFirst('T', '  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 9)),
                            ],
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class WriterEditorScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  final bool isBangla;

  const WriterEditorScreen({
    super.key,
    required this.document,
    this.isBangla = false,
  });

  @override
  State<WriterEditorScreen> createState() =>
      _WriterEditorScreenState();
}

class _WriterEditorScreenState extends State<WriterEditorScreen> {
  String _t(String bn, String en) => widget.isBangla ? bn : en;

  late final TextEditingController titleController;
  late final FocusNode editorFocusNode;
  late QuillController quillController;

  int wordCount = 0;
  int selectedRibbonTab = 1;
  String selectedFontFamily = 'sans-serif';
  String selectedFontSize = '16';
  bool isSaved = true;
  Future<void> saveQueue = Future.value();
  Timer? saveTimer;

  // প্রতি ডকুমেন্টের Page Layout সেটিংস।
  String pageSize = 'A4';
  String pageOrientation = 'Portrait';
  String marginPreset = 'Normal';
  double marginTop = 1.0;
  double marginBottom = 1.0;
  double marginLeft = 1.0;
  double marginRight = 1.0;
  int pageBackgroundColorValue = 0xFFFFFFFF;

  // Writer-এর অতিরিক্ত নথি, রিভিউ ও ভিউ সেটিংস।
  double zoomLevel = 1.0;
  String viewFit = 'Width';
  final TransformationController _pageTransformController = TransformationController();
  bool showRuler = true;
  bool showStatusBar = true;
  bool showPageBorder = true;
  bool focusMode = false;
  bool captureRevisions = false;
  List<Map<String, dynamic>> writerComments = [];
  List<Map<String, dynamic>> writerCitations = [];
  List<Map<String, dynamic>> writerRevisions = [];
  String headerText = '';
  String footerText = '';

  @override
  void initState() {
    super.initState();

    editorFocusNode = FocusNode();
    titleController = TextEditingController(
      text: widget.document['title']?.toString() ??
          'Untitled Document',
    );

    final savedMeta = widget.document['writerMeta'];
    if (savedMeta is Map) {
      final savedFontFamily = savedMeta['fontFamily']?.toString();
      if (['sans-serif', 'serif'].contains(savedFontFamily)) {
        selectedFontFamily = savedFontFamily!;
      }
      zoomLevel = (savedMeta['zoom'] is num)
          ? (savedMeta['zoom'] as num).toDouble().clamp(0.5, 3.0).toDouble()
          : 1.0;
      final savedViewFitVersion = savedMeta['viewFitVersion'] is num
          ? (savedMeta['viewFitVersion'] as num).toInt()
          : 0;
      viewFit = savedViewFitVersion >= 2 &&
              ['Page', 'Width', 'Actual'].contains(savedMeta['viewFit'])
          ? savedMeta['viewFit'] as String
          : 'Width';
      showRuler = savedMeta['showRuler'] is bool
          ? savedMeta['showRuler'] as bool : true;
      showStatusBar = savedMeta['showStatusBar'] is bool
          ? savedMeta['showStatusBar'] as bool : true;
      showPageBorder = savedMeta['showPageBorder'] is bool
          ? savedMeta['showPageBorder'] as bool : true;
      captureRevisions = savedMeta['captureRevisions'] is bool
          ? savedMeta['captureRevisions'] as bool : false;
      focusMode = savedMeta['focusMode'] is bool
          ? savedMeta['focusMode'] as bool : false;
      headerText = savedMeta['headerText']?.toString() ?? '';
      footerText = savedMeta['footerText']?.toString() ?? '';
      final savedComments = savedMeta['comments'];
      if (savedComments is List) {
        writerComments = savedComments
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      final savedCitations = savedMeta['citations'];
      if (savedCitations is List) {
        writerCitations = savedCitations
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      final savedRevisions = savedMeta['revisions'];
      if (savedRevisions is List) {
        writerRevisions = savedRevisions
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    final savedLayout = widget.document['pageLayout'];
    if (savedLayout is Map) {
      final savedPageSize = savedLayout['pageSize']?.toString();
      final savedOrientation = savedLayout['orientation']?.toString();
      final savedPreset = savedLayout['marginPreset']?.toString();
      final savedPageColor = savedLayout['pageBackgroundColor'];
      if (savedPageColor is int && savedPageColor >= 0 && savedPageColor <= 0xFFFFFFFF) {
        pageBackgroundColorValue = savedPageColor;
      }

      if (['A4', 'A5', 'Letter', 'Legal'].contains(savedPageSize)) {
        pageSize = savedPageSize!;
      }
      if (['Portrait', 'Landscape'].contains(savedOrientation)) {
        pageOrientation = savedOrientation!;
      }
      if (savedPreset != null && savedPreset.isNotEmpty) {
        marginPreset = savedPreset;
      }

      double readMargin(String key, double fallback) {
        final value = savedLayout[key];
        if (value is num && value.isFinite) {
          return value.toDouble().clamp(0.25, 2.5).toDouble();
        }
        return fallback;
      }

      marginTop = readMargin('top', marginTop);
      marginBottom = readMargin('bottom', marginBottom);
      marginLeft = readMargin('left', marginLeft);
      marginRight = readMargin('right', marginRight);
    }

    final rawContent = widget.document['content'];
    late Document initialDocument;

    // পুরোনো সাধারণ লেখা এবং নতুন Quill ডকুমেন্ট দুটোই খুলবে।
    if (rawContent is List) {
      try {
        initialDocument = Document.fromJson(
          rawContent
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
        );
      } catch (_) {
        initialDocument = Document();
      }
    } else {
      initialDocument = Document()
        ..insert(0, rawContent?.toString() ?? '');
    }

    quillController = QuillController(
      document: initialDocument,
      selection: TextSelection.collapsed(
        offset: initialDocument.length - 1,
      ),
    );

    updateWordCount(quillController.document.toPlainText());
    quillController.addListener(onEditorChanged);
  }

  void updateWordCount(String text) {
    final words = text.trim().isEmpty
        ? <String>[]
        : text.trim().split(RegExp(r'\s+'));

    wordCount = words.length;
  }

  void onEditorChanged() {
    if (!mounted) return;
    setState(() {
      updateWordCount(quillController.document.toPlainText());
    });
    scheduleSave();
  }

  void scheduleSave() {
    saveTimer?.cancel();

    if (mounted && isSaved) {
      setState(() => isSaved = false);
    }

    saveTimer = Timer(
      const Duration(milliseconds: 700),
      () {
        saveDocument();
      },
    );
  }

  Future<void> saveDocument({bool rethrowOnError = false}) {
    final title = titleController.text;
    final content = quillController.document.toDelta().toJson();
    final pageLayout = _pageLayoutToJson();
    _captureRevisionIfNeeded();
    final writerMeta = _writerMetaToJson();
    final id = widget.document['id'];

    // আগের Save ব্যর্থ হলেও নতুন Save চালু থাকবে।
    saveQueue = saveQueue
        .catchError((Object error) {})
        .then((_) async {
          final documents = await loadDocuments();
          if (writerLibraryDataBlocked) {
            throw StateError('Writer library is damaged; the original document is protected.');
          }

          final index = documents.indexWhere(
            (item) => item['id'] == id,
          );

          if (index == -1) {
            throw StateError('The Writer document could not be found in the library.');
          }

          documents[index] = {
            ...documents[index],
            'title': title,
            'content': content,
            'pageLayout': pageLayout,
            'writerMeta': writerMeta,
            'updated': DateTime.now().toIso8601String(),
          };

          await storeDocuments(documents);

          if (mounted) {
            setState(() => isSaved = true);
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() => isSaved = false);
          }
          if (rethrowOnError) throw error;
        });

    return saveQueue;
  }
  

  Map<String, dynamic> _writerMetaToJson() => {
        'zoom': zoomLevel,
        'fontFamily': selectedFontFamily,
        'viewFit': viewFit,
        'viewFitVersion': 2,
        'showRuler': showRuler,
        'showStatusBar': showStatusBar,
        'showPageBorder': showPageBorder,
        'captureRevisions': captureRevisions,
        'focusMode': focusMode,
        'comments': writerComments,
        'citations': writerCitations,
        'revisions': writerRevisions,
        'headerText': headerText,
        'footerText': footerText,
      };

  void _captureRevisionIfNeeded() {
    if (!captureRevisions) return;
    final text = quillController.document.toPlainText();
    if (text.trim().isEmpty) return;
    final delta = quillController.document.toDelta().toJson();
    final encodedDelta = jsonEncode(delta);
    if (writerRevisions.isNotEmpty &&
        writerRevisions.last['deltaJson'] == encodedDelta) {
      return;
    }
    writerRevisions.add({
      'content': text,
      'delta': delta,
      'deltaJson': encodedDelta,
      'savedAt': DateTime.now().toIso8601String(),
    });
    if (writerRevisions.length > 20) {
      writerRevisions.removeAt(0);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> copyDocumentText() async {
    await Clipboard.setData(ClipboardData(
      text: quillController.document.toPlainText(),
    ));
    _showMessage('ডকুমেন্টের লেখা কপি হয়েছে।');
  }

  Future<void> showDocumentInfo() async {
    final text = quillController.document.toPlainText();
    final chars = text.replaceAll(RegExp(r'\s'), '').length;
    final paragraphs = text.split(RegExp(r'\n+'))
        .where((line) => line.trim().isNotEmpty).length;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Document Information')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_t('নাম', 'Name')}: ${titleController.text}'),
            Text('${_t('শব্দ', 'Words')}: $wordCount'),
            Text('${_t('অক্ষর', 'Characters')}: $chars'),
            Text('${_t('অনুচ্ছেদ', 'Paragraphs')}: $paragraphs'),
            Text('${_t('মন্তব্য', 'Comments')}: ${writerComments.length}'),
            Text('${_t('উদ্ধৃতি', 'Citations')}: ${writerCitations.length}'),
            Text('${_t('সর্বশেষ সংরক্ষণ', 'Last saved')}: ${widget.document['updated'] ?? _t('এই সেশনে', 'This session')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('বন্ধ করুন', 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> renameCurrentDocument() async {
    final controller = TextEditingController(text: titleController.text);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Rename Document')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: _t('ডকুমেন্টের নাম', 'Document name')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_ribbonLabel('Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_ribbonLabel('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    titleController.text = value;
    scheduleSave();
    setState(() {});
  }

  Future<void> insertCitation() async {
    final author = TextEditingController();
    final title = TextEditingController();
    final year = TextEditingController(text: DateTime.now().year.toString());
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Insert Citation')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: author, decoration: const InputDecoration(labelText: 'Author / লেখক')),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title / শিরোনাম')),
            TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year / সাল')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_ribbonLabel('Cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, [author.text.trim(), title.text.trim(), year.text.trim()]), child: Text(_ribbonLabel('Insert'))),
        ],
      ),
    );
    final a = author.text.trim();
    final t = title.text.trim();
    final y = year.text.trim();
    author.dispose(); title.dispose(); year.dispose();
    if (result == null || a.isEmpty || t.isEmpty || y.isEmpty || !mounted) return;
    writerCitations.add({'author': a, 'title': t, 'year': y});
    insertTextAtSelection('($a, $y)');
    scheduleSave();
  }

  void insertBibliography() {
    if (writerCitations.isEmpty) {
      _showMessage('আগে Insert Citation থেকে উদ্ধৃতি যোগ করুন।');
      return;
    }
    final sortedSources = List<Map<String, dynamic>>.from(writerCitations)
      ..sort((a, b) {
        final authorCompare = (a['author']?.toString() ?? '')
            .toLowerCase()
            .compareTo((b['author']?.toString() ?? '').toLowerCase());
        if (authorCompare != 0) return authorCompare;
        final yearCompare = (a['year']?.toString() ?? '')
            .compareTo(b['year']?.toString() ?? '');
        if (yearCompare != 0) return yearCompare;
        return (a['title']?.toString() ?? '')
            .toLowerCase()
            .compareTo((b['title']?.toString() ?? '').toLowerCase());
      });
    final lines = sortedSources.map((item) =>
      '${item['author']} (${item['year']}). ${item['title']}.').join('\n');
    insertTextAtSelection('\n\nReferences\n$lines\n');
    scheduleSave();
  }

  Future<void> manageCitationSources() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: Text(_ribbonLabel('Citation Sources / উদ্ধৃতির উৎস')),
          content: SizedBox(
            width: 460,
            child: writerCitations.isEmpty
                ? const Text('এখনো কোনো Citation Source যোগ করা হয়নি।')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: writerCitations.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final source = writerCitations[index];
                      final author = source['author']?.toString() ?? '';
                      final year = source['year']?.toString() ?? '';
                      final title = source['title']?.toString() ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('$author ($year)'),
                        subtitle: Text(title),
                        trailing: IconButton(
                          tooltip: _ribbonLabel('Remove source'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (confirmContext) => AlertDialog(
                                title: Text(_ribbonLabel('Remove citation source?')),
                                content: const Text(
                                  'উৎসটি তালিকা ও ভবিষ্যৎ Bibliography থেকে বাদ যাবে। ডকুমেন্টের আগে বসানো citation text মুছবে না।',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(confirmContext, false),
                                    child: Text(_ribbonLabel('Cancel')),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(confirmContext, true),
                                    child: Text(_ribbonLabel('Remove')),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              setState(() => writerCitations.removeAt(index));
                              scheduleSave();
                              refreshDialog(() {});
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_ribbonLabel('Close / বন্ধ')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> insertNote({required bool endnote}) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(endnote ? _ribbonLabel('Insert Endnote') : _ribbonLabel('Insert Footnote')),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'নোট লিখুন',
            labelText: _t('নোট', 'Note'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ribbonLabel('Cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_ribbonLabel('Insert')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note == null || note.isEmpty || !mounted) return;

    final plainText = quillController.document.toPlainText();
    final notePattern =
        RegExp(r'(?:Footnote|Endnote)\s+(\d+):');
    var number = 1;
    for (final match in notePattern.allMatches(plainText)) {
      final existing = int.tryParse(match.group(1) ?? '');
      if (existing != null && existing >= number) {
        number = existing + 1;
      }
    }

    insertTextAtSelection('[$number]');
    final kind = endnote ? 'Endnote' : 'Footnote';
    final noteText = '\n\n$kind $number: $note';
    final end = quillController.document.length - 1;
    quillController.replaceText(
      end,
      0,
      noteText,
      TextSelection.collapsed(offset: end + noteText.length),
    );
    scheduleSave();
  }

  void insertTableOfContents() {
    final headings = <String>[];

    // Quill-এর আসল Heading 1/2/3 ফরম্যাট থেকে শিরোনাম সংগ্রহ।
    var currentLine = '';
    for (final operation in quillController.document.toDelta().toJson()) {
      final inserted = operation['insert'];
      final attributes = operation['attributes'];
      if (inserted is! String) continue;

      final parts = inserted.split('\n');
      for (var index = 0; index < parts.length; index++) {
        currentLine += parts[index];
        if (index < parts.length - 1) {
          if (attributes is Map &&
              attributes['header'] != null &&
              currentLine.trim().isNotEmpty) {
            headings.add(currentLine.trim());
          }
          currentLine = '';
        }
      }
    }

    // পুরোনো Markdown-ধাঁচের # Heading-ও সমর্থন থাকবে।
    if (headings.isEmpty) {
      headings.addAll(
        quillController.document
            .toPlainText()
            .split('\n')
            .where((line) => line.trimLeft().startsWith('#'))
            .map((line) =>
                line.replaceFirst(RegExp(r'^\s*#+\s*'), '').trim())
            .where((line) => line.isNotEmpty),
      );
    }

    if (headings.isEmpty) {
      _showMessage('সূচিপত্র তৈরির আগে Heading 1/2/3 ব্যবহার করুন।');
      return;
    }

    final contents = headings
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
    insertTextAtSelection('\n\nTable of Contents\n$contents\n');
    scheduleSave();
  }

  Future<void> insertCaption() async {
    final controller = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Insert Caption')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: _t('ক্যাপশন', 'Caption')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ribbonLabel('Cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_ribbonLabel('Insert')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (caption == null || caption.isEmpty || !mounted) return;

    final plainText = quillController.document.toPlainText();
    final figureCount =
        RegExp(r'Figure\s+\d+:').allMatches(plainText).length;
    insertTextAtSelection('\nFigure ${figureCount + 1}: $caption\n');
    scheduleSave();
  }

  Future<void> addReviewComment() async {
    final selection = quillController.selection;
    final plainText = quillController.document.toPlainText();
    final start = selection.start.clamp(0, plainText.length);
    final end = selection.end.clamp(start, plainText.length);
    final selectedText =
        selection.isCollapsed ? '' : plainText.substring(start, end);

    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('New Comment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedText.isNotEmpty)
              Text(
                'নির্বাচিত লেখা: $selectedText',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: _t('মন্তব্য', 'Comment')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ribbonLabel('Cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_ribbonLabel('Add')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (comment == null || comment.isEmpty || !mounted) return;

    writerComments.add({
      'text': comment,
      'selectedText': selectedText,
      'startOffset': start,
      'endOffset': end,
      'createdAt': DateTime.now().toIso8601String(),
    });
    scheduleSave();
    setState(() {});
    _showMessage('মন্তব্য সংরক্ষিত হয়েছে।');
  }

  Future<void> showReviewComments() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Document Comments')),
        content: SizedBox(
          width: 420,
          child: writerComments.isEmpty
              ? const Text('এখনো কোনো মন্তব্য নেই।')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: writerComments.length,
                  itemBuilder: (context, index) {
                    final item = writerComments[index];
                    final selectedText =
                        item['selectedText']?.toString() ?? '';
                    final createdAt =
                        item['createdAt']?.toString() ?? '';
                    return ListTile(
                      title: Text(item['text']?.toString() ?? ''),
                      subtitle: Text(
                        [
                          if (selectedText.isNotEmpty)
                            '“$selectedText”',
                          if (createdAt.isNotEmpty) createdAt,
                        ].join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        final plainText =
                            quillController.document.toPlainText();
                        final savedStart = item['startOffset'];
                        final savedEnd = item['endOffset'];
                        var start = savedStart is num
                            ? savedStart.toInt()
                            : 0;
                        var end = savedEnd is num
                            ? savedEnd.toInt()
                            : start;

                        // লেখা সম্পাদনার পর পুরোনো offset সরে গেলে
                        // নির্বাচিত বাক্য খুঁজে নতুন অবস্থান নির্ণয় করা হয়।
                        if (selectedText.isNotEmpty) {
                          final occurrences = <int>[];
                          var searchFrom = 0;
                          while (searchFrom <=
                              plainText.length - selectedText.length) {
                            final found =
                                plainText.indexOf(selectedText, searchFrom);
                            if (found < 0) break;
                            occurrences.add(found);
                            searchFrom = found + selectedText.length;
                          }
                          if (occurrences.isNotEmpty) {
                            occurrences.sort((a, b) =>
                                (a - start).abs().compareTo((b - start).abs()));
                            start = occurrences.first;
                            end = start + selectedText.length;
                          }
                        }

                        final maxOffset = plainText.length;
                        start = start.clamp(0, maxOffset).toInt();
                        end = end.clamp(start, maxOffset).toInt();
                        quillController.updateSelection(
                          TextSelection(baseOffset: start, extentOffset: end),
                          ChangeSource.local,
                        );
                        editorFocusNode.requestFocus();
                        Navigator.pop(dialogContext);
                      },
                      trailing: IconButton(
                        tooltip: _ribbonLabel('Delete comment'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() => writerComments.removeAt(index));
                          scheduleSave();
                          Navigator.pop(dialogContext);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ribbonLabel('Close')),
          ),
        ],
      ),
    );
  }

  Future<void> findAndReplace() async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Find and Replace')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findController,
              decoration: InputDecoration(labelText: _t('খুঁজুন', 'Find')),
            ),
            TextField(
              controller: replaceController,
              decoration:
                  InputDecoration(labelText: _t('এর বদলে লিখুন', 'Replace with')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'find'),
            child: Text(_ribbonLabel('Find Next')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            child: Text(_ribbonLabel('Replace')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'all'),
            child: Text(_ribbonLabel('Replace All')),
          ),
        ],
      ),
    );

    final find = findController.text;
    final replacement = replaceController.text;
    findController.dispose();
    replaceController.dispose();

    if (action == null || find.isEmpty || !mounted) return;

    final plainText = quillController.document.toPlainText();
    final matches = <int>[];
    var searchOffset = 0;
    while (searchOffset <= plainText.length - find.length) {
      final found = plainText.indexOf(find, searchOffset);
      if (found < 0) break;
      matches.add(found);
      searchOffset = found + find.length;
    }

    if (matches.isEmpty) {
      _showMessage('লেখাটি পাওয়া যায়নি।');
      return;
    }

    if (action == 'find') {
      final found = matches.firstWhere(
        (offset) => offset >= quillController.selection.extentOffset,
        orElse: () => matches.first,
      );
      quillController.updateSelection(
        TextSelection(
          baseOffset: found,
          extentOffset: found + find.length,
        ),
        ChangeSource.local,
      );
      editorFocusNode.requestFocus();
      return;
    }

    if (action == 'replace') {
      final found = matches.firstWhere(
        (offset) => offset >= quillController.selection.extentOffset,
        orElse: () => matches.first,
      );
      quillController.replaceText(
        found,
        find.length,
        replacement,
        TextSelection.collapsed(offset: found + replacement.length),
      );
      _showMessage('একটি জায়গায় পরিবর্তন হয়েছে।');
      return;
    }

    for (final found in matches.reversed) {
      quillController.replaceText(
        found,
        find.length,
        replacement,
        TextSelection.collapsed(offset: found + replacement.length),
      );
    }
    _showMessage('${matches.length}টি জায়গায় পরিবর্তন হয়েছে।');
  }

  Future<void> showRevisionHistory() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: Text(_ribbonLabel('Revision Snapshots')),
          content: SizedBox(
            width: 420,
            child: writerRevisions.isEmpty
                ? const Text(
                    'Revision সংরক্ষণ চালু করুন; এরপর Save হলে snapshot তৈরি হবে।',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: writerRevisions.length,
                    itemBuilder: (context, index) {
                      final revisionIndex =
                          writerRevisions.length - 1 - index;
                      final item = writerRevisions[revisionIndex];
                      final date = item['savedAt']?.toString() ?? '';
                      final content = item['content']?.toString() ?? '';

                      return ListTile(
                        title: Text(
                          date.isEmpty ? 'তারিখ নেই' : date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (confirmContext) => AlertDialog(
                              title: Text(_ribbonLabel('Restore this snapshot?')),
                              content: const Text(
                                'বর্তমান লেখা প্রতিস্থাপিত হবে।',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    confirmContext,
                                    false,
                                  ),
                                  child: Text(_ribbonLabel('Cancel')),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    confirmContext,
                                    true,
                                  ),
                                  child: Text(_ribbonLabel('Restore')),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            try {
                              final savedDelta = item['delta'];
                              if (savedDelta is List) {
                                final restoredDocument = Document.fromJson(
                                  savedDelta
                                      .map((op) =>
                                          Map<String, dynamic>.from(op as Map))
                                      .toList(),
                                );
                                quillController.document = restoredDocument;
                                quillController.updateSelection(
                                  TextSelection.collapsed(
                                    offset: restoredDocument.length - 1,
                                  ),
                                  ChangeSource.local,
                                );
                              } else {
                                // পুরোনো plain-text snapshot সমর্থন।
                                quillController.replaceText(
                                  0,
                                  quillController.document.length - 1,
                                  content,
                                  const TextSelection.collapsed(offset: 0),
                                );
                              }
                              updateWordCount(
                                quillController.document.toPlainText(),
                              );
                              scheduleSave();
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              _showMessage('পুরোনো সংস্করণ ফিরিয়ে আনা হয়েছে।');
                            } catch (_) {
                              _showMessage(
                                'এই Revision খোলা যায়নি; বর্তমান লেখা অপরিবর্তিত আছে।',
                              );
                            }
                          }
                        },
                        trailing: IconButton(
                          tooltip: _ribbonLabel('Delete snapshot'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (confirmContext) => AlertDialog(
                                title: Text(_ribbonLabel('Delete snapshot?')),
                                content: const Text(
                                  'এই Revision স্থায়ীভাবে মুছে যাবে।',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(
                                      confirmContext,
                                      false,
                                    ),
                                    child: Text(_ribbonLabel('Cancel')),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(
                                      confirmContext,
                                      true,
                                    ),
                                    child: Text(_ribbonLabel('Delete')),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) {
                              setState(() {
                                writerRevisions.removeAt(revisionIndex);
                              });
                              scheduleSave();
                              refreshDialog(() {});
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            if (writerRevisions.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (confirmContext) => AlertDialog(
                      title: Text(_ribbonLabel('Clear revision history?')),
                      content: const Text(
                        'সব সংরক্ষিত Revision মুছে যাবে। ডকুমেন্টের বর্তমান লেখা মুছবে না।',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(confirmContext, false),
                          child: Text(_ribbonLabel('Cancel')),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(confirmContext, true),
                          child: Text(_ribbonLabel('Clear History')),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    setState(() => writerRevisions.clear());
                    scheduleSave();
                    refreshDialog(() {});
                  }
                },
                child: Text(_ribbonLabel('Clear History')),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_ribbonLabel('Close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rulerWidget() {
    return Container(
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE8EDF5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(9, (index) => Text('$index', style: const TextStyle(fontSize: 10, color: Colors.black54))),
      ),
    );
  }
  
  Widget buildFileRibbon() => _ribbonPanel([
        _ribbonButton(Icons.save, 'Save', () async { await saveDocument(); _showMessage('সংরক্ষণ সম্পন্ন।'); }),
        _ribbonButton(Icons.preview_outlined, 'Print Preview', openPrintPreview),
        _ribbonButton(Icons.print_outlined, 'Print', printDocument),
        _ribbonButton(Icons.drive_file_rename_outline, 'Rename', renameCurrentDocument),
        _ribbonButton(Icons.copy, 'Copy Text', copyDocumentText),
        _ribbonButton(Icons.info_outline, 'Document Info', showDocumentInfo),
        _ribbonButton(Icons.article_outlined, 'Header / Footer', editHeaderFooter),
        _ribbonButton(Icons.file_open_outlined, 'Import DOCX / ODT', importWriterDocument),
        _ribbonButton(Icons.description_outlined, 'Export DOCX', exportDocx),
        _ribbonButton(Icons.file_download_outlined, 'Export ODT', exportOdt),
        _ribbonButton(Icons.delete_outline, 'Clear', clearDocument),
        _ribbonButton(Icons.close, 'Close', () => Navigator.maybePop(context)),
      ]);

  Widget buildDesignRibbon() => _ribbonPanel([
        PopupMenuButton<int>(
          tooltip: _ribbonLabel('Page Color'),
          onSelected: (value) => _saveLayoutChange(() => pageBackgroundColorValue = value),
          itemBuilder: (context) => [
            PopupMenuItem(value: 0xFFFFFFFF, child: Text(_ribbonLabel('White'))),
            PopupMenuItem(value: 0xFFFFF8E7, child: Text(_ribbonLabel('Ivory'))),
            PopupMenuItem(value: 0xFFEAF4FF, child: Text(_ribbonLabel('Light Blue'))),
            PopupMenuItem(value: 0xFFF1F3F5, child: Text(_ribbonLabel('Light Gray'))),
            PopupMenuItem(value: 0xFFEAF7EA, child: Text(_ribbonLabel('Light Green'))),
            PopupMenuItem(value: 0xFFFFF9DB, child: Text(_ribbonLabel('Light Yellow'))),
          ],
          child: Chip(
            avatar: const Icon(Icons.palette_outlined, size: 18),
            label: Text(_ribbonLabel('Page Color')),
          ),
        ),
        FilterChip(
          label: Text(_ribbonLabel('Page Border')),
          selected: showPageBorder,
          onSelected: (value) {
            setState(() => showPageBorder = value);
            scheduleSave();
          },
        ),
        _ribbonButton(Icons.restart_alt, 'Reset Design', () {
          _saveLayoutChange(() {
            pageBackgroundColorValue = 0xFFFFFFFF;
            showPageBorder = true;
          });
        }),
      ]);

  Widget buildReferencesRibbon() => _ribbonPanel([
        _ribbonButton(Icons.format_list_numbered, 'Table of Contents', insertTableOfContents),
        _ribbonButton(Icons.format_quote, 'Citation', insertCitation),
        _ribbonButton(Icons.library_books_outlined, 'Manage Sources', manageCitationSources),
        _ribbonButton(Icons.menu_book, 'Bibliography', insertBibliography),
        _ribbonButton(Icons.note_add_outlined, 'Footnote', () => insertNote(endnote: false)),
        _ribbonButton(Icons.notes, 'Endnote', () => insertNote(endnote: true)),
        _ribbonButton(Icons.image_outlined, 'Caption', insertCaption),
      ]);

  Widget buildReviewRibbon() => _ribbonPanel([
        _ribbonButton(Icons.comment_outlined, 'New Comment', addReviewComment),
        _ribbonButton(Icons.forum_outlined, 'Comments', showReviewComments),
        _ribbonButton(Icons.search, 'Find / Replace', findAndReplace),
        _ribbonButton(Icons.history, 'Revision History', showRevisionHistory),
        FilterChip(
          label: Text(_ribbonLabel('Capture revisions')),
          selected: captureRevisions,
          onSelected: (value) {
            setState(() => captureRevisions = value);
            scheduleSave();
          },
        ),
      ]);

  Widget buildViewRibbon() => _ribbonPanel([
        Wrap(spacing: 6, children: [
          ChoiceChip(label: Text(_t('সম্পূর্ণ পৃষ্ঠা', 'Full Page')), selected: viewFit == 'Page', onSelected: (_) => _setViewFit('Page')),
          ChoiceChip(label: Text(_t('পৃষ্ঠার প্রস্থ', 'Page Width')), selected: viewFit == 'Width', onSelected: (_) => _setViewFit('Width')),
          ChoiceChip(label: const Text('100%'), selected: viewFit == 'Actual', onSelected: (_) => _setViewFit('Actual')),
        ]),
        SizedBox(
          width: 250,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              key: const ValueKey('writer-zoom-out'),
              tooltip: _t('ছোট করুন', 'Zoom out'),
              visualDensity: VisualDensity.compact,
              onPressed: () => _adjustZoom(-0.1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${_t('জুম', 'Zoom')} ${(zoomLevel * 100).round()}%'),
                Slider(
                  key: const ValueKey('writer-zoom-slider'),
                  value: zoomLevel,
                  min: WriterViewportLayout.minimumZoom,
                  max: WriterViewportLayout.maximumZoom,
                  divisions: 25,
                  onChanged: (value) => _setZoomLevel(value, save: false),
                  onChangeEnd: (_) => scheduleSave(),
                ),
              ]),
            ),
            IconButton(
              key: const ValueKey('writer-zoom-in'),
              tooltip: _t('বড় করুন', 'Zoom in'),
              visualDensity: VisualDensity.compact,
              onPressed: () => _adjustZoom(0.1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
        ),
        FilterChip(label: Text(_t('রুলার', 'Ruler')), selected: showRuler, onSelected: (v) { setState(() => showRuler = v); scheduleSave(); }),
        FilterChip(label: Text(_t('পৃষ্ঠার বর্ডার', 'Page Border')), selected: showPageBorder, onSelected: (v) { setState(() => showPageBorder = v); scheduleSave(); }),
        FilterChip(label: Text(_t('স্ট্যাটাস বার', 'Status Bar')), selected: showStatusBar, onSelected: (v) { setState(() => showStatusBar = v); scheduleSave(); }),
        FilterChip(
           label: Text(_t('ফোকাস মোড', 'Focus Mode')),
           selected: focusMode,
           onSelected: (value) {
             setState(() => focusMode = value);
             scheduleSave();
           },
         ),
      ]);
  
  Widget _ribbonPanel(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: const BoxDecoration(
          color: Color(0xFFEFF2F0),
          border: Border(bottom: BorderSide(color: Color(0xFFD2DAD5))),
        ),
        child: Wrap(
          spacing: 3,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );

  String _ribbonLabel(String english) {
    const translations = <String, String>{
      'Page Color': 'পৃষ্ঠার রং', 'White': 'সাদা', 'Ivory': 'আইভরি',
      'Light Blue': 'হালকা নীল', 'Light Gray': 'হালকা ধূসর',
      'Light Green': 'হালকা সবুজ', 'Light Yellow': 'হালকা হলুদ',
      'Page Border': 'পৃষ্ঠার বর্ডার', 'Capture revisions': 'সংশোধন সংরক্ষণ',
      'Custom Size': 'নিজস্ব সাইজ', 'Bold': 'গাঢ়', 'Italic': 'তির্যক',
      'Underline': 'নিচে দাগ', 'Strikethrough': 'মাঝে দাগ',
      'Red Text': 'লাল লেখা', 'Yellow Highlight': 'হলুদ হাইলাইট',
      'Save': 'সংরক্ষণ',
      'Print Preview': 'প্রিন্ট প্রিভিউ',
      'Print': 'প্রিন্ট',
      'Rename': 'নাম পরিবর্তন',
      'Copy Text': 'লেখা কপি',
      'Document Info': 'ডকুমেন্টের তথ্য',
      'Header / Footer': 'হেডার / ফুটার',
      'Import DOCX / ODT': 'DOCX / ODT Import',
      'Export DOCX': 'DOCX Export',
      'Export ODT': 'ODT Export',
      'Clear': 'খালি করুন',
      'Close': 'বন্ধ',
      'Reset Design': 'ডিজাইন রিসেট',
      'Table of Contents': 'সূচিপত্র',
      'Citation': 'উদ্ধৃতি',
      'Manage Sources': 'উৎস ব্যবস্থাপনা',
      'Bibliography': 'তথ্যসূত্র',
      'Footnote': 'পাদটীকা',
      'Endnote': 'শেষটীকা',
      'Caption': 'ক্যাপশন',
      'New Comment': 'নতুন মন্তব্য',
      'Comments': 'মন্তব্য',
      'Find / Replace': 'খুঁজুন / প্রতিস্থাপন',
      'Revision History': 'সংশোধনের ইতিহাস',
      'Page Size': 'পৃষ্ঠার আকার',
      'Orientation': 'দিকনির্দেশ',
      'Margins': 'মার্জিন',
      'Letter': 'লেটার',
      'Legal': 'লিগ্যাল',
      'Portrait': 'পোর্ট্রেট',
      'Landscape': 'ল্যান্ডস্কেপ',
      'Normal': 'স্বাভাবিক',
      'Narrow': 'সরু',
      'Moderate': 'মাঝারি',
      'Wide': 'প্রশস্ত',
      'Custom Margins...': 'নিজস্ব মার্জিন...',
      'Custom Margins (inches)': 'নিজস্ব মার্জিন (ইঞ্চি)',
      'Top': 'উপর',
      'Bottom': 'নিচে',
      'Left': 'বামে',
      'Right': 'ডানে',
      'Apply': 'প্রয়োগ',
      'Reset': 'রিসেট',
      'Cancel': 'বাতিল',
      'Page Margins': 'পৃষ্ঠার মার্জিন',
      'Document Information': 'ডকুমেন্টের তথ্য',
      'Rename Document': 'ডকুমেন্টের নাম পরিবর্তন',
      'Insert Citation': 'উদ্ধৃতি যোগ করুন',
      'Citation Sources / উদ্ধৃতির উৎস': 'উদ্ধৃতির উৎস',
      'Remove citation source?': 'উদ্ধৃতির উৎস সরাবেন?',
      'Remove': 'সরান',
      'Close / বন্ধ': 'বন্ধ',
      'Insert Caption': 'ক্যাপশন যোগ করুন',
      'Add': 'যোগ করুন',
      'Document Comments': 'ডকুমেন্টের মন্তব্য',
      'Find and Replace': 'খুঁজুন ও প্রতিস্থাপন',
      'Find Next': 'পরবর্তীটি খুঁজুন',
      'Replace': 'প্রতিস্থাপন',
      'Replace All': 'সব প্রতিস্থাপন',
      'Revision Snapshots': 'সংশোধনের সংস্করণ',
      'Restore this snapshot?': 'এই সংস্করণটি পুনরুদ্ধার করবেন?',
      'Restore': 'পুনরুদ্ধার',
      'Delete snapshot?': 'সংস্করণ মুছবেন?',
      'Delete': 'মুছুন',
      'Clear revision history?': 'সংশোধনের ইতিহাস মুছবেন?',
      'Clear History': 'ইতিহাস মুছুন',
      'Clear document?': 'ডকুমেন্ট খালি করবেন?',
      'Custom Font Size': 'নিজস্ব ফন্ট সাইজ',
      'Insert Hyperlink': 'হাইপারলিংক যোগ করুন',
      'Remove source': 'উৎস সরান',
      'Delete comment': 'মন্তব্য মুছুন',
      'Delete snapshot': 'সংস্করণ মুছুন',
      'Website URL': 'ওয়েবসাইটের ঠিকানা',
      'Size in points (8–72)': 'সাইজ (৮–৭২ পয়েন্ট)',
      'Insert Endnote': 'শেষটীকা যোগ করুন',
      'Insert Footnote': 'পাদটীকা যোগ করুন',
      'Symbols': 'প্রতীক',
    };
    return _t(translations[english] ?? english, english);
  }

  Widget _ribbonButton(IconData icon, String label, VoidCallback action) =>
      SizedBox(
        width: 72,
        height: 42,
        child: Tooltip(
          message: _ribbonLabel(label),
          child: TextButton(
            onPressed: action,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF26362D),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: const Color(0xFF315D43)),
                const SizedBox(height: 2),
                Text(
                  _ribbonLabel(label),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, height: 1.0),
                ),
              ],
            ),
          ),
        ),
      );

  void selectAllText() {
    final endOffset = quillController.document.length - 1;
    if (endOffset <= 0) return;

    quillController.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: endOffset),
          ChangeSource.local,
    );
    editorFocusNode.requestFocus();
  }

  Future<void> clearDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Clear document?')),
        content: const Text('সব লেখা মুছে ফেলতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_ribbonLabel('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_ribbonLabel('Clear')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    quillController.clear();
    updateWordCount('');
    await saveDocument();

    if (mounted) setState(() {});
  }

  Widget buildRibbonTabs() {
    final tabs = [
      _t('ফাইল', 'File'), _t('হোম', 'Home'), _t('ইনসার্ট', 'Insert'),
      _t('ডিজাইন', 'Design'), _t('লেআউট', 'Layout'),
      _t('রেফারেন্স', 'References'), _t('রিভিউ', 'Review'), _t('ভিউ', 'View'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF185C3B),
        border: Border(bottom: BorderSide(color: Color(0xFF12452C))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(tabs.length, (index) {
          final selected = selectedRibbonTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => setState(() => selectedRibbonTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE8F1EB) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? const Color(0xFFB8D5C1) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: selected ? const Color(0xFF174B30) : Colors.white,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        })),
      ),
    );
  }
  
  
Future<void> showCustomFontSizeDialog() async {
    final controller = TextEditingController(text: selectedFontSize);
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Custom Font Size')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Size in points (8–72)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_ribbonLabel('Cancel'))),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || !parsed.isFinite || parsed < 8 || parsed > 72) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(_t('৮ থেকে ৭২ পয়েন্টের মধ্যে সাইজ দিন।', 'Enter a font size between 8 and 72 points.'))),
                );
                return;
              }
              Navigator.pop(dialogContext, parsed);
            },
            child: Text(_ribbonLabel('Apply')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() => selectedFontSize = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1));
    final pixelValue = value * (4 / 3);
    quillController.formatSelection(
      Attribute.fromKeyValue('size', pixelValue.toStringAsFixed(2)),
    );
  }

  Widget buildHomeRibbon() {
  const fontFamilies = <String, String>{
    'Noto Sans Bengali': 'sans-serif',
    'Noto Serif Bengali': 'serif',
  };

  const fontSizes = [
    '8', '9', '10', '11', '12', '14',
    '16', '18', '20', '22', '24', '26',
    '28', '36', '48', '72',
  ];

  void applyFontSize(String points) {
    final pointValue = double.parse(points);
    final pixelValue = pointValue * (4 / 3);

    quillController.formatSelection(
      Attribute.fromKeyValue(
        'size',
        pixelValue.toStringAsFixed(2),
      ),
    );
  }

  return Container(
    width: double.infinity,
    color: const Color(0xFFF3F6FA),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: Wrap(
      spacing: 5,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Font Family
        DropdownButton<String>(
          isDense: true,
          itemHeight: 48,
          iconSize: 16,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          value: fontFamilies.containsValue(selectedFontFamily)
              ? selectedFontFamily
              : 'sans-serif',
          items: fontFamilies.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.value,
              child: Text(entry.key),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedFontFamily = value;
            });

            quillController.formatSelection(
              Attribute.fromKeyValue('font', value),
            );
          },
        ),

        // Font Size (Points)
        DropdownButton<String>(
          isDense: true,
          itemHeight: 48,
          iconSize: 16,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          value: fontSizes.contains(selectedFontSize)
              ? selectedFontSize
              : '16',
          items: fontSizes.map((size) {
            return DropdownMenuItem<String>(
              value: size,
              child: Text(size),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedFontSize = value;
            });

            applyFontSize(value);
          },
        ),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(30, 30), padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), textStyle: const TextStyle(fontSize: 10)),
          onPressed: showCustomFontSizeDialog,
          icon: const Icon(Icons.edit, size: 16),
          label: Text(_ribbonLabel('Custom Size')),
        ),

        // Bold
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: _ribbonLabel('Bold'),
          onPressed: () {
            quillController.formatSelection(Attribute.bold);
          },
          icon: const Icon(Icons.format_bold),
        ),

        // Italic
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: _ribbonLabel('Italic'),
          onPressed: () {
            quillController.formatSelection(Attribute.italic);
          },
          icon: const Icon(Icons.format_italic),
        ),

        // Underline
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: _ribbonLabel('Underline'),
          onPressed: () {
            quillController.formatSelection(Attribute.underline);
          },
          icon: const Icon(Icons.format_underline),
        ),

        // Strikethrough
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: _ribbonLabel('Strikethrough'),
          onPressed: () {
            quillController.formatSelection(
              Attribute.strikeThrough,
            );
          },
          icon: const Icon(Icons.format_strikethrough),
        ),

        // Red Text
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: _ribbonLabel('Red Text'),
          onPressed: () {
            quillController.formatSelection(
              Attribute.fromKeyValue('color', '#FF0000'),
            );
          },
          icon: const Icon(
            Icons.format_color_text,
            color: Colors.red,
          ),
        ),

        // Yellow Highlight
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: _ribbonLabel('Yellow Highlight'),
          onPressed: () {
            quillController.formatSelection(
              Attribute.fromKeyValue('background', '#FFFF00'),
            );
          },
          icon: const Icon(
            Icons.format_color_fill,
            color: Colors.orange,
          ),
        ),
      ],
    ),
  );
}
  

  Map<String, dynamic> _pageLayoutToJson() {
    return {
      'pageSize': pageSize,
      'orientation': pageOrientation,
      'marginPreset': marginPreset,
      'top': marginTop,
      'bottom': marginBottom,
      'left': marginLeft,
      'right': marginRight,
      'pageBackgroundColor': pageBackgroundColorValue,
    };
  }

  Size get _pageDimensions {
    final dimensions = <String, Size>{
      'A4': const Size(8.27 * 96, 11.69 * 96),
      'A5': const Size(5.83 * 96, 8.27 * 96),
      'Letter': const Size(8.5 * 96, 11 * 96),
      'Legal': const Size(8.5 * 96, 14 * 96),
    };
    final selected = dimensions[pageSize] ?? dimensions['A4']!;
    if (pageOrientation == 'Landscape') {
      return Size(selected.height, selected.width);
    }
    return selected;
  }

  PdfPageFormat get _selectedPdfFormat {
    final page = _pageDimensions;
    return PdfPageFormat(page.width / 96 * 72, page.height / 96 * 72);
  }

  Future<Uint8List> _buildWriterPdf(PdfPageFormat format) async {
    final sansFontData = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serifFontData = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latinFontData = await rootBundle.load('assets/fonts/NotoSans.ttf');
    final delta = quillController.document.toDelta().toJson()
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return WriterPdfExportService.build(
      title: titleController.text.trim().isEmpty
          ? 'Untitled Document'
          : titleController.text.trim(),
      delta: delta,
      sansFontData: sansFontData,
      serifFontData: serifFontData,
      latinFontData: latinFontData,
      pageFormat: format,
      marginTop: marginTop * 72,
      marginBottom: marginBottom * 72,
      marginLeft: marginLeft * 72,
      marginRight: marginRight * 72,
      headerText: headerText,
      footerText: footerText,
    );
  }


  Future<void> importWriterDocument() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['docx', 'odt'],
      );
      if (picked == null) return;
      if (!mounted) return;
      final fileSize = picked.lengthSync() ?? await picked.length() ?? 0;
      if (!mounted) return;
      if (fileSize <= 0 || fileSize > WriterDocumentFormatService.maxInputBytes) {
        _showMessage(_t('ফাইল খালি অথবা ২৫ MB-এর বেশি।', 'File is empty or exceeds 25 MB.'));
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('ডকুমেন্ট Import', 'Import document')),
          content: Text(_t(
            'মূল ডকুমেন্ট অপরিবর্তিত রেখে নতুন Writer ডকুমেন্ট তৈরি হবে।',
            'A new Writer document will be created. Your current document will remain unchanged.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('Import', 'Import')),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await saveDocument();
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final appDirectory = await getApplicationSupportDirectory();
      final name = picked.name;
      final dot = name.lastIndexOf('.');
      final fileTitle = dot > 0 ? name.substring(0, dot) : name;
      final imported = await WriterDocumentFormatService.importFile(
        bytes: bytes,
        extension: picked.extension ?? '',
        imageDirectory: Directory('${appDirectory.path}/offynexbd_images'),
        title: fileTitle,
      );
      if (!mounted) return;
      final now = DateTime.now().toIso8601String();
      final newDocument = <String, dynamic>{
        'id': 'writer_import_${DateTime.now().microsecondsSinceEpoch}',
        'title': imported.title,
        'content': imported.delta,
        'created': now,
        'updated': now,
        'pageLayout': {
          ...?imported.pageLayout,
          'pageBackgroundColor': 0xFFFFFFFF,
        },
        'writerMeta': {
          'zoom': 1.0,
          'fontFamily': 'sans-serif',
          'viewFit': 'Page',
          'showRuler': true,
          'showStatusBar': true,
          'showPageBorder': true,
          'captureRevisions': false,
          'focusMode': false,
          'comments': <Map<String, dynamic>>[],
          'citations': <Map<String, dynamic>>[],
          'revisions': <Map<String, dynamic>>[],
          'headerText': imported.headerText,
          'footerText': imported.footerText,
        },
      };
      final documents = await loadDocuments();
      if (writerLibraryDataBlocked) {
        throw StateError('Writer library is protected because its saved data could not be read.');
      }
      await storeDocuments([...documents, newDocument]);
      if (!mounted) return;
      _showMessage(_t(
        '${imported.format} Import সম্পন্ন। নতুন ডকুমেন্ট তালিকায় যোগ হয়েছে.',
        '${imported.format} import completed. The new document is in your library.',
      ));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        _showMessage(_t('ডকুমেন্ট Import করা যায়নি: $error', 'Could not import document: $error'));
      }
    }
  }

  Future<void> exportOdt() async {
    try {
      await saveDocument();
      final appDirectory = await getApplicationSupportDirectory();
      final delta = quillController.document.toDelta().toJson()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final bytes = await WriterDocumentFormatService.exportOdt(
        title: titleController.text.trim().isEmpty ? 'Untitled Document' : titleController.text.trim(),
        delta: delta,
        imageDirectory: Directory('${appDirectory.path}/offynexbd_images'),
        pageLayout: _pageLayoutToJson(),
        headerText: headerText,
        footerText: footerText,
      );
      if (!mounted) return;
      final rawName = titleController.text.trim().isEmpty ? 'OFFYNEXBD-Document' : titleController.text.trim();
      final safeName = rawName.replaceAll(' ', '_').replaceAll('/', '_').replaceAll('\\\\', '_');
      final saved = await FilePicker.saveFile(
        fileName: '$safeName.odt',
        bytes: bytes,
        mimeType: 'application/vnd.oasis.opendocument.text',
        dialogTitle: _t('ODT ফাইল সংরক্ষণ', 'Save ODT document'),
      );
      if (saved == null || !mounted) return;
      _showMessage(_t('ODT Export সম্পন্ন হয়েছে।', 'ODT export completed.'));
    } catch (error) {
      if (mounted) {
        _showMessage(_t('ODT তৈরি করা যায়নি: $error', 'Could not create ODT: $error'));
      }
    }
  }

  Future<void> exportDocx() async {
    try {
      await saveDocument();
      final delta = quillController.document.toDelta().toJson()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final bytes = await WriterDocxExportService.build(
        title: titleController.text.trim().isEmpty
            ? 'Untitled Document'
            : titleController.text.trim(),
        delta: delta,
        pageLayout: _pageLayoutToJson(),
        headerText: headerText,
        footerText: footerText,
      );
      if (!mounted) return;
      final baseName = titleController.text.trim().isEmpty
          ? 'OFFYNEXBD-Document'
          : titleController.text.trim();
      final fileName = '${baseName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.docx';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        dialogTitle: _t('DOCX ফাইল সংরক্ষণ', 'Save DOCX document'),
      );
      if (saved == null || !mounted) return;
      _showMessage(_t('DOCX Export সম্পন্ন হয়েছে।', 'DOCX export completed.'));
    } catch (error) {
      if (!mounted) return;
      _showMessage(_t('DOCX তৈরি করা যায়নি: $error', 'Could not create DOCX: $error'));
    }
  }

  Future<void> editHeaderFooter() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => _WriterHeaderFooterDialog(
        initialHeader: headerText,
        initialFooter: footerText,
        isBangla: widget.isBangla,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      headerText = result[0];
      footerText = result[1];
    });
    await saveDocument();
    _showMessage(_t('Header ও Footer সংরক্ষিত হয়েছে।', 'Header and footer saved.'));
  }

  Future<void> openPrintPreview() async {
    try {
      await saveDocument(rethrowOnError: true);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => _WriterPrintPreviewScreen(
            fileName: titleController.text.trim().isEmpty
                ? 'OFFYNEXBD-Document'
                : titleController.text.trim(),
            initialPageFormat: _selectedPdfFormat,
            buildPdf: _buildWriterPdf,
            controller: quillController,
            focusNode: editorFocusNode,
            isBangla: widget.isBangla,
            onSave: () => saveDocument(rethrowOnError: true),
            onEditTable: editWriterTable,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_t('সংরক্ষণ ব্যর্থ হওয়ায় প্রিন্ট প্রিভিউ খোলা যায়নি: $error', 'Print Preview could not open because saving failed: $error'));
    }
  }

  Future<void> printDocument() async {
    try {
      await saveDocument(rethrowOnError: true);
      if (!mounted) return;
      await Printing.layoutPdf(
        name: titleController.text.trim().isEmpty
            ? 'OFFYNEXBD-Document.pdf'
            : '${titleController.text.trim()}.pdf',
        format: _selectedPdfFormat,
        onLayout: _buildWriterPdf,
      );
    } catch (error) {
      if (mounted) _showMessage('প্রিন্ট তৈরি করা যায়নি: $error');
    }
  }


  void _setZoomLevel(double value, {bool save = true}) {
    setState(() {
      zoomLevel = value.clamp(
        WriterViewportLayout.minimumZoom,
        WriterViewportLayout.maximumZoom,
      ).toDouble();
    });
    _pageTransformController.value = Matrix4.identity();
    if (save) scheduleSave();
  }

  void _adjustZoom(double amount) {
    _setZoomLevel(zoomLevel + amount);
  }

  void _handlePageInteractionEnd(ScaleEndDetails details) {
    final matrix = _pageTransformController.value;
    final gestureScale = matrix.getMaxScaleOnAxis();
    if (!gestureScale.isFinite || (gestureScale - 1).abs() < 0.015) return;

    final translateX = matrix.storage[12];
    final translateY = matrix.storage[13];
    setState(() {
      zoomLevel = (zoomLevel * gestureScale)
          .clamp(
            WriterViewportLayout.minimumZoom,
            WriterViewportLayout.maximumZoom,
          )
          .toDouble();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageTransformController.value = Matrix4.identity()
        ..translateByDouble(translateX, translateY, 0, 1);
    });
    scheduleSave();
  }

  Widget _buildViewportControls() {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: OFFYNEXTheme.border),
          bottom: BorderSide(color: OFFYNEXTheme.border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: _t('ছোট করুন', 'Zoom out'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              onPressed: () => _adjustZoom(-0.1),
              icon: const Icon(Icons.remove_circle_outline, size: 20),
            ),
            SizedBox(
              width: 88,
              child: Slider(
                value: zoomLevel,
                min: WriterViewportLayout.minimumZoom,
                max: WriterViewportLayout.maximumZoom,
                divisions: 25,
                onChanged: (value) => _setZoomLevel(value, save: false),
                onChangeEnd: (_) => scheduleSave(),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${(zoomLevel * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: _t('বড় করুন', 'Zoom in'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              onPressed: () => _adjustZoom(0.1),
              icon: const Icon(Icons.add_circle_outline, size: 20),
            ),
            const VerticalDivider(width: 12, indent: 9, endIndent: 9),
            TextButton(
              onPressed: () => _setViewFit('Page'),
              child: Text(_t('সম্পূর্ণ পৃষ্ঠা', 'Full Page')),
            ),
            TextButton(
              onPressed: () => _setViewFit('Width'),
              child: Text(_t('পৃষ্ঠার প্রস্থ', 'Page Width')),
            ),
            TextButton(
              onPressed: () => _setViewFit('Actual'),
              child: const Text('100%'),
            ),
          ],
        ),
      ),
    );
  }

  void _setViewFit(String mode) {
    setState(() {
      viewFit = mode;
      zoomLevel = 1.0;
    });
    _pageTransformController.value = Matrix4.identity();
    scheduleSave();
  }

  void _saveLayoutChange(VoidCallback change) {
    setState(change);
    scheduleSave();
  }

  void _applyMarginPreset(String preset) {
    final value = switch (preset) {
      'Narrow' => 0.5,
      'Moderate' => 0.75,
      'Wide' => 1.25,
      _ => 1.0,
    };

    _saveLayoutChange(() {
      marginPreset = preset;
      marginTop = value;
      marginBottom = value;
      marginLeft = value;
      marginRight = value;
    });
  }

  Future<void> _showCustomMarginsDialog() async {
    final topController = TextEditingController(
      text: marginTop.toStringAsFixed(2),
    );
    final bottomController = TextEditingController(
      text: marginBottom.toStringAsFixed(2),
    );
    final leftController = TextEditingController(
      text: marginLeft.toStringAsFixed(2),
    );
    final rightController = TextEditingController(
      text: marginRight.toStringAsFixed(2),
    );

    final values = await showDialog<List<double>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Custom Margins (inches)')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _ribbonLabel('Top')),
              ),
              TextField(
                controller: bottomController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _ribbonLabel('Bottom')),
              ),
              TextField(
                controller: leftController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _ribbonLabel('Left')),
              ),
              TextField(
                controller: rightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _ribbonLabel('Right')),
              ),
              const SizedBox(height: 8),
              const Text(
                'প্রতিটি মার্জিন ০.২৫ থেকে ২.৫০ ইঞ্চির মধ্যে দিন।',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ribbonLabel('Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = [
                double.tryParse(topController.text.trim()),
                double.tryParse(bottomController.text.trim()),
                double.tryParse(leftController.text.trim()),
                double.tryParse(rightController.text.trim()),
              ];
              final hasInvalidMargin = parsed.any((value) {
                if (value == null) return true;
                return !value.isFinite || value < 0.25 || value > 2.5;
              });
              if (hasInvalidMargin) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(_t('সঠিক মার্জিনের মান দিন।', 'Enter valid margin values.'))),
                );
                return;
              }
              Navigator.pop(dialogContext, parsed.cast<double>());
            },
            child: Text(_ribbonLabel('Apply')),
          ),
        ],
      ),
    );

    topController.dispose();
    bottomController.dispose();
    leftController.dispose();
    rightController.dispose();

    if (values == null || !mounted) return;

    final dimensions = _pageDimensions;
    final pageWidthInches = dimensions.width / 96;
    final pageHeightInches = dimensions.height / 96;
    if (values[0] + values[1] >= pageHeightInches - 1 ||
        values[2] + values[3] >= pageWidthInches - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('মার্জিনের যোগফল পৃষ্ঠার আকারের তুলনায় বেশি।', 'The combined margins are too large for this page size.')),
        ),
      );
      return;
    }

    _saveLayoutChange(() {
      marginPreset = 'Custom';
      marginTop = values[0];
      marginBottom = values[1];
      marginLeft = values[2];
      marginRight = values[3];
    });
  }
  
  Widget buildLayoutRibbon() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F6FA),
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ribbonLabel('Page Size'), style: const TextStyle(fontSize: 11)),
              DropdownButton<String>(
                value: pageSize,
                items: [
                  const DropdownMenuItem(value: 'A4', child: Text('A4')),
                  const DropdownMenuItem(value: 'A5', child: Text('A5')),
                  DropdownMenuItem(value: 'Letter', child: Text(_ribbonLabel('Letter'))),
                  DropdownMenuItem(value: 'Legal', child: Text(_ribbonLabel('Legal'))),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _saveLayoutChange(() => pageSize = value);
                },
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ribbonLabel('Orientation'), style: const TextStyle(fontSize: 11)),
              DropdownButton<String>(
                value: pageOrientation,
                items: [
                  DropdownMenuItem(value: 'Portrait', child: Text(_ribbonLabel('Portrait'))),
                  DropdownMenuItem(value: 'Landscape', child: Text(_ribbonLabel('Landscape'))),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _saveLayoutChange(() => pageOrientation = value);
                },
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ribbonLabel('Margins'), style: const TextStyle(fontSize: 11)),
              PopupMenuButton<String>(
                tooltip: _ribbonLabel('Page Margins'),
                onSelected: (value) {
                  if (value == 'Custom') {
                    _showCustomMarginsDialog();
                  } else {
                    _applyMarginPreset(value);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'Normal', child: Text('${_ribbonLabel('Normal')} — 1.00"')),
                  PopupMenuItem(value: 'Narrow', child: Text('${_ribbonLabel('Narrow')} — 0.50"')),
                  PopupMenuItem(value: 'Moderate', child: Text('${_ribbonLabel('Moderate')} — 0.75"')),
                  PopupMenuItem(value: 'Wide', child: Text('${_ribbonLabel('Wide')} — 1.25"')),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'Custom', child: Text(_ribbonLabel('Custom Margins...'))),
                ],
                child: Chip(
                  avatar: const Icon(Icons.border_outer, size: 17),
                  label: Text(_ribbonLabel(marginPreset)),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () {
              _saveLayoutChange(() {
                pageSize = 'A4';
                pageOrientation = 'Portrait';
                marginPreset = 'Normal';
                marginTop = 1.0;
                marginBottom = 1.0;
                marginLeft = 1.0;
                marginRight = 1.0;
              });
            },
            icon: const Icon(Icons.restart_alt),
            label: Text(_ribbonLabel('Reset')),
          ),
        ],
      ),
    );
  }

  void insertTextAtSelection(String text) {
    final selection = quillController.selection;
    final start = selection.start;
    final length = selection.end - selection.start;

    quillController.replaceText(
      start,
      length,
      text,
      TextSelection.collapsed(
        offset: start + text.length,
      ),
    );
  }

  Future<void> insertHyperlink() async {
    final selection = quillController.selection;

    if (selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('প্রথমে যে লেখায় Link দিতে চান সেটি নির্বাচন করুন।', 'Select the text you want to turn into a link first.')),
        ),
      );
      return;
    }

    final controller = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_ribbonLabel('Insert Hyperlink')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://example.com',
            labelText: _t('ওয়েবসাইটের ঠিকানা', 'Website URL'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_ribbonLabel('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: Text(_ribbonLabel('Insert')),
          ),
        ],
      ),
    );

    controller.dispose();

    if (url == null || url.isEmpty) return;

    final parsedUrl = Uri.tryParse(url);

    if (parsedUrl == null ||
        !['http', 'https'].contains(parsedUrl.scheme) ||
        parsedUrl.host.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('সঠিক Website URL দিন।', 'Enter a valid website URL.')),
        ),
      );
      return;
    }

    quillController.formatText(
      selection.start,
      selection.end - selection.start,
      Attribute.fromKeyValue('link', url),
    );
  }
  
  Widget buildInsertRibbon() {
    final now = DateTime.now();
    final currentDate =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';

    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F6FA),
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => insertTextAtSelection(currentDate),
            icon: const Icon(Icons.calendar_today),
            label: Text(_t('তারিখ', 'Date')),
          ),
          ElevatedButton.icon(
            onPressed: insertWriterTable,
            icon: const Icon(Icons.table_chart),
            label: Text(_t('টেবিল', 'Table')),
          ),
          ElevatedButton.icon(
            onPressed: insertWriterImage,
            icon: const Icon(Icons.image),
            label: Text(_t('ছবি', 'Image')),
          ),
          ElevatedButton.icon(
            onPressed: insertWriterPageBreak,
            icon: const Icon(Icons.insert_page_break),
            label: Text(_t('পৃষ্ঠা বিরতি', 'Page Break')),
          ),
          ElevatedButton.icon(
            onPressed: insertHyperlink,
            icon: const Icon(Icons.link),
            label: Text(_t('হাইপারলিংক', 'Hyperlink')),
          ),
          PopupMenuButton<String>(
            tooltip: _t('প্রতীক যোগ করুন', 'Insert Symbol'),
            onSelected: insertTextAtSelection,
            itemBuilder: (context) => const [
              PopupMenuItem(value: '©', child: Text('©  Copyright')),
              PopupMenuItem(value: '®', child: Text('®  Registered')),
              PopupMenuItem(value: '™', child: Text('™  Trademark')),
              PopupMenuItem(value: '₹', child: Text('₹  Rupee')),
              PopupMenuItem(value: '৳', child: Text('৳  Taka')),
              PopupMenuItem(value: '°', child: Text('°  Degree')),
              PopupMenuItem(value: '±', child: Text('±  Plus Minus')),
              PopupMenuItem(value: '∞', child: Text('∞  Infinity')),
              PopupMenuItem(value: '✓', child: Text('✓  Check')),
            ],
            child: Chip(
              avatar: const Icon(Icons.functions),
              label: Text(_ribbonLabel('Symbols')),
            ),
          ),
        ],
      ),
    );
  }

  void insertWriterPageBreak() {
    final selection = quillController.selection;
    final start = selection.start;
    final length = selection.end - selection.start;
    quillController.replaceText(
      start,
      length,
      BlockEmbed.custom(const WriterPageBreakEmbed()),
      TextSelection.collapsed(offset: start + 1),
    );
    scheduleSave();
  }

  Future<void> insertWriterTable() async {
    final data = await showWriterTableEditor(context);

    if (data == null || !mounted) return;

    final selection = quillController.selection;
    final start = selection.start;
    final length = selection.end - selection.start;

    quillController.replaceText(
      start,
      length,
      BlockEmbed.custom(
        WriterTableBlockEmbed.fromData(data),
      ),
      TextSelection.collapsed(offset: start + 1),
    );
  }
  
  
Future<void> insertWriterImage() async {
  final selection = quillController.selection;

  try {
    final pickedFile = await FilePicker.pickFile(
      type: FileType.image,
    );

    if (pickedFile == null || !mounted) return;

    final fileSize = pickedFile.lengthSync() ?? await pickedFile.length();
    if (!mounted) return;

    if (fileSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('ছবির ফাইলের সাইজ পড়া যায়নি।', 'Could not read the image file size.')),
        ),
      );
      return;
    }

    if (fileSize > 15 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('ছবির সর্বোচ্চ সাইজ ১৫ MB হতে পারবে।', 'Images must be 15 MB or smaller.')),
        ),
      );
      return;
    }

    final extension =
        (pickedFile.extension ?? 'png').toLowerCase();

    const allowedExtensions = [
      'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp',
    ];

    if (!allowedExtensions.contains(extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('এই ছবির ফরম্যাট সমর্থিত নয়।', 'This image format is not supported.')),
        ),
      );
      return;
    }

    final bytes = await pickedFile.readAsBytes();

    if (!mounted) return;

    final appDirectory =
        await getApplicationSupportDirectory();
    if (!mounted) return;

    final imageDirectory = Directory(
      '${appDirectory.path}/offynexbd_images',
    );

    await imageDirectory.create(recursive: true);
    if (!mounted) return;

    final savedImage = File(
      '${imageDirectory.path}/'
      'offynex_${DateTime.now().microsecondsSinceEpoch}.'
      '$extension',
    );

    await savedImage.writeAsBytes(bytes, flush: true);
    if (!mounted) return;

    final start = selection.start;
    final length = selection.end - selection.start;

    quillController.replaceText(
      start,
      length,
      BlockEmbed.image(savedImage.path),
      TextSelection.collapsed(offset: start + 1),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('ছবি ডকুমেন্টে যুক্ত হয়েছে।', 'Image added to the document.')),
        ),
      );
    }
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('ছবি যুক্ত করা যায়নি: $error', 'Could not add image: $error')),
      ),
    );
  }
}
  
  Future<void> editWriterTable(
    BuildContext editorContext,
    Map<String, dynamic> data,
    int offset,
  ) async {
    final updatedData = await showWriterTableEditor(
      editorContext,
      initialData: data,
    );

    if (updatedData == null || !mounted) return;

    quillController.replaceText(
      offset,
      1,
      BlockEmbed.custom(
        WriterTableBlockEmbed.fromData(updatedData),
      ),
      TextSelection.collapsed(offset: offset + 1),
    );
  }
  
  @override
  void dispose() {
    saveTimer?.cancel();

    final title = titleController.text;
    final content = quillController.document.toDelta().toJson();
    final pageLayout = _pageLayoutToJson();
    _captureRevisionIfNeeded();
    final writerMeta = _writerMetaToJson();
    final id = widget.document['id'];

    quillController.removeListener(onEditorChanged);

    // আগের Save শেষ হওয়ার পর সর্বশেষ লেখা সংরক্ষণ হবে।
    saveQueue = saveQueue
        .catchError((Object error) {})
        .then((_) async {
          final documents = await loadDocuments();

          final index = documents.indexWhere(
            (item) => item['id'] == id,
          );

          if (index == -1) return;

          documents[index] = {
            ...documents[index],
            'title': title,
            'content': content,
            'pageLayout': pageLayout,
            'writerMeta': writerMeta,
            'updated': DateTime.now().toIso8601String(),
          };

          await storeDocuments(documents);
        })
        .catchError((Object error) {});

    _pageTransformController.dispose();
    editorFocusNode.dispose();
    titleController.dispose();
    quillController.dispose();

    super.dispose();
  }
    

  @override
  Widget build(BuildContext context) {
    // কিবোর্ড খোলা থাকলে লেখার জায়গা সর্বোচ্চ রাখতে উপরের ও নিচের
    // অপ্রয়োজনীয় বার সরিয়ে শুধু ছোট ribbon ও formatting toolbar রাখা হয়।
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: (focusMode || keyboardVisible) ? null : AppBar(
        backgroundColor: const Color(0xFF185C3B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: titleController,
          onChanged: (_) => scheduleSave(),
          maxLines: 1,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: _t('ডকুমেন্টের নাম', 'Document name'),
            hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(vertical: 5),
          ),
        ),
        actions: [
          IconButton(tooltip: _t('সব নির্বাচন', 'Select all'), onPressed: selectAllText, icon: const Icon(Icons.select_all)),
          IconButton(tooltip: _t('সংরক্ষণ', 'Save'), onPressed: () => saveDocument(), icon: const Icon(Icons.save_outlined)),
          IconButton(tooltip: _t('ডকুমেন্ট খালি করুন', 'Clear document'), onPressed: clearDocument, icon: const Icon(Icons.delete_outline)),
          IconButton(
             tooltip: _t('ফোকাস মোড', 'Focus mode'),
             onPressed: () {
               setState(() => focusMode = !focusMode);
               scheduleSave();
             },
             icon: const Icon(Icons.center_focus_strong),
           ),
        ],
      ),
      body: Column(
        children: [
          if (!focusMode) Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (keyboardVisible) ...[
                // তিন লাইনের কমপ্যাক্ট এডিটিং হেডার: ডকুমেন্ট নাম, ট্যাব, টুল।
                Container(
                  height: 30,
                  color: const Color(0xFF185C3B),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: titleController,
                    onChanged: (_) => scheduleSave(),
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: _t('ডকুমেন্টের নাম', 'Document name'),
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      contentPadding: EdgeInsets.zero,
                      prefixIcon: const Icon(
                        Icons.description_outlined,
                        color: Colors.white70,
                        size: 16,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 25,
                        minHeight: 24,
                      ),
                    ),
                  ),
                ),
                // Keyboard-open order: document name, ribbon tabs, formatting tools.
                buildRibbonTabs(),
                SizedBox(
                  height: 32,
                  child: ClipRect(
                    child: QuillSimpleToolbar(
                      controller: quillController,
                      config: const QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        showFontFamily: false,
                        showFontSize: false,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showAlignmentButtons: true,
                        showListNumbers: true,
                        showListBullets: true,
                        showIndent: true,
                        showUndo: true,
                        showRedo: true,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                buildRibbonTabs(),
                if (selectedRibbonTab == 0) ...[
                buildFileRibbon(),
                ] else if (selectedRibbonTab == 1) ...[
                buildHomeRibbon(),
                Container(
                  color: Colors.white,
                  child: QuillSimpleToolbar(
                    controller: quillController,
                    config: const QuillSimpleToolbarConfig(
                      multiRowsDisplay: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showBoldButton: false,
                      showItalicButton: false,
                      showUnderLineButton: false,
                      showAlignmentButtons: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showIndent: true,
                      showUndo: true,
                      showRedo: true,
                    ),
                  ),
                ),
              ] else if (selectedRibbonTab == 2) ...[
                buildInsertRibbon(),
              ] else if (selectedRibbonTab == 3) ...[
                buildDesignRibbon(),
              ] else if (selectedRibbonTab == 4) ...[
                buildLayoutRibbon(),
              ] else if (selectedRibbonTab == 5) ...[
                buildReferencesRibbon(),
              ] else if (selectedRibbonTab == 6) ...[
                buildReviewRibbon(),
              ] else if (selectedRibbonTab == 7) ...[
                buildViewRibbon(),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'এই ট্যাবে এখন কোনো অতিরিক্ত টুল নেই।',
                    ),
                  ),
                ),
              ],
              ],
            ],
          ),
          if (showRuler && !focusMode && !keyboardVisible) _rulerWidget(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final page = _pageDimensions;
                final layout = WriterViewportLayout.calculate(
                  pageWidth: page.width,
                  pageHeight: page.height,
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  viewFit: viewFit,
                  zoom: zoomLevel,
                );
                final availableWidth = layout.availableWidth;
                final scale = layout.scale;
                final displayWidth = page.width * scale;
                final displayHeight = page.height * scale;
                final pageContentWidth = math.max(
                  1,
                  page.width - (marginLeft + marginRight) * 96,
                ).toDouble();
                final pageContentHeight = math.max(
                  1,
                  page.height - (marginTop + marginBottom) * 96,
                ).toDouble();
                final contentHeight = WriterContentMetrics.estimateHeight(
                  delta: quillController.document.toDelta().toJson(),
                  maxWidth: pageContentWidth,
                  pageContentHeight: pageContentHeight,
                  textDirection: Directionality.of(context),
                );
                final estimatedPageCount = math.max(
                  1,
                  (contentHeight / pageContentHeight).ceil(),
                );
                final documentCanvasHeight =
                    displayHeight * estimatedPageCount;

                return InteractiveViewer(
                  transformationController: _pageTransformController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  constrained: false,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(120),
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.hardEdge,
                  onInteractionEnd: _handlePageInteractionEnd,
                  child: SizedBox(
                    width: math.max(availableWidth, displayWidth),
                    height: documentCanvasHeight + 24,
                    child: Center(
                      child: Container(
                        key: const ValueKey('writer-page-canvas'),
                        width: displayWidth,
                        height: documentCanvasHeight,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        child: Stack(
                          children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _WriterPagesPainter(
                                    pageWidth: displayWidth,
                                    pageHeight: displayHeight,
                                    pageCount: estimatedPageCount,
                                    pageColor: Color(pageBackgroundColorValue),
                                    showBorder: showPageBorder,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    marginLeft * 96 * scale,
                                    marginTop * 96 * scale,
                                    marginRight * 96 * scale,
                                    marginBottom * 96 * scale,
                                  ),
                                  child: QuillEditor.basic(
                                    controller: quillController,
                                    focusNode: editorFocusNode,
                                    config: QuillEditorConfig(
                                      expands: true,
                                      padding: EdgeInsets.zero,
                                      placeholder: _t('এখানে আপনার লেখা শুরু করুন...', 'Start writing here...'),
                                      embedBuilders: [
                                        WriterTableEmbedBuilder(
                                          onEdit: editWriterTable,
                                        ),
                                        WriterImageEmbedBuilder(),
                                        WriterPageBreakEmbedBuilder(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!keyboardVisible) _buildViewportControls(),
          if (showStatusBar && !keyboardVisible) Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OFFYNEXTheme.border))),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.article_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 7),
                Text(
                  _t('শব্দ: $wordCount', 'Words: $wordCount'),
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                Icon(
                  isSaved ? Icons.save : Icons.sync,
                  size: 15,
                  color: isSaved ? OFFYNEXTheme.teal : const Color(0xFFE59A32),
                ),
                const SizedBox(width: 5),
                Text(
                  isSaved ? _t('ডিভাইসে সংরক্ষিত', 'Saved on device') : _t('সংরক্ষণ হচ্ছে...', 'Saving...'),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

    
class _WriterHeaderFooterDialog extends StatefulWidget {
  final String initialHeader;
  final String initialFooter;
  final bool isBangla;

  const _WriterHeaderFooterDialog({
    required this.initialHeader,
    required this.initialFooter,
    required this.isBangla,
  });

  @override
  State<_WriterHeaderFooterDialog> createState() =>
      _WriterHeaderFooterDialogState();
}

class _WriterHeaderFooterDialogState
    extends State<_WriterHeaderFooterDialog> {
  late final TextEditingController _headerController;
  late final TextEditingController _footerController;

  String _t(String bn, String en) => widget.isBangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _headerController = TextEditingController(text: widget.initialHeader);
    _footerController = TextEditingController(text: widget.initialFooter);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_t('Header ও Footer', 'Header and Footer')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _headerController,
            maxLength: 180,
            decoration: InputDecoration(
              labelText: _t('Header লেখা', 'Header text'),
              hintText: _t('প্রতিটি পৃষ্ঠার উপরে', 'Top of each page'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _footerController,
            maxLength: 180,
            decoration: InputDecoration(
              labelText: _t('Footer লেখা', 'Footer text'),
              hintText: _t('পৃষ্ঠা নম্বর: {page} / মোট: {pages}', 'Page {page} of {pages}'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _t('পৃষ্ঠা নম্বরের জন্য {page} এবং মোট পৃষ্ঠার জন্য {pages} লিখুন।', 'Use {page} for the current page and {pages} for total pages.'),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('বাতিল', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, [
            _headerController.text.trim(),
            _footerController.text.trim(),
          ]),
          child: Text(_t('সংরক্ষণ', 'Save')),
        ),
      ],
    );
  }
}

class _WriterPagesPainter extends CustomPainter {
  final double pageWidth;
  final double pageHeight;
  final int pageCount;
  final Color pageColor;
  final bool showBorder;

  const _WriterPagesPainter({
    required this.pageWidth,
    required this.pageHeight,
    required this.pageCount,
    required this.pageColor,
    required this.showBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = pageColor
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFD9E0EA)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var index = 0; index < pageCount; index++) {
      final rect = Rect.fromLTWH(
        0,
        index * pageHeight,
        pageWidth,
        pageHeight,
      );
      final path = Path()..addRect(rect);
      canvas.drawShadow(path, const Color(0x33000000), 3, true);
      canvas.drawRect(rect, fill);
      if (showBorder) {
        canvas.drawRect(rect, border);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WriterPagesPainter oldDelegate) {
    return pageWidth != oldDelegate.pageWidth ||
        pageHeight != oldDelegate.pageHeight ||
        pageCount != oldDelegate.pageCount ||
        pageColor != oldDelegate.pageColor ||
        showBorder != oldDelegate.showBorder;
  }
}

class _WriterPrintPreviewScreen extends StatefulWidget {
  final String fileName;
  final PdfPageFormat initialPageFormat;
  final Future<Uint8List> Function(PdfPageFormat) buildPdf;
  final QuillController controller;
  final FocusNode focusNode;
  final bool isBangla;
  final Future<void> Function() onSave;
  final Future<void> Function(
    BuildContext,
    Map<String, dynamic>,
    int,
  ) onEditTable;

  const _WriterPrintPreviewScreen({
    required this.fileName,
    required this.initialPageFormat,
    required this.buildPdf,
    required this.controller,
    required this.focusNode,
    required this.isBangla,
    required this.onSave,
    required this.onEditTable,
  });

  @override
  State<_WriterPrintPreviewScreen> createState() =>
      _WriterPrintPreviewScreenState();
}

class _WriterPrintPreviewScreenState
    extends State<_WriterPrintPreviewScreen> {
  bool _editing = false;
  bool _saving = false;
  int _previewRevision = 0;

  String _t(String bn, String en) => widget.isBangla ? bn : en;

  Future<void> _saveAndPreview() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
        _previewRevision++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('সংরক্ষণ ব্যর্থ হয়েছে: $error', 'Save failed: $error'))),
      );
    }
  }

  void _openEditor() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF2),
      appBar: AppBar(
        title: Text(_editing
            ? _t('প্রিভিউ থেকে সম্পাদনা', 'Edit from preview')
            : _t('প্রিন্ট প্রিভিউ', 'Print Preview')),
        actions: [
          if (_editing)
            IconButton(
              tooltip: _t('সংরক্ষণ করে প্রিভিউ', 'Save and preview'),
              onPressed: _saving ? null : _saveAndPreview,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            )
          else
            IconButton(
              tooltip: _t('ডকুমেন্ট সম্পাদনা', 'Edit document'),
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_outlined),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _editing
          ? Column(
              children: [
                Material(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_document, color: Color(0xFF185C3B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t(
                              'এখানকার পরিবর্তন মূল ডকুমেন্টে সংরক্ষিত হবে',
                              'Changes here are made to the original document',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : _saveAndPreview,
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(_t('প্রিভিউ', 'Preview')),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: QuillEditor.basic(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      config: QuillEditorConfig(
                        expands: true,
                        padding: EdgeInsets.zero,
                        placeholder: _t(
                          'এখানে সম্পাদনা করুন...',
                          'Edit your document here...',
                        ),
                        embedBuilders: [
                          WriterTableEmbedBuilder(
                            onEdit: widget.onEditTable,
                          ),
                          WriterImageEmbedBuilder(),
                          WriterPageBreakEmbedBuilder(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : PdfPreview(
              key: ValueKey(_previewRevision),
              build: widget.buildPdf,
              initialPageFormat: widget.initialPageFormat,
              canChangePageFormat: true,
              canChangeOrientation: true,
              allowPrinting: true,
              allowSharing: true,
              pdfFileName: '${widget.fileName}.pdf',
              maxPageWidth: 700,
            ),
    );
  }
}

class WriterImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final imagePath =
        embedContext.node.value.data as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (dialogContext) {
              return Dialog(
                child: InteractiveViewer(
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('ছবি পাওয়া যায়নি।'),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.broken_image,
              size: 60,
            );
          },
        ),
      ),
    );
  }
}

