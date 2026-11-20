import 'package:material_ui/material_ui.dart';

/// Offline slide editor with editable slide text, ordering and duplication.
/// The saved newline-delimited content remains compatible with legacy records.
class SlidesEditorScreen extends StatefulWidget {
  const SlidesEditorScreen({
    super.key,
    required this.title,
    required this.content,
    required this.isBangla,
  });

  final String title;
  final String content;
  final bool isBangla;

  @override
  State<SlidesEditorScreen> createState() => _SlidesEditorScreenState();
}

class _SlidesEditorScreenState extends State<SlidesEditorScreen> {
  late final TextEditingController _titleController;
  late final List<TextEditingController> _slides;

  bool get _bn => widget.isBangla;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    final initial = widget.content
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    _slides = initial
        .map((value) => TextEditingController(text: value))
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _slides) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _editSlide(int index) async {
    final controller = TextEditingController(text: _slides[index].text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_bn ? 'স্লাইডের লেখা সম্পাদনা' : 'Edit slide text'),
        content: TextField(
          key: const Key('slide-content-input'),
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: 12000,
          decoration: InputDecoration(
            hintText: _bn ? 'স্লাইডের বিষয়বস্তু লিখুন' : 'Enter slide content',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_bn ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_bn ? 'সংরক্ষণ' : 'Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _slides[index].text = result);
    }
    controller.dispose();
  }

  void _addSlide() {
    setState(() => _slides.add(TextEditingController()));
    _editSlide(_slides.length - 1);
  }

  void _duplicateSlide(int index) {
    setState(() => _slides.insert(
      index + 1,
      TextEditingController(text: _slides[index].text),
    ));
  }

  void _deleteSlide(int index) {
    final removed = _slides.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _save() {
    final title = _titleController.text.trim();
    final content = _slides
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn ? 'প্রেজেন্টেশনের নাম লিখুন।' : 'Enter a presentation title.'),
      ));
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn ? 'কমপক্ষে একটি স্লাইডে লেখা দিন।' : 'Add content to at least one slide.'),
      ));
      return;
    }
    Navigator.pop(context, <String, String>{'title': title, 'content': content});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_bn ? 'স্লাইড এডিটর' : 'Slides editor'),
        actions: [
          TextButton.icon(
            key: const Key('save-slides'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_bn ? 'সংরক্ষণ' : 'Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('presentation-title'),
              controller: _titleController,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: _bn ? 'প্রেজেন্টেশনের নাম' : 'Presentation title',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _bn ? 'স্লাইডসমূহ' : 'Slides',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${_slides.length}'),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: const Key('add-slide'),
                  onPressed: _addSlide,
                  icon: const Icon(Icons.add),
                  label: Text(_bn ? 'স্লাইড যোগ' : 'Add slide'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _slides.isEmpty
                ? Center(child: Text(_bn ? 'প্রথম স্লাইড যোগ করুন।' : 'Add your first slide.'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _slides.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final moved = _slides.removeAt(oldIndex);
                        _slides.insert(newIndex, moved);
                      });
                    },
                    itemBuilder: (context, index) => Card(
                      key: ValueKey('slide-${index}-${_slides[index].hashCode}'),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(
                          _slides[index].text.trim().isEmpty
                              ? (_bn ? 'খালি স্লাইড' : 'Empty slide')
                              : _slides[index].text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_bn ? 'স্লাইড ${index + 1}' : 'Slide ${index + 1}'),
                        onTap: () => _editSlide(index),
                        trailing: PopupMenuButton<String>(
                          tooltip: _bn ? 'স্লাইডের কাজ' : 'Slide actions',
                          onSelected: (action) {
                            if (action == 'duplicate') _duplicateSlide(index);
                            if (action == 'delete') _deleteSlide(index);
                            if (action == 'edit') _editSlide(index);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(_bn ? 'সম্পাদনা' : 'Edit')),
                            PopupMenuItem(value: 'duplicate', child: Text(_bn ? 'কপি তৈরি' : 'Duplicate')),
                            PopupMenuItem(value: 'delete', child: Text(_bn ? 'মুছুন' : 'Delete')),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
