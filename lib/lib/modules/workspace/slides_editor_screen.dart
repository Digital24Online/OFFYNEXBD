import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'slides_content_codec.dart';

/// Offline slide editor with editable slide text, ordering and duplication.
/// Structured storage preserves paragraphs; legacy newline records still load.
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
    final initial = SlidesContentCodec.decode(widget.content);
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
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SlideTextDialog(
        isBangla: _bn,
        initialValue: _slides[index].text,
      ),
    );
    if (result != null && mounted && index < _slides.length) {
      setState(() => _slides[index].text = result);
    }
  }

  void _addSlide() {
    if (_slides.length >= 200) {
      _showLimitMessage();
      return;
    }
    setState(() => _slides.add(TextEditingController()));
    _editSlide(_slides.length - 1);
  }

  void _duplicateSlide(int index) {
    if (_slides.length >= 200) {
      _showLimitMessage();
      return;
    }
    setState(() => _slides.insert(
      index + 1,
      TextEditingController(text: _slides[index].text),
    ));
  }

  void _showLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_bn
          ? 'একটি প্রেজেন্টেশনে সর্বোচ্চ ২০০টি স্লাইড রাখা যাবে।'
          : 'A presentation can contain up to 200 slides.'),
    ));
  }

  void _deleteSlide(int index) {
    final removed = _slides.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _save() {
    final title = _titleController.text.trim();
    final slides = _slides
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn ? 'প্রেজেন্টেশনের নাম লিখুন।' : 'Enter a presentation title.'),
      ));
      return;
    }
    if (slides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn ? 'কমপক্ষে একটি স্লাইডে লেখা দিন।' : 'Add content to at least one slide.'),
      ));
      return;
    }
    final encoded = SlidesContentCodec.encode(slides);
    if (slides.length > 200 || utf8.encode('$title\n${slides.join('\n')}').length > SlidesContentCodec.maxTextBytes) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn
            ? 'সর্বোচ্চ ২০০টি স্লাইড এবং ৫ MB লেখা রাখা যাবে।'
            : 'A presentation is limited to 200 slides and 5 MB of text.'),
      ));
      return;
    }
    Navigator.pop(context, <String, String>{'title': title, 'content': encoded});
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
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final moved = _slides.removeAt(oldIndex);
                        _slides.insert(newIndex, moved);
                      });
                    },
                    itemBuilder: (context, index) => Card(
                      key: ValueKey('slide-$index-${_slides[index].hashCode}'),
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


class _SlideTextDialog extends StatefulWidget {
  const _SlideTextDialog({
    required this.isBangla,
    required this.initialValue,
  });

  final bool isBangla;
  final String initialValue;

  @override
  State<_SlideTextDialog> createState() => _SlideTextDialogState();
}

class _SlideTextDialogState extends State<_SlideTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;
    return AlertDialog(
      title: Text(bn ? 'স্লাইডের লেখা সম্পাদনা' : 'Edit slide text'),
      content: TextField(
        key: const Key('slide-content-input'),
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        maxLength: 12000,
        decoration: InputDecoration(
          hintText: bn ? 'স্লাইডের বিষয়বস্তু লিখুন' : 'Enter slide content',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(bn ? 'বাতিল' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(bn ? 'সংরক্ষণ' : 'Save'),
        ),
      ],
    );
  }
}
