import 'package:material_ui/material_ui.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Explicit hard page break stored as a stable Quill custom block.
class WriterPageBreakEmbed extends CustomBlockEmbed {
  static const String embedType = 'offynexbd-writer-page-break';
  const WriterPageBreakEmbed() : super(embedType, 'page');
}

/// Visible editing marker for an explicit page break.
class WriterPageBreakEmbedBuilder extends EmbedBuilder {
  @override
  String get key => WriterPageBreakEmbed.embedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Divider(color: Color(0xFF8A98AA), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('PAGE BREAK', style: TextStyle(
            color: Color(0xFF52647A), fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 1.1,
          )),
        ),
        Expanded(child: Divider(color: Color(0xFF8A98AA), thickness: 1)),
      ]),
    );
  }
}
