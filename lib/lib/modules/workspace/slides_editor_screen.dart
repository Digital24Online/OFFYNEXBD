import 'package:material_ui/material_ui.dart';

import 'slides_document_codec.dart';
import '../../theme/offynex_theme.dart';

/// Text-slide editor. Legacy newline-based presentations are upgraded only
/// when the user saves, so opening and cancelling never changes stored data.
class SlidesEditorScreen extends StatefulWidget {
  const SlidesEditorScreen({
    super.key,
    required this.isBangla,
    required this.title,
    required this.content,
  });

  final bool isBangla;
  final String title;
  final String content;

  @override
  State<SlidesEditorScreen> createState() => _SlidesEditorScreenState();
}

class _SlideDraft {
  _SlideDraft(this.id, String text) : controller = TextEditingController(text: text);
  final int id;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _SlidesEditorScreenState extends State<SlidesEditorScreen> {
  late final TextEditingController _titleController;
  late final List<_SlideDraft> _slides;
  int _nextId = 0;

  bool get _bn => widget.isBangla;
  String _t(String bn, String en) => _bn ? bn : en;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    List<String> initial;
    try {
      initial = SlidesDocumentCodec.decode(widget.content);
    } on FormatException {
      // Do not discard an unrecognized document. Keep its raw content editable
      // as one slide so the user can explicitly save a repaired copy.
      initial = [widget.content];
    }
    if (initial.isEmpty) initial = [''];
    _slides = initial.map((text) => _SlideDraft(_nextId++, text)).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final slide in _slides) {
      slide.dispose();
    }
    super.dispose();
  }

  void _addSlide() {
    if (_slides.length >= SlidesDocumentCodec.maxSlides) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('সর্বোচ্চ ২০০টি স্লাইড যোগ করা যাবে।', 'A presentation can contain up to 200 slides.')),
      ));
      return;
    }
    setState(() => _slides.add(_SlideDraft(_nextId++, '')));
  }

  void _duplicateSlide(int index) {
    if (_slides.length >= SlidesDocumentCodec.maxSlides) return;
    final source = _slides[index];
    setState(() => _slides.insert(index + 1, _SlideDraft(_nextId++, source.controller.text)));
  }

  void _deleteSlide(int index) {
    if (_slides.length == 1) {
      _slides[index].controller.clear();
      setState(() {});
      return;
    }
    setState(() {
      _slides.removeAt(index).dispose();
    });
  }

  void _reorderSlides(int oldIndex, int newIndex) {
    // ReorderableListView.onReorderItem already adjusts newIndex after removal.
    setState(() {
      final slide = _slides.removeAt(oldIndex);
      _slides.insert(newIndex, slide);
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('প্রেজেন্টেশনের নাম লিখুন।', 'Enter a presentation title.')),
      ));
      return;
    }
    try {
      final content = SlidesDocumentCodec.encode(
        _slides.map((slide) => slide.controller.text).toList(growable: false),
      );
      Navigator.pop(context, <String, String>{'title': title, 'content': content});
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        title: Text(_t('স্লাইড এডিটর', 'Slides editor')),
        backgroundColor: OFFYNEXTheme.canvas,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_t('সংরক্ষণ', 'Save')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: _t('প্রেজেন্টেশনের নাম', 'Presentation title'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_t('স্লাইডসমূহ', 'Slides')} (${_slides.length}/200)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addSlide,
                    icon: const Icon(Icons.add),
                    label: Text(_t('স্লাইড যোগ', 'Add slide')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _slides.length,
                onReorderItem: _reorderSlides,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Card(
                    key: ValueKey<int>(slide.id),
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle, color: OFFYNEXTheme.muted),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _t('স্লাইড ', 'Slide ') + (index + 1).toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: _t('কপি করুন', 'Duplicate slide'),
                                onPressed: () => _duplicateSlide(index),
                                icon: const Icon(Icons.copy_outlined),
                              ),
                              IconButton(
                                tooltip: _t('মুছুন', 'Delete slide'),
                                onPressed: () => _deleteSlide(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          TextField(
                            key: ValueKey<String>('slides-editor-field-${slide.id}'),
                            controller: slide.controller,
                            minLines: 3,
                            maxLines: 7,
                            maxLength: 10000,
                            decoration: InputDecoration(
                              hintText: _t('এই স্লাইডের লেখা লিখুন', 'Enter this slide content'),
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
