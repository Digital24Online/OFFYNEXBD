import 'dart:convert';
import 'dart:io';

import 'package:docx_creator/docx_creator.dart';

/// Converts supported OFFYNEX Writer Quill content into a real DOCX file.
/// Images are embedded as bytes; device-local file paths are never exported.
class WriterDocxExportService {
  static Future<List<int>> build({
    required String title,
    required List<Map<String, dynamic>> delta,
  }) async {
    final html = StringBuffer()..write('<h1>${_escape(title)}</h1>');
    final line = StringBuffer();

    void flushLine(Map<String, dynamic> attributes) {
      final content = line.toString();
      line.clear();
      final heading = attributes['header'];
      final list = attributes['list'];
      if (list == 'bullet' || list == 'ordered') {
        final tag = list == 'bullet' ? 'ul' : 'ol';
        html.write('<$tag><li>$content</li></$tag>');
      } else {
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
        } else if (insert.containsKey('offynexbd-writer-table')) {
          html.write(line.toString());
          line.clear();
          html.write(_tableHtml(insert['offynexbd-writer-table']?.toString() ?? '{}'));
        }
      }
    }
    if (line.length > 0) flushLine(<String, dynamic>{});

    final nodes = await DocxParser.fromHtml(html.toString());
    final document = DocxBuiltDocument(elements: nodes);
    final bytes = await DocxExporter().exportToBytes(document);
    if (bytes.isEmpty || bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw StateError('DOCX export did not produce a valid ZIP-based document.');
    }
    return bytes;
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
    final font = attributes['font']?.toString();
    if (font == 'serif') styles.add('font-family:Noto Serif Bengali,serif');
    if (font == 'sans-serif') styles.add('font-family:Noto Sans Bengali,sans-serif');
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
}
