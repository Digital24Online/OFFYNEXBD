import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/services.dart';
import 'writer_table.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

const String documentsKey = 'offynex_writer_documents';

Future<List<Map<String, dynamic>>> loadDocuments() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(documentsKey);

  if (raw == null) return [];

  try {
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (_) {
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
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
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

  const WriterEditorScreen({
    super.key,
    required this.document,
  });

  @override
  State<WriterEditorScreen> createState() =>
      _WriterEditorScreenState();
}

class _WriterEditorScreenState extends State<WriterEditorScreen> {
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

  // Writer-এর অতিরিক্ত নথি, রিভিউ ও ভিউ সেটিংস।
  double zoomLevel = 1.0;
  bool showRuler = true;
  bool showStatusBar = true;
  bool showPageBorder = true;
  bool focusMode = false;
  bool captureRevisions = false;
  List<Map<String, dynamic>> writerComments = [];
  List<Map<String, dynamic>> writerCitations = [];
  List<Map<String, dynamic>> writerRevisions = [];

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
      zoomLevel = (savedMeta['zoom'] is num)
          ? (savedMeta['zoom'] as num).toDouble().clamp(0.6, 1.5).toDouble()
          : 1.0;
      showRuler = savedMeta['showRuler'] is bool
          ? savedMeta['showRuler'] as bool : true;
      showStatusBar = savedMeta['showStatusBar'] is bool
          ? savedMeta['showStatusBar'] as bool : true;
      showPageBorder = savedMeta['showPageBorder'] is bool
          ? savedMeta['showPageBorder'] as bool : true;
      captureRevisions = savedMeta['captureRevisions'] is bool
          ? savedMeta['captureRevisions'] as bool : false;
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
        'showRuler': showRuler,
        'showStatusBar': showStatusBar,
        'showPageBorder': showPageBorder,
        'captureRevisions': captureRevisions,
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
        writerRevisions.last['deltaJson'] == encodedDelta) return;
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
    final lines = writerCitations.map((item) =>
      '${item['author']} (${item['year']}). ${item['title']}.').join('\n');
    insertTextAtSelection('\n\nReferences\n$lines\n');
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
          decoration: const InputDecoration(hintText: 'নোট লিখুন'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Insert')),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.isEmpty || !mounted) return;
    final number = writerComments.length + writerCitations.length + 1;
    insertTextAtSelection('[$number]');
    final kind = endnote ? 'Endnote' : 'Footnote';
    final end = quillController.document.length - 1;
    quillController.replaceText(
      end, 0, '\n\n$kind $number: $note',
      TextSelection.collapsed(offset: end + kind.length + note.length + 5),
    );
    scheduleSave();
  }

  void insertTableOfContents() {
    final lines = quillController.document.toPlainText().split('\n');
    final headings = lines
        .where((line) => line.trimLeft().startsWith('#'))
        .map((line) => line.replaceFirst(RegExp(r'^\s*#+\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (headings.isEmpty) {
      _showMessage('সূচিপত্র তৈরির আগে শিরোনামের শুরুতে # লিখুন।');
      return;
    }
    insertTextAtSelection('\n\nTable of Contents\n${headings.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}\n');
  }

  Future<void> insertCaption() async {
    final controller = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insert Caption'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Caption')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Insert')),
        ],
      ),
    );
    controller.dispose();
    if (caption != null && caption.isNotEmpty && mounted) {
      insertTextAtSelection('\nFigure: $caption\n');
    }
  }
  
  Future<void> addReviewComment() async {
    final selection = quillController.selection;
    final selectedText = selection.isCollapsed ? '' : quillController.getPlainText();
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Comment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (selectedText.isNotEmpty) Text('নির্বাচিত লেখা: $selectedText', maxLines: 3, overflow: TextOverflow.ellipsis),
          TextField(controller: controller, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Comment')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (comment == null || comment.isEmpty || !mounted) return;
    writerComments.add({
      'text': comment,
      'selectedText': selectedText,
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
                    return ListTile(
                      title: Text(item['text']?.toString() ?? ''),
                      subtitle: Text(item['selectedText']?.toString() ?? ''),
                      trailing: IconButton(
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
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Future<void> findAndReplace() async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    final replaceAll = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Find and Replace'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: findController, decoration: const InputDecoration(labelText: 'Find')),
          TextField(controller: replaceController, decoration: const InputDecoration(labelText: 'Replace with')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Find only')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Replace All')),
        ],
      ),
    );
    final find = findController.text;
    final replacement = replaceController.text;
    findController.dispose(); replaceController.dispose();
    if (find.isEmpty || !mounted) return;
    final plain = quillController.document.toPlainText();
    if (replaceAll == true) {
      final offsets = <int>[];
      var offset = 0;
      while (true) {
        final found = plain.indexOf(find, offset);
        if (found < 0) break;
        offsets.add(found);
        offset = found + find.length;
      }
      for (final found in offsets.reversed) {
        quillController.replaceText(
          found, find.length, replacement,
          TextSelection.collapsed(offset: found + replacement.length),
        );
      }
      _showMessage('${offsets.length}টি জায়গায় পরিবর্তন হয়েছে।');
    } else {
      final found = plain.indexOf(find);
      if (found < 0) {
        _showMessage('লেখাটি পাওয়া যায়নি।');
      } else {
        quillController.updateSelection(
          TextSelection(baseOffset: found, extentOffset: found + find.length),
          ChangeSource.local,
        );
        editorFocusNode.requestFocus();
      }
    }
  }

  Future<void> showRevisionHistory() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revision Snapshots'),
        content: SizedBox(
          width: 420,
          child: writerRevisions.isEmpty
              ? const Text('Revision সংরক্ষণ চালু করুন; এরপর Save হলে snapshot তৈরি হবে।')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: writerRevisions.length,
                  itemBuilder: (context, index) {
                    final item = writerRevisions[writerRevisions.length - 1 - index];
                    final date = item['savedAt']?.toString() ?? '';
                    final content = item['content']?.toString() ?? '';
                    return ListTile(
                      title: Text(date),
                      subtitle: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Restore this snapshot?'),
                            content: const Text('বর্তমান লেখা প্রতিস্থাপিত হবে।'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          final savedDelta = item['delta'];
                          if (savedDelta is List) {
                            final restoredDocument = Document.fromJson(
                              savedDelta
                                  .map((op) => Map<String, dynamic>.from(op as Map))
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
                              0, quillController.document.length - 1, content,
                              const TextSelection.collapsed(offset: 0),
                            );
                          }
                          updateWordCount(quillController.document.toPlainText());
                          scheduleSave();
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
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
        _ribbonButton(Icons.drive_file_rename_outline, 'Rename', renameCurrentDocument),
        _ribbonButton(Icons.copy, 'Copy Text', copyDocumentText),
        _ribbonButton(Icons.info_outline, 'Document Info', showDocumentInfo),
        _ribbonButton(Icons.delete_outline, 'Clear', clearDocument),
        _ribbonButton(Icons.close, 'Close', () => Navigator.maybePop(context)),
      ]);

  Widget buildReferencesRibbon() => _ribbonPanel([
        _ribbonButton(Icons.format_list_numbered, 'Table of Contents', insertTableOfContents),
        _ribbonButton(Icons.format_quote, 'Citation', insertCitation),
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
        FilterChip(label: const Text('Focus Mode'), selected: focusMode, onSelected: (v) => setState(() => focusMode = v)),
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
  const tabs = [
    'File',
    'Home',
    'Insert',
    'Layout',
    'References',
    'Review',
    'View',
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
          decoration: const InputDecoration(labelText: 'Size in points (6–200)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || !parsed.isFinite || parsed < 6 || parsed > 200) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('৬ থেকে ২০০ পয়েন্টের মধ্যে সাইজ দিন।')),
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
    'Sans Serif': 'sans-serif',
    'Serif': 'serif',
    'Monospace': 'monospace',
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
          IconButton(tooltip: 'Focus mode', onPressed: () => setState(() => focusMode = !focusMode), icon: const Icon(Icons.center_focus_strong)),
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
                buildLayoutRibbon(),
              ] else if (selectedRibbonTab == 4) ...[
                buildReferencesRibbon(),
              ] else if (selectedRibbonTab == 5) ...[
                buildReviewRibbon(),
              ] else if (selectedRibbonTab == 6) ...[
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
                final availableWidth = constraints.maxWidth > 24
                    ? constraints.maxWidth - 24
                    : constraints.maxWidth;
                final zoomedWidth = page.width * zoomLevel;
                final displayWidth = zoomedWidth < availableWidth
                    ? zoomedWidth
                    : availableWidth;
                final scale = displayWidth / page.width;

                return Center(
                  child: Container(
                    width: displayWidth,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: EdgeInsets.fromLTRB(
                      marginLeft * 96 * scale,
                      marginTop * 96 * scale,
                      marginRight * 96 * scale,
                      marginBottom * 96 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: showPageBorder ? Border.all(color: const Color(0xFFD9E0EA)) : null,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                    errorBuilder: (_, __, ___) {
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
          errorBuilder: (_, __, ___) {
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

