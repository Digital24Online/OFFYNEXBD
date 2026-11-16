import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
      source: ChangeSource.local,
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
      source: ChangeSource.local,
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
            source: ChangeSource.local,
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
      source: ChangeSource.local,
    );
  }
  
  @override
  void dispose() {
    saveTimer?.cancel();

    final title = titleController.text;
    final content = quillController.document.toDelta().toJson();
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildRibbonTabs(),
              if (selectedRibbonTab == 1) ...[
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
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'এই ট্যাবের টুলগুলো পরবর্তী ধাপে যুক্ত হবে।',
                    ),
                  ),
                ),
              ],
            ],
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

