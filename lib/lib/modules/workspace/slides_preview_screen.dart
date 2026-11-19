import 'package:material_ui/material_ui.dart';

import '../../theme/offynex_theme.dart';

/// Read-only, full-screen preview for the current text-based slide format.
class SlidesPreviewScreen extends StatefulWidget {
  const SlidesPreviewScreen({
    super.key,
    required this.title,
    required this.slides,
    required this.isBangla,
  });

  final String title;
  final List<String> slides;
  final bool isBangla;

  @override
  State<SlidesPreviewScreen> createState() => _SlidesPreviewScreenState();
}

class _SlidesPreviewScreenState extends State<SlidesPreviewScreen> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim().isEmpty ? 'OFFYNEXBD' : widget.title.trim();
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101827),
        foregroundColor: Colors.white,
        title: Text(
          widget.isBangla ? 'স্লাইড প্রিভিউ' : 'Presentation preview',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${_index + 1} / ${widget.slides.length}',
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 24,
                                offset: Offset(0, 12)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: OFFYNEXTheme.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  )),
                              const SizedBox(height: 8),
                              Text(
                                widget.isBangla ? 'স্লাইড ${index + 1}' : 'SLIDE ${index + 1}',
                                style: const TextStyle(
                                  color: OFFYNEXTheme.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const Divider(height: 22),
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Text(widget.slides[index],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: OFFYNEXTheme.ink,
                                        fontSize: 22,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      )),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text('OFFYNEXBD',
                                  style: TextStyle(
                                    color: OFFYNEXTheme.muted.withValues(alpha: 0.7),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  )),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _index == 0 ? null : () => _controller.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(widget.isBangla ? 'আগেরটি' : 'Previous'),
                  ),
                  Text(
                    widget.isBangla
                        ? '${_index + 1} / ${widget.slides.length} স্লাইড'
                        : 'Slide ${_index + 1} of ${widget.slides.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  OutlinedButton.icon(
                    onPressed: _index == widget.slides.length - 1 ? null : () => _controller.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.chevron_right),
                    label: Text(widget.isBangla ? 'পরেরটি' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
