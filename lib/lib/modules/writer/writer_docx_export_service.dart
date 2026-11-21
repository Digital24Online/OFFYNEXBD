import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'writer_page_break.dart';

/// Converts supported OFFYNEX Writer Quill content into a real DOCX file.
/// Images are embedded as bytes; device-local file paths are never exported.
class WriterDocxExportService {
  static Future<List<int>> build({
    required String title,
    required List<Map<String, dynamic>> delta,
    Map<String, dynamic>? pageLayout,
    String headerText = '',
    String footerText = '',
  }) async {
    // The document title is separate metadata in Writer. Avoid adding it as a
    // second visible heading when the user's first body paragraph already is
    // the same title; otherwise keep the convenient title heading on export.
    final firstParagraph = StringBuffer();
    var firstParagraphEnded = false;
    for (final operation in delta) {
      final insert = operation['insert'];
      if (insert is String && !firstParagraphEnded) {
        final newline = insert.indexOf('\n');
        firstParagraph.write(newline < 0 ? insert : insert.substring(0, newline));
        if (newline >= 0) firstParagraphEnded = true;
      } else if (insert is Map && !firstParagraphEnded) {
        if (insert.containsKey(WriterPageBreakEmbed.embedType) ||
            insert.containsKey('offynexbd-writer-table') ||
            insert.containsKey('image')) {
          firstParagraphEnded = true;
        }
      }
      if (firstParagraphEnded) break;
    }
    final titleAlreadyInBody = firstParagraph.toString().trim() == title.trim();
    final html = StringBuffer();
    if (!titleAlreadyInBody && title.trim().isNotEmpty) {
      html.write('<h1>${_escape(title)}</h1>');
    }
    final line = StringBuffer();
    final listTags = <String>[];
    final listItemOpen = <bool>[];
    var pageBreakCount = 0;

    void closeDeepestListLevel() {
      if (listTags.isEmpty) return;
      if (listItemOpen.last) html.write('</li>');
      html.write('</${listTags.removeLast()}>');
      listItemOpen.removeLast();
    }

    void closeAllLists() {
      while (listTags.isNotEmpty) {
        closeDeepestListLevel();
      }
    }

    void flushLine(Map<String, dynamic> attributes) {
      final content = line.toString();
      line.clear();
      final heading = attributes['header'];
      final list = attributes['list'];
      if (list == 'bullet' || list == 'ordered') {
        final tag = list == 'bullet' ? 'ul' : 'ol';
        final rawIndent = attributes['indent'];
        final requestedLevel = rawIndent is num
            ? rawIndent.toInt()
            : int.tryParse(rawIndent?.toString() ?? '') ?? 0;
        final level = requestedLevel.clamp(0, 8).toInt();

        while (listTags.length - 1 > level) {
          closeDeepestListLevel();
        }
        if (listTags.isNotEmpty && listTags.length - 1 == level &&
            listTags.last != tag) {
          closeDeepestListLevel();
        }
        if (listTags.isNotEmpty && listTags.length - 1 == level &&
            listItemOpen.last) {
          html.write('</li>');
          listItemOpen[listItemOpen.length - 1] = false;
        }

        while (listTags.length <= level) {
          html.write('<$tag>');
          listTags.add(tag);
          listItemOpen.add(false);
        }
        html.write('<li>$content');
        listItemOpen[listItemOpen.length - 1] = true;
      } else {
        closeAllLists();
        final tag = heading == 1 ? 'h1' : heading == 2 ? 'h2' : heading == 3 ? 'h3' : 'p';
        html.write('<$tag>$content</$tag>');
      }
    }

    for (final operation in delta) {
      final insert = operation['insert'];
      final rawAttributes = operation['attributes'];
      final attributes = rawAttributes is Map
          ? Map<String, dynamic>.from(rawAttributes)
          : <String, dynamic>{};

      if (insert is String) {
        final segments = insert.split('\n');
        for (var index = 0; index < segments.length; index++) {
          if (segments[index].isNotEmpty) {
            line.write(_styledText(segments[index], attributes));
          }
          if (index < segments.length - 1) flushLine(attributes);
        }
      } else if (insert is Map) {
        if (insert.containsKey('image')) {
          final path = insert['image']?.toString() ?? '';
          final file = File(path);
          if (!await file.exists()) throw StateError('Writer image file is missing: $path');
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) throw StateError('Writer image is empty: $path');
          final extension = path.split('.').last.toLowerCase();
          final mime = switch (extension) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'webp' => 'image/webp',
            'gif' => 'image/gif',
            'bmp' => 'image/bmp',
            _ => 'image/png',
          };
          html.write('<p>${line.toString()}<img src="data:$mime;base64:${base64Encode(bytes)}" /></p>');
          line.clear();
        } else if (insert.containsKey(WriterPageBreakEmbed.embedType)) {
          closeAllLists();
          if (line.isNotEmpty) flushLine(const <String, dynamic>{});
          html.write('<p>OFFYNEXBD_WRITER_PAGE_BREAK_${pageBreakCount++}</p>');
        } else if (insert.containsKey('offynexbd-writer-table')) {
          html.write(line.toString());
          line.clear();
          html.write(_tableHtml(insert['offynexbd-writer-table']?.toString() ?? '{}'));
        }
      }
    }
    if (line.length > 0) flushLine(<String, dynamic>{});
    closeAllLists();

    final nodes = await DocxParser.fromHtml(html.toString());
    final document = DocxBuiltDocument(elements: nodes);
    final originalBytes = await DocxExporter().exportToBytes(document);
    final fontSegments = <_WriterFontSegment>[];
    for (final operation in delta) {
      final insert = operation['insert'];
      final attributes = operation['attributes'];
      if (insert is! String || attributes is! Map) continue;
      final rawFont = attributes['font']?.toString().trim() ?? '';
      if (rawFont.isEmpty) continue;
      final font = rawFont == 'serif'
          ? 'Noto Serif Bengali'
          : rawFont == 'sans-serif'
              ? 'Noto Sans Bengali'
              : rawFont.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      if (font.isEmpty) continue;
      for (final part in insert.split('\\n').where((part) => part.isNotEmpty)) {
        fontSegments.add(_WriterFontSegment(part, font));
      }
    }
    final bytes = _applyPageAndHeaderFooter(
      originalBytes,
      pageLayout: pageLayout ?? const {},
      headerText: headerText,
      footerText: footerText,
      pageBreakCount: pageBreakCount,
      fontSegments: fontSegments,
    );
    if (bytes.isEmpty || bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw StateError('DOCX export did not produce a valid ZIP-based document.');
    }
    return bytes;
  }


  static List<int> _applyPageAndHeaderFooter(
    List<int> source, {
    required Map<String, dynamic> pageLayout,
    required String headerText,
    required String footerText,
    int pageBreakCount = 0,
    List<_WriterFontSegment> fontSegments = const [],
  }) {
    final input = ZipDecoder().decodeBytes(source);
    final files = <String, List<int>>{};
    for (final file in input.files.where((item) => item.isFile)) {
      files[file.name] = file.readBytes() ?? <int>[];
    }

    final sizes = <String, List<int>>{
      'A4': [11906, 16838],
      'A5': [8391, 11906],
      'Letter': [12240, 15840],
      'Legal': [12240, 20160],
    };
    final selected = sizes[pageLayout['pageSize']?.toString()] ?? sizes['A4']!;
    final landscape = pageLayout['orientation'] == 'Landscape';
    final width = landscape ? selected[1] : selected[0];
    final height = landscape ? selected[0] : selected[1];
    int margin(String key) {
      final raw = pageLayout[key];
      final inches = raw is num ? raw.toDouble() : 1.0;
      return (inches.clamp(0.25, 2.5) * 1440).round();
    }

    final relationshipsPath = 'word/_rels/document.xml.rels';
    var relationships = files.containsKey(relationshipsPath)
        ? utf8.decode(files[relationshipsPath]!)
        : '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>';
    final contentTypesPath = '[Content_Types].xml';
    var contentTypes = utf8.decode(files[contentTypesPath] ?? <int>[]);
    var nextId = 1;
    for (final match in RegExp(r'Id="rId(\d+)"').allMatches(relationships)) {
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value >= nextId) nextId = value + 1;
    }

    final sectionReferences = StringBuffer();
    void addPart(String kind, String text) {
      if (text.trim().isEmpty) return;
      final id = 'rId${nextId++}';
      final fileName = kind == 'header' ? 'header1.xml' : 'footer1.xml';
      final relationType = kind == 'header'
          ? 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header'
          : 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer';
      relationships = relationships.replaceFirst(
        '</Relationships>',
        '<Relationship Id="$id" Type="$relationType" Target="$fileName"/></Relationships>',
      );
      sectionReferences.write('<w:$kind w:type="default" r:id="$id"/>');
      final element = kind == 'header' ? 'hdr' : 'ftr';
      files['word/$fileName'] = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:$element xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:p>${_headerFooterRuns(text)}</w:p>'
        '</w:$element>',
      );
      final partType = kind == 'header'
          ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml';
      contentTypes = contentTypes.replaceFirst(
        '</Types>',
        '<Override PartName="/word/$fileName" ContentType="$partType"/></Types>',
      );
    }

    addPart('header', headerText);
    addPart('footer', footerText);
    final section = '<w:sectPr>${sectionReferences.toString()}'
        '<w:pgSz w:w="$width" w:h="$height"${landscape ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="${margin('top')}" w:bottom="${margin('bottom')}" '
        'w:left="${margin('left')}" w:right="${margin('right')}" w:header="720" w:footer="720" w:gutter="0"/>'
        '</w:sectPr>';
    var documentXml = utf8.decode(files['word/document.xml'] ?? <int>[]);
    documentXml = _applyCustomRunFonts(documentXml, fontSegments);
    for (var index = 0; index < pageBreakCount; index++) {
      final marker = 'OFFYNEXBD_WRITER_PAGE_BREAK_$index';
      final markerPattern = RegExp('<w:t(?: [^>]*)?>${RegExp.escape(marker)}</w:t>');
      if (!markerPattern.hasMatch(documentXml)) {
        throw StateError('DOCX page break marker $index was not found.');
      }
      documentXml = documentXml.replaceFirst(markerPattern, '<w:br w:type="page"/>');
    }
    final sectionPattern = RegExp(r'<w:sectPr\b[\s\S]*?</w:sectPr>|<w:sectPr\b[^>]*/>');
    if (sectionPattern.hasMatch(documentXml)) {
      documentXml = documentXml.replaceFirst(sectionPattern, section);
    } else {
      documentXml = documentXml.replaceFirst('</w:body>', '$section</w:body>');
    }
    if (!documentXml.contains('<w:sectPr>')) {
      throw StateError('DOCX page settings could not be written.');
    }
    files['word/document.xml'] = utf8.encode(documentXml);
    files[relationshipsPath] = utf8.encode(relationships);
    if (contentTypes.isNotEmpty) files[contentTypesPath] = utf8.encode(contentTypes);

    final output = Archive();
    for (final entry in files.entries) {
      output.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return ZipEncoder().encodeBytes(output);
  }


  /// Converts Writer's {page}/{pages} placeholders into live Word fields.
  /// Ordinary text remains XML-escaped and editable in the header/footer.
  static String _headerFooterRuns(String value) {
    final output = StringBuffer();
    final fields = RegExp(r'\{(page|pages)\}');
    var cursor = 0;
    var wroteAny = false;
    for (final match in fields.allMatches(value)) {
      if (match.start > cursor) {
        output.write('<w:r><w:t xml:space="preserve">${_escape(value.substring(cursor, match.start))}</w:t></w:r>');
        wroteAny = true;
      }
      final instruction = match.group(1) == 'page' ? ' PAGE ' : ' NUMPAGES ';
      output.write('<w:fldSimple w:instr="$instruction"><w:r><w:t>1</w:t></w:r></w:fldSimple>');
      wroteAny = true;
      cursor = match.end;
    }
    if (cursor < value.length || !wroteAny) {
      output.write('<w:r><w:t xml:space="preserve">${_escape(value.substring(cursor))}</w:t></w:r>');
    }
    return output.toString();
  }

  static String _styledText(String value, Map<String, dynamic> attributes) {
    var text = _escape(value);
    if (attributes['bold'] == true) text = '<strong>$text</strong>';
    if (attributes['italic'] == true) text = '<em>$text</em>';
    if (attributes['underline'] == true) text = '<u>$text</u>';
    if (attributes['strike'] == true) text = '<s>$text</s>';
    final styles = <String>[];
    final color = _safeColor(attributes['color']);
    final background = _safeColor(attributes['background']);
    final size = double.tryParse(attributes['size']?.toString() ?? '');
    if (color != null) styles.add('color:$color');
    if (background != null) styles.add('background-color:$background');
    if (size != null && size.isFinite && size >= 8 && size <= 96) {
      styles.add('font-size:${(size * 0.75).round()}px');
    }
    final font = attributes['font']?.toString().trim();
    if (font == 'serif') {
      styles.add('font-family:Noto Serif Bengali,serif');
    } else if (font == 'sans-serif') {
      styles.add('font-family:Noto Sans Bengali,sans-serif');
    } else if (font != null) {
      final safeFont = font.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      if (safeFont.isNotEmpty) styles.add('font-family:"$safeFont"');
    }
    final link = attributes['link']?.toString();
    if (link != null) {
      final uri = Uri.tryParse(link);
      if (uri != null && ['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty) {
        text = '<a href="${_escape(link)}">$text</a>';
      }
    }
    return styles.isEmpty ? text : '<span style="${styles.join(';')}">$text</span>';
  }

  static String? _safeColor(dynamic raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value) ? value : null;
  }

  static String _tableHtml(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['rows'] is! List) return '';
      final rows = decoded['rows'] as List;
      if (rows.isEmpty) return '';
      final html = StringBuffer('<table border="1">');
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (row is! List) continue;
        html.write('<tr>');
        for (final cell in row) {
          final tag = rowIndex == 0 && decoded['headerRow'] == true ? 'th' : 'td';
          html.write('<$tag>${_escape(cell?.toString() ?? '')}</$tag>');
        }
        html.write('</tr>');
      }
      html.write('</table>');
      return html.toString();
    } catch (_) {
      return '<p>[Table data unavailable]</p>';
    }
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
  /// Applies Quill font-family attributes directly to WordprocessingML runs.
  /// The HTML parser can drop custom CSS font families, so the final DOCX
  /// runs are repaired while preserving their text and other formatting.
  static String _applyCustomRunFonts(
    String documentXml,
    List<_WriterFontSegment> fontSegments,
  ) {
    if (fontSegments.isEmpty) return documentXml;
    final pending = List<bool>.filled(fontSegments.length, true);
    final paragraphPattern = RegExp(r'<w:p\\b[^>]*>[\\s\\S]*?</w:p>');
    final runPattern = RegExp(r'<w:r\\b[^>]*>[\\s\\S]*?</w:r>');
    final textPattern = RegExp(r'<w:t(?:\\s[^>]*)?>([\\s\\S]*?)</w:t>');
    return documentXml.replaceAllMapped(paragraphPattern, (paragraphMatch) {
      final paragraph = paragraphMatch.group(0)!;
      final runs = runPattern.allMatches(paragraph).toList();
      final runTexts = <String>[];
      final runStarts = <int>[];
      final plain = StringBuffer();
      for (final run in runs) {
        runStarts.add(plain.length);
        final runText = StringBuffer();
        for (final textMatch in textPattern.allMatches(run.group(0)!)) {
          runText.write(_decodeXmlText(textMatch.group(1)!));
        }
        final value = runText.toString();
        runTexts.add(value);
        plain.write(value);
      }
      final paragraphText = plain.toString();
      final replacements = <int, String>{};
      for (var fontIndex = 0; fontIndex < fontSegments.length; fontIndex++) {
        if (!pending[fontIndex]) continue;
        final segment = fontSegments[fontIndex];
        if (segment.text.isEmpty) continue;
        final start = paragraphText.indexOf(segment.text);
        if (start < 0) continue;
        final end = start + segment.text.length;
        for (var runIndex = 0; runIndex < runs.length; runIndex++) {
          final runStart = runStarts[runIndex];
          final runEnd = runStart + runTexts[runIndex].length;
          if (runTexts[runIndex].isEmpty || runEnd <= start || runStart >= end) continue;
          replacements[runIndex] = _setRunFont(
            runs[runIndex].group(0)!,
            segment.font,
          );
        }
        pending[fontIndex] = false;
      }
      if (replacements.isEmpty) return paragraph;
      final output = StringBuffer();
      var cursor = 0;
      for (var runIndex = 0; runIndex < runs.length; runIndex++) {
        final match = runs[runIndex];
        output.write(paragraph.substring(cursor, match.start));
        output.write(replacements[runIndex] ?? match.group(0)!);
        cursor = match.end;
      }
      output.write(paragraph.substring(cursor));
      return output.toString();
    });
  }

  static String _setRunFont(String runXml, String font) {
    final escaped = _escape(font);
    final fontProperties = '<w:rFonts w:ascii="$escaped" w:hAnsi="$escaped" '
        'w:eastAsia="$escaped" w:cs="$escaped"/>';
    final runProperties = RegExp(r'<w:rPr\\b[^>]*>');
    final existingProperties = runProperties.firstMatch(runXml);
    if (existingProperties == null) {
      final runStart = RegExp(r'<w:r\\b[^>]*>').firstMatch(runXml);
      if (runStart == null) return runXml;
      return runXml.replaceRange(runStart.end, runStart.end, '<w:rPr>$fontProperties</w:rPr>');
    }
    final propertiesEnd = runXml.indexOf('</w:rPr>', existingProperties.end);
    if (propertiesEnd < 0) return runXml;
    var properties = runXml.substring(existingProperties.end, propertiesEnd);
    properties = properties.replaceAll(
      RegExp(r'<w:rFonts\\b[^>]*/>|<w:rFonts\\b[^>]*>[\\s\\S]*?</w:rFonts>'),
      '',
    );
    properties = '$fontProperties$properties';
    return runXml.replaceRange(existingProperties.end, propertiesEnd, properties);
  }

  static String _decodeXmlText(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');


}

class _WriterFontSegment {
  const _WriterFontSegment(this.text, this.font);
  final String text;
  final String font;
}
