import 'package:material_ui/material_ui.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final TextEditingController titleController =
      TextEditingController(text: 'Untitled Document');

  final TextEditingController documentController =
      TextEditingController();

  double fontSize = 18;
  int wordCount = 0;

  void updateWordCount(String text) {
    final words = text.trim().isEmpty
        ? <String>[]
        : text.trim().split(RegExp(r'\s+'));

    setState(() {
      wordCount = words.length;
    });
  }

  void selectAllText() {
    documentController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: documentController.text.length,
    );
  }

  void clearDocument() {
    documentController.clear();
    updateWordCount('');
  }

  @override
  void dispose() {
    titleController.dispose();
    documentController.dispose();
    super.dispose();
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
          Container(
            color: const Color(0xFFEAF0F8),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 5,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Decrease font size',
                  onPressed: () {
                    setState(() {
                      if (fontSize > 10) fontSize -= 1;
                    });
                  },
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '${fontSize.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Increase font size',
                  onPressed: () {
                    setState(() {
                      if (fontSize < 40) fontSize += 1;
                    });
                  },
                  icon: const Icon(Icons.add),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: selectAllText,
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('Select all'),
                ),
              ],
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
              child: TextField(
                controller: documentController,
                onChanged: updateWordCount,
                expands: true,
                minLines: null,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.6,
                  color: const Color(0xFF202124),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'এখানে আপনার লেখা শুরু করুন...',
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
                const Text(
                  'OFFYNEX Writer',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
