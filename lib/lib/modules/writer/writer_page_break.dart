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
    return Container(
      height: 28,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFF8A98AA), width: 1),
        ),
      ),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'PAGE BREAK',
          style: TextStyle(
            color: Color(0xFF52647A),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
