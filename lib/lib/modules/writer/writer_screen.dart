import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/services.dart';
import 'writer_table.dart';
import 'writer_pdf_export_service.dart';
import 'writer_document_codec.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

const String documentsKey = 'offynex_writer_documents';
String? writerDataRecoveryNotice;

Future<List<Map<String, dynamic>>> loadDocuments() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(documentsKey);

  if (raw == null) return [];

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Writer library root must be a list.');
    }
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  } catch (error) {
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
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(documentsKey, jsonEncode(documents));
}

class WriterScreen extends StatefulWidget {
  final bool isBangla;
  const WriterScreen({super.key, this.isBangla = true});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  String _t(String bn, String en) => widget.isBangla ? bn : en;

  List<Map<String, dynamic>> documents = [];
  bool isLoading = true;

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
    try {
      final json = WriterDocumentCodec.encode(documents);
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-Writer-documents.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        dialogTitle: 'Export Writer documents',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Writer documents exported successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Writer export failed: $e')),
        );
      }
    }
  }

  Future<void> importDocuments() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
        throw const FormatException('Writer archive must be between 1 byte and 20 MB.');
      }
      final imported = WriterDocumentCodec.decode(
        utf8.decode(bytes, allowMalformed: false),
      );
      final existingIds = documents.map((item) => item['id']?.toString()).toSet();
      final additions = imported
          .where((item) => !existingIds.contains(item['id']))
          .toList(growable: false);
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import Writer documents?'),
          content: Text(
            '${imported.length} documents found. ${additions.length} are new. Existing documents with the same ID will be kept unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      if (additions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new Writer documents to import.')),
        );
        return;
      }
      final updated = [...documents, ...additions];
      await storeDocuments(updated);
      if (!mounted) return;
      setState(() => documents = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${additions.length} Writer documents imported.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Writer import failed: $e')),
        );
      }
    }
  }

  Future<void> addDocument() async {
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
    final controller = TextEditingController(
      text: document['title']?.toString() ?? '',
    );

    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Document name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Save'),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
          'এই ডকুমেন্টটি স্থায়ীভাবে মুছে যাবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'OFFYNEX Writer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Import documents',
            onPressed: importDocuments,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'Export documents',
            onPressed: exportDocuments,
            icon: const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addDocument,
        icon: const Icon(Icons.add),
        label: const Text('New Document'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : documents.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 65,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text('এখনো কোনো ডকুমেন্ট নেই'),
                      Text('নতুন ডকুমেন্ট তৈরি করুন'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final title =
                        document['title']?.toString() ??
                        'Untitled Document';

                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: const Icon(
                          Icons.description,
                          color: Color(0xFF168BFA),
                          size: 32,
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text('Saved on device'),
                        onTap: () => openDocument(document),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              renameDocument(document);
                            } else if (value == 'delete') {
                              deleteDocument(document);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
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
    this.isBangla = true,
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
  String viewFit = 'Page';
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
          ? (savedMeta['zoom'] as num).toDouble().clamp(0.6, 1.5).toDouble()
          : 1.0;
      viewFit = ['Page', 'Width', 'Actual'].contains(savedMeta['viewFit'])
          ? savedMeta['viewFit'] as String
          : 'Page';
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

  Future<void> saveDocument() {
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

          if (mounted) {
            setState(() => isSaved = true);
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() => isSaved = false);
          }
        });

    return saveQueue;
  }
  

  Map<String, dynamic> _writerMetaToJson() => {
        'zoom': zoomLevel,
        'fontFamily': selectedFontFamily,
        'viewFit': viewFit,
        'showRuler': showRuler,
        'showStatusBar': showStatusBar,
        'showPageBorder': showPageBorder,
        'captureRevisions': captureRevisions,
        'focusMode': focusMode,
        'comments': writerComments,
        'citations': writerCitations,
        'revisions': writerRevisions,
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
        title: const Text('Document Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('নাম: ${titleController.text}'),
            Text('শব্দ: $wordCount'),
            Text('অক্ষর: $chars'),
            Text('অনুচ্ছেদ: $paragraphs'),
            Text('মন্তব্য: ${writerComments.length}'),
            Text('উদ্ধৃতি: ${writerCitations.length}'),
            Text('সর্বশেষ সংরক্ষণ: ${widget.document['updated'] ?? 'এই সেশনে'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('বন্ধ করুন'),
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
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Document name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
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
        title: const Text('Insert Citation'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: author, decoration: const InputDecoration(labelText: 'Author / লেখক')),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title / শিরোনাম')),
            TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year / সাল')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, [author.text.trim(), title.text.trim(), year.text.trim()]), child: const Text('Insert')),
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
          title: const Text('Citation Sources / উদ্ধৃতির উৎস'),
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
                          tooltip: 'Remove source',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (confirmContext) => AlertDialog(
                                title: const Text('Remove citation source?'),
                                content: const Text(
                                  'উৎসটি তালিকা ও ভবিষ্যৎ Bibliography থেকে বাদ যাবে। ডকুমেন্টের আগে বসানো citation text মুছবে না।',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(confirmContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(confirmContext, true),
                                    child: const Text('Remove'),
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
              child: const Text('Close / বন্ধ'),
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
        title: Text(endnote ? 'Insert Endnote' : 'Insert Footnote'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'নোট লিখুন',
            labelText: 'Note',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Insert'),
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
        title: const Text('Insert Caption'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Caption'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Insert'),
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
        title: const Text('New Comment'),
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
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
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
        title: const Text('Document Comments'),
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
                        tooltip: 'Delete comment',
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
            child: const Text('Close'),
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
        title: const Text('Find and Replace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findController,
              decoration: const InputDecoration(labelText: 'Find'),
            ),
            TextField(
              controller: replaceController,
              decoration:
                  const InputDecoration(labelText: 'Replace with'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'find'),
            child: const Text('Find Next'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            child: const Text('Replace'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'all'),
            child: const Text('Replace All'),
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
          title: const Text('Revision Snapshots'),
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
                              title: const Text('Restore this snapshot?'),
                              content: const Text(
                                'বর্তমান লেখা প্রতিস্থাপিত হবে।',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    confirmContext,
                                    false,
                                  ),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    confirmContext,
                                    true,
                                  ),
                                  child: const Text('Restore'),
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
                          tooltip: 'Delete snapshot',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (confirmContext) => AlertDialog(
                                title: const Text('Delete snapshot?'),
                                content: const Text(
                                  'এই Revision স্থায়ীভাবে মুছে যাবে।',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(
                                      confirmContext,
                                      false,
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(
                                      confirmContext,
                                      true,
                                    ),
                                    child: const Text('Delete'),
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
                      title: const Text('Clear revision history?'),
                      content: const Text(
                        'সব সংরক্ষিত Revision মুছে যাবে। ডকুমেন্টের বর্তমান লেখা মুছবে না।',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(confirmContext, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(confirmContext, true),
                          child: const Text('Clear History'),
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
                child: const Text('Clear History'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
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
        _ribbonButton(Icons.delete_outline, 'Clear', clearDocument),
        _ribbonButton(Icons.close, 'Close', () => Navigator.maybePop(context)),
      ]);

  Widget buildDesignRibbon() => _ribbonPanel([
        PopupMenuButton<int>(
          tooltip: 'Page Color',
          onSelected: (value) => _saveLayoutChange(() => pageBackgroundColorValue = value),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0xFFFFFFFF, child: Text('White')),
            PopupMenuItem(value: 0xFFFFF8E7, child: Text('Ivory')),
            PopupMenuItem(value: 0xFFEAF4FF, child: Text('Light Blue')),
            PopupMenuItem(value: 0xFFF1F3F5, child: Text('Light Gray')),
            PopupMenuItem(value: 0xFFEAF7EA, child: Text('Light Green')),
            PopupMenuItem(value: 0xFFFFF9DB, child: Text('Light Yellow')),
          ],
          child: const Chip(
            avatar: Icon(Icons.palette_outlined, size: 18),
            label: Text('Page Color'),
          ),
        ),
        FilterChip(
          label: const Text('Page Border'),
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
          label: const Text('Capture revisions'),
          selected: captureRevisions,
          onSelected: (value) {
            setState(() => captureRevisions = value);
            scheduleSave();
          },
        ),
      ]);

  Widget buildViewRibbon() => _ribbonPanel([
        Wrap(spacing: 6, children: [
          ChoiceChip(label: const Text('Full Page'), selected: viewFit == 'Page', onSelected: (_) => _setViewFit('Page')),
          ChoiceChip(label: const Text('Page Width'), selected: viewFit == 'Width', onSelected: (_) => _setViewFit('Width')),
          ChoiceChip(label: const Text('100%'), selected: viewFit == 'Actual', onSelected: (_) => _setViewFit('Actual')),
        ]),
        SizedBox(
          width: 180,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Zoom ${(zoomLevel * 100).round()}%'),
            Slider(
              value: zoomLevel,
              min: 0.6,
              max: 1.5,
              divisions: 18,
              onChanged: (value) => setState(() => zoomLevel = value),
              onChangeEnd: (_) => scheduleSave(),
            ),
          ]),
        ),
        FilterChip(label: const Text('Ruler'), selected: showRuler, onSelected: (v) { setState(() => showRuler = v); scheduleSave(); }),
        FilterChip(label: const Text('Page Border'), selected: showPageBorder, onSelected: (v) { setState(() => showPageBorder = v); scheduleSave(); }),
        FilterChip(label: const Text('Status Bar'), selected: showStatusBar, onSelected: (v) { setState(() => showStatusBar = v); scheduleSave(); }),
        FilterChip(
           label: const Text('Focus Mode'),
           selected: focusMode,
           onSelected: (value) {
             setState(() => focusMode = value);
             scheduleSave();
           },
         ),
      ]);
  
  Widget _ribbonPanel(List<Widget> children) => Container(
        width: double.infinity,
        color: const Color(0xFFF3F6FA),
        padding: const EdgeInsets.all(10),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children),
      );

  Widget _ribbonButton(IconData icon, String label, VoidCallback action) =>
      OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 18),
        label: Text(label),
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
        title: const Text('Clear document?'),
        content: const Text('সব লেখা মুছে ফেলতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
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
    _t('ফাইল', 'File'),
    _t('হোম', 'Home'),
    _t('ইনসার্ট', 'Insert'),
    _t('ডিজাইন', 'Design'),
    _t('লেআউট', 'Layout'),
    _t('রেফারেন্স', 'References'),
    _t('রিভিউ', 'Review'),
    _t('ভিউ', 'View'),
  ];

  return Container(
    color: Colors.white,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedRibbonTab == index;

          return InkWell(
            onTap: () {
              setState(() {
                selectedRibbonTab = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected
                        ? const Color(0xFF168BFA)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF168BFA)
                      : Colors.black87,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
  }
  
  
Future<void> showCustomFontSizeDialog() async {
    final controller = TextEditingController(text: selectedFontSize);
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Font Size'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Size in points (8–72)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || !parsed.isFinite || parsed < 8 || parsed > 72) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text(_t('৮ থেকে ৭২ পয়েন্টের মধ্যে সাইজ দিন।', 'Enter a font size between 8 and 72 points.'))),
                );
                return;
              }
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Apply'),
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
    padding: const EdgeInsets.all(10),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Font Family
        DropdownButton<String>(
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
          onPressed: showCustomFontSizeDialog,
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Custom Size'),
        ),

        // Bold
        IconButton(
          tooltip: 'Bold',
          onPressed: () {
            quillController.formatSelection(Attribute.bold);
          },
          icon: const Icon(Icons.format_bold),
        ),

        // Italic
        IconButton(
          tooltip: 'Italic',
          onPressed: () {
            quillController.formatSelection(Attribute.italic);
          },
          icon: const Icon(Icons.format_italic),
        ),

        // Underline
        IconButton(
          tooltip: 'Underline',
          onPressed: () {
            quillController.formatSelection(Attribute.underline);
          },
          icon: const Icon(Icons.format_underline),
        ),

        // Strikethrough
        IconButton(
          tooltip: 'Strikethrough',
          onPressed: () {
            quillController.formatSelection(
              Attribute.strikeThrough,
            );
          },
          icon: const Icon(Icons.format_strikethrough),
        ),

        // Red Text
        IconButton(
          tooltip: 'Red Text',
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
          tooltip: 'Yellow Highlight',
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

  Future<void> editHeaderFooter() async {
    final header = TextEditingController(text: headerText);
    final footer = TextEditingController(text: footerText);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Header ও Footer', 'Header and Footer')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: header,
              maxLength: 180,
              decoration: InputDecoration(
                labelText: _t('Header লেখা', 'Header text'),
                hintText: _t('প্রতিটি পৃষ্ঠার উপরে', 'Top of each page'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: footer,
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, [header.text.trim(), footer.text.trim()]),
            child: Text(_t('সংরক্ষণ', 'Save')),
          ),
        ],
      ),
    );
    final nextHeader = header.text.trim();
    final nextFooter = footer.text.trim();
    header.dispose();
    footer.dispose();
    if (result == null || !mounted) return;
    setState(() {
      headerText = nextHeader;
      footerText = nextFooter;
    });
    await saveDocument();
    _showMessage(_t('Header ও Footer সংরক্ষিত হয়েছে।', 'Header and footer saved.'));
  }

  Future<void> openPrintPreview() async {
    await saveDocument();
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
        ),
      ),
    );
  }

  Future<void> printDocument() async {
    await saveDocument();
    if (!mounted) return;
    try {
      await Printing.layoutPdf(
        name: titleController.text.trim().isEmpty
            ? 'OFFYNEXBD-Document.pdf'
            : '${titleController.text.trim()}.pdf',
        format: _selectedPdfFormat,
        onLayout: _buildWriterPdf,
      );
    } catch (error) {
      _showMessage('প্রিন্ট তৈরি করা যায়নি: $error');
    }
  }

  void _setViewFit(String mode) {
    setState(() {
      viewFit = mode;
      zoomLevel = 1.0;
    });
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
        title: const Text('Custom Margins (inches)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Top'),
              ),
              TextField(
                controller: bottomController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Bottom'),
              ),
              TextField(
                controller: leftController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Left'),
              ),
              TextField(
                controller: rightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Right'),
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
            child: const Text('Cancel'),
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
                  const SnackBar(content: Text('সঠিক মার্জিনের মান দিন।')),
                );
                return;
              }
              Navigator.pop(dialogContext, parsed.cast<double>());
            },
            child: const Text('Apply'),
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
        const SnackBar(
          content: Text('মার্জিনের যোগফল পৃষ্ঠার আকারের তুলনায় বেশি।'),
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
              const Text('Page Size', style: TextStyle(fontSize: 11)),
              DropdownButton<String>(
                value: pageSize,
                items: const [
                  DropdownMenuItem(value: 'A4', child: Text('A4')),
                  DropdownMenuItem(value: 'A5', child: Text('A5')),
                  DropdownMenuItem(value: 'Letter', child: Text('Letter')),
                  DropdownMenuItem(value: 'Legal', child: Text('Legal')),
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
              const Text('Orientation', style: TextStyle(fontSize: 11)),
              DropdownButton<String>(
                value: pageOrientation,
                items: const [
                  DropdownMenuItem(value: 'Portrait', child: Text('Portrait')),
                  DropdownMenuItem(value: 'Landscape', child: Text('Landscape')),
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
              const Text('Margins', style: TextStyle(fontSize: 11)),
              PopupMenuButton<String>(
                tooltip: 'Page Margins',
                onSelected: (value) {
                  if (value == 'Custom') {
                    _showCustomMarginsDialog();
                  } else {
                    _applyMarginPreset(value);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Normal', child: Text('Normal — 1.00"')),
                  PopupMenuItem(value: 'Narrow', child: Text('Narrow — 0.50"')),
                  PopupMenuItem(value: 'Moderate', child: Text('Moderate — 0.75"')),
                  PopupMenuItem(value: 'Wide', child: Text('Wide — 1.25"')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'Custom', child: Text('Custom Margins...')),
                ],
                child: Chip(
                  avatar: const Icon(Icons.border_outer, size: 17),
                  label: Text(marginPreset),
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
            label: const Text('Reset'),
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
        const SnackBar(
          content: Text('প্রথমে যে লেখায় Link দিতে চান সেটি নির্বাচন করুন।'),
        ),
      );
      return;
    }

    final controller = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insert Hyperlink'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            labelText: 'Website URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Insert'),
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
        const SnackBar(
          content: Text('সঠিক Website URL দিন।'),
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
            label: const Text('Date'),
          ),
          ElevatedButton.icon(
            onPressed: insertWriterTable,
            icon: const Icon(Icons.table_chart),
            label: const Text('Table'),
          ),
          ElevatedButton.icon(
            onPressed: insertWriterImage,
            icon: const Icon(Icons.image),
            label: const Text('Image'),
          ),
          ElevatedButton.icon(
            onPressed: insertHyperlink,
            icon: const Icon(Icons.link),
            label: const Text('Hyperlink'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Insert Symbol',
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
            child: const Chip(
              avatar: Icon(Icons.functions),
              label: Text('Symbols'),
            ),
          ),
        ],
      ),
    );
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
        const SnackBar(
          content: Text('ছবির ফাইলের সাইজ পড়া যায়নি।'),
        ),
      );
      return;
    }

    if (fileSize > 15 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ছবির সর্বোচ্চ সাইজ ১৫ MB হতে পারবে।'),
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
        const SnackBar(
          content: Text('এই ছবির ফরম্যাট সমর্থিত নয়।'),
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
        const SnackBar(
          content: Text('ছবি ডকুমেন্টে যুক্ত হয়েছে।'),
        ),
      );
    }
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ছবি যুক্ত করা যায়নি: $error'),
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

    editorFocusNode.dispose();
    titleController.dispose();
    quillController.dispose();

    super.dispose();
  }
    

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: focusMode ? null : AppBar(
        backgroundColor: Colors.white,
        title: const Text('OFFYNEX Writer'),
        actions: [
          IconButton(tooltip: 'Select all', onPressed: selectAllText, icon: const Icon(Icons.select_all)),
          IconButton(tooltip: 'Save', onPressed: () => saveDocument(), icon: const Icon(Icons.save_outlined)),
          IconButton(tooltip: 'Clear document', onPressed: clearDocument, icon: const Icon(Icons.delete_outline)),
          IconButton(
             tooltip: 'Focus mode',
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
          if (!focusMode) Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: TextField(
              controller: titleController,
              onChanged: (_) => scheduleSave(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Document name',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!focusMode) Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildRibbonTabs(),
              if (selectedRibbonTab == 0) ...[
                buildFileRibbon(),
                ] else if (selectedRibbonTab == 1) ...[
                buildHomeRibbon(),
                Container(
                  color: const Color(0xFFEAF0F8),
                  child: QuillSimpleToolbar(
                    controller: quillController,
                    config: const QuillSimpleToolbarConfig(
                      multiRowsDisplay: true,
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
          ),
          if (showRuler && !focusMode) _rulerWidget(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final page = _pageDimensions;
                final availableWidth = math.max(1.0, constraints.maxWidth - 24);
                final fitScale = math.min(
                  availableWidth / page.width,
                  constraints.maxHeight / page.height,
                );
                final baseScale = viewFit == 'Width'
                    ? availableWidth / page.width
                    : viewFit == 'Actual'
                        ? 1.0
                        : fitScale;
                final scale = (baseScale * zoomLevel).clamp(0.15, 2.0).toDouble();
                final displayWidth = page.width * scale;
                final displayHeight = page.height * scale;
                final plainText = quillController.document.toPlainText();
                final textPainter = TextPainter(
                  text: TextSpan(
                    text: plainText,
                    style: const TextStyle(fontSize: 16),
                  ),
                  textDirection: Directionality.of(context),
                )..layout(
                    maxWidth: math.max(
                      1,
                      page.width - (marginLeft + marginRight) * 96,
                    ),
                  );
                final pageContentHeight = math.max(
                  1,
                  page.height - (marginTop + marginBottom) * 96,
                );
                final estimatedPageCount = math.max(
                  1,
                  (textPainter.height / pageContentHeight).ceil(),
                );
                final documentCanvasHeight =
                    displayHeight * estimatedPageCount;

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(availableWidth, displayWidth),
                      height: documentCanvasHeight + 24,
                      child: Center(
                        child: Container(
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
                                      placeholder: 'এখানে আপনার লেখা শুরু করুন...',
                                      embedBuilders: [
                                        WriterTableEmbedBuilder(
                                          onEdit: editWriterTable,
                                        ),
                                        WriterImageEmbedBuilder(),
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
                  ),
                );
              },
            ),
          ),
          if (showStatusBar) Container(
            width: double.infinity,
            color: Colors.white,
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
                  'Words: $wordCount',
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                Icon(
                  isSaved ? Icons.save : Icons.sync,
                  size: 15,
                  color: isSaved ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 5),
                Text(
                  isSaved ? 'Saved on device' : 'Saving...',
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

class _WriterPrintPreviewScreen extends StatelessWidget {
  final String fileName;
  final PdfPageFormat initialPageFormat;
  final Future<Uint8List> Function(PdfPageFormat) buildPdf;

  const _WriterPrintPreviewScreen({
    required this.fileName,
    required this.initialPageFormat,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Print Preview')),
      body: PdfPreview(
        build: buildPdf,
        initialPageFormat: initialPageFormat,
        canChangePageFormat: true,
        canChangeOrientation: true,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '$fileName.pdf',
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

