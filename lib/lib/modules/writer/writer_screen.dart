import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
  bool isSaved = true;
  Future<void> saveQueue = Future.value();
  Timer? saveTimer;

  @override
  void initState() {
    super.initState();

    editorFocusNode = FocusNode();
    titleController = TextEditingController(
      text: widget.document['title']?.toString() ??
          'Untitled Document',
    );

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
    updateWordCount(quillController.document.toPlainText());
    scheduleSave();

    if (mounted) {
      setState(() {});
    }
  }

  void scheduleSave() {
    saveTimer?.cancel();

    if (mounted) {
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
    final id = widget.document['id'];

    saveQueue = saveQueue.then((_) async {
      final documents = await loadDocuments();

      final index = documents.indexWhere(
        (item) => item['id'] == id,
      );

      if (index == -1) return;

      documents[index] = {
        ...documents[index],
        'title': title,
        'content': content,
        'updated': DateTime.now().toIso8601String(),
      };

      await storeDocuments(documents);

      if (mounted) {
        setState(() => isSaved = true);
      }
    });

    return saveQueue;
  }

  void selectAllText() {
    final length = quillController.document.length - 1;

    quillController.updateSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: length,
      ),
      ChangeSource.local,
    );
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

    @override
    void dispose() {
    saveTimer?.cancel();

    final title = titleController.text;
    final content = quillController.document.toDelta().toJson();
    final id = widget.document['id'];

    quillController.removeListener(onEditorChanged);

    saveQueue = saveQueue.catchError((_) {}).then((_) async {
      final documents = await loadDocuments();

      final index = documents.indexWhere(
        (item) => item['id'] == id,
      );

      if (index == -1) return;

      documents[index] = {
        ...documents[index],
        'title': title,
        'content': content,
        'updated': DateTime.now().toIso8601String(),
      };

      await storeDocuments(documents);
    });

    editorFocusNode.dispose();
    titleController.dispose();
    quillController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('OFFYNEX Writer'),
        actions: [
          IconButton(
            tooltip: 'Select all',
            onPressed: selectAllText,
            icon: const Icon(Icons.select_all),
          ),
          IconButton(
            tooltip: 'Clear document',
            onPressed: clearDocument,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
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

          // আসল Rich Text Formatting Toolbar
          Container(
            color: const Color(0xFFEAF0F8),
            child: QuillSimpleToolbar(
              controller: quillController,
              config: const QuillSimpleToolbarConfig(
                multiRowsDisplay: true,
                showFontFamily: true,
                showFontSize: true,
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

          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QuillEditor.basic(
                controller: quillController,
                focusNode: editorFocusNode,
                config: const QuillEditorConfig(
                  expands: true,
                  padding: EdgeInsets.zero,
                  placeholder: 'এখানে আপনার লেখা শুরু করুন...',
                ),
              ),
            ),
          ),

          Container(
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
