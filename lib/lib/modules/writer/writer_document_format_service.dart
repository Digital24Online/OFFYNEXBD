import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class WriterImportedDocument {
  const WriterImportedDocument({required this.delta, required this.title, required this.format});
  final List<Map<String, dynamic>> delta;
  final String title;
  final String format;
}

/// Safe, bounded DOCX/ODT interchange for editable paragraphs, common
/// formatting, headings, lists, Writer tables and embedded images.
class WriterDocumentFormatService {
  static const int maxInputBytes = 25 * 1024 * 1024;
  static const int maxExpandedBytes = 60 * 1024 * 1024;
  static const int maxEntries = 2000;
  static const int maxImageBytes = 15 * 1024 * 1024;

  static Future<WriterImportedDocument> importFile({
    required Uint8List bytes,
    required String extension,
    required Directory imageDirectory,
    required String title,
  }) async {
    if (bytes.isEmpty || bytes.length > maxInputBytes) {
      throw const FormatException('Document file is empty or exceeds 25 MB.');
    }
    switch (extension.toLowerCase().replaceFirst('.', '')) {
      case 'docx':
        return _importDocx(bytes, imageDirectory, title);
      case 'odt':
        return _importOdt(bytes, imageDirectory, title);
      default:
        throw const FormatException('Only DOCX and ODT files are supported.');
    }
  }

  static Future<WriterImportedDocument> _importDocx(
    Uint8List bytes, Directory imageDirectory, String title,
  ) async {
    final archive = _decodeArchive(bytes);
    final file = archive.findFile('word/document.xml');
    if (file == null) throw const FormatException('DOCX document.xml is missing.');
    final document = XmlDocument.parse(utf8.decode(_fileBytes(file)));
    final body = _firstDescendant(document, 'body');
    if (body == null) throw const FormatException('DOCX body is missing.');

    final relationships = <String, String>{};
    final relFile = archive.findFile('word/_rels/document.xml.rels');
    if (relFile != null) {
      final relDoc = XmlDocument.parse(utf8.decode(_fileBytes(relFile)));
      for (final rel in _descendants(relDoc, 'Relationship')) {
        final id = _attribute(rel, 'Id');
        final target = _attribute(rel, 'Target');
        if (id != null && target != null) {
          relationships[id] = _normalizeZipPath(
            target.startsWith('/') ? target.substring(1) : 'word/$target',
          );
        }
      }
    }

    await imageDirectory.create(recursive: true);
    final savedImages = <String, String>{};
    Future<String?> saveImage(String id) async {
      if (savedImages.containsKey(id)) return savedImages[id];
      final target = relationships[id];
      if (target == null) return null;
      final image = archive.findFile(target);
      if (image == null) return null;
      final data = _fileBytes(image);
      if (data.isEmpty || data.length > maxImageBytes) return null;
      final ext = _safeImageExtension(target);
      final path = '${imageDirectory.path}/imported_${DateTime.now().microsecondsSinceEpoch}_${savedImages.length}.$ext';
      await File(path).writeAsBytes(data, flush: true);
      savedImages[id] = path;
      return path;
    }

    final delta = <Map<String, dynamic>>[];
    for (final child in _elementChildren(body)) {
      if (child.name.local == 'p') {
        await _appendDocxParagraph(child, _docxParagraphAttributes(child), delta, saveImage);
      } else if (child.name.local == 'tbl') {
        final rows = _docxTable(child);
        if (rows.isNotEmpty) {
          delta.add({'insert': {'offynexbd-writer-table': jsonEncode({'rows': rows, 'headerRow': true, 'version': 1})}});
          delta.add({'insert': '\n'});
        }
      }
    }
    if (delta.isEmpty) delta.add({'insert': '\n'});
    _ensureTrailingNewline(delta);
    return WriterImportedDocument(delta: delta, title: _safeTitle(title), format: 'DOCX');
  }

  static Future<void> _appendDocxParagraph(
    XmlElement paragraph,
    Map<String, dynamic> block,
    List<Map<String, dynamic>> delta,
    Future<String?> Function(String) saveImage,
  ) async {
    Future<void> walk(XmlNode node, Map<String, dynamic> attrs) async {
      if (node is! XmlElement) return;
      final name = node.name.local;
      if (name == 'rPr' || name == 'pPr') return;
      if (name == 'r') {
        final runAttrs = _docxRunAttributes(_firstChild(node, 'rPr'));
        for (final child in node.children) { await walk(child, runAttrs); }
        return;
      }
      if (name == 't') { _addText(delta, node.innerText, attrs); return; }
      if (name == 'tab') { _addText(delta, '\t', attrs); return; }
      if (name == 'br' || name == 'cr') { _addText(delta, '\n', attrs); return; }
      if (name == 'blip') {
        final id = _attribute(node, 'embed');
        if (id != null) {
          final path = await saveImage(id);
          if (path != null) delta.add({'insert': {'image': path}});
        }
        return;
      }
      for (final child in node.children) { await walk(child, attrs); }
    }
    for (final child in paragraph.children) { await walk(child, const <String, dynamic>{}); }
    delta.add({'insert': '\n', if (block.isNotEmpty) 'attributes': block});
  }

  static Map<String, dynamic> _docxParagraphAttributes(XmlElement paragraph) {
    final props = _firstChild(paragraph, 'pPr');
    if (props == null) return {};
    final result = <String, dynamic>{};
    final style = _firstChild(props, 'pStyle');
    final styleId = style == null ? null : _attribute(style, 'val');
    final heading = styleId == null ? null : RegExp(r'heading([1-3])', caseSensitive: false).firstMatch(styleId);
    if (heading != null) result['header'] = int.parse(heading.group(1)!);
    final jc = _firstChild(props, 'jc');
    final align = jc == null ? null : _attribute(jc, 'val');
    const aligns = {'center': 'center', 'right': 'right', 'both': 'justify'};
    if (aligns.containsKey(align)) result['align'] = aligns[align];
    if (_firstChild(props, 'numPr') != null) result['list'] = 'bullet';
    return result;
  }

  static bool _isOn(XmlElement? element) {
    if (element == null) return false;
    final value = _attribute(element, 'val')?.toLowerCase();
    return value == null || !const {'0', 'false', 'off', 'none'}.contains(value);
  }

  static Map<String, dynamic> _docxRunAttributes(XmlElement? props) {
    if (props == null) return {};
    final result = <String, dynamic>{};
    if (_isOn(_firstChild(props, 'b'))) result['bold'] = true;
    if (_isOn(_firstChild(props, 'i'))) result['italic'] = true;
    if (_isOn(_firstChild(props, 'u'))) result['underline'] = true;
    if (_isOn(_firstChild(props, 'strike'))) result['strike'] = true;
    final color = _firstChild(props, 'color');
    final colorValue = color == null ? null : _attribute(color, 'val');
    if (colorValue != null && RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(colorValue)) result['color'] = '#$colorValue';
    final size = _firstChild(props, 'sz');
    final halfPoints = size == null ? null : int.tryParse(_attribute(size, 'val') ?? '');
    if (halfPoints != null && halfPoints >= 12 && halfPoints <= 192) {
      result['size'] = (halfPoints / 2 * 4 / 3).toStringAsFixed(2);
    }
    final fonts = _firstChild(props, 'rFonts');
    final family = fonts == null ? null : _attribute(fonts, 'ascii');
    if (family != null) result['font'] = family.toLowerCase().contains('serif') ? 'serif' : 'sans-serif';
    return result;
  }

  static List<List<String>> _docxTable(XmlElement table) {
    final rows = <List<String>>[];
    for (final row in _elementChildren(table).where((e) => e.name.local == 'tr')) {
      final cells = <String>[];
      for (final cell in _elementChildren(row).where((e) => e.name.local == 'tc')) {
        cells.add(_descendants(cell, 'p').map(_plainText).join('\n'));
      }
      if (cells.isNotEmpty) rows.add(cells.take(10).toList());
      if (rows.length >= 20) break;
    }
    return rows;
  }

  static Future<WriterImportedDocument> _importOdt(
    Uint8List bytes, Directory imageDirectory, String title,
  ) async {
    final archive = _decodeArchive(bytes);
    final file = archive.findFile('content.xml');
    if (file == null) throw const FormatException('ODT content.xml is missing.');
    final content = XmlDocument.parse(utf8.decode(_fileBytes(file)));
    final body = _firstDescendant(content, 'text');
    if (body == null) throw const FormatException('ODT text body is missing.');

    final styles = <String, Map<String, dynamic>>{};
    final stylesFile = archive.findFile('styles.xml');
    if (stylesFile != null) {
      final doc = XmlDocument.parse(utf8.decode(_fileBytes(stylesFile)));
      for (final style in _descendants(doc, 'style')) {
        final name = _attribute(style, 'name');
        final props = _firstDescendant(style, 'text-properties');
        if (name != null && props != null) styles[name] = _odtTextAttributes(props);
      }
    }

    await imageDirectory.create(recursive: true);
    final delta = <Map<String, dynamic>>[];
    var imageIndex = 0;
    for (final child in _elementChildren(body)) {
      if (child.name.local == 'p' || child.name.local == 'h') {
        final block = <String, dynamic>{};
        if (child.name.local == 'h') {
          final level = int.tryParse(_attribute(child, 'outline-level') ?? '1') ?? 1;
          block['header'] = level.clamp(1, 3).toInt();
        }
        await _appendOdtParagraph(child, styles, delta, archive, imageDirectory, () => imageIndex++);
        delta.add({'insert': '\n', if (block.isNotEmpty) 'attributes': block});
      } else if (child.name.local == 'list') {
        for (final item in _elementChildren(child).where((e) => e.name.local == 'list-item')) {
          for (final p in _elementChildren(item).where((e) => e.name.local == 'p' || e.name.local == 'h')) {
            await _appendOdtParagraph(p, styles, delta, archive, imageDirectory, () => imageIndex++);
            delta.add({'insert': '\n', 'attributes': {'list': 'bullet'}});
          }
        }
      } else if (child.name.local == 'table') {
        final rows = _odtTable(child);
        if (rows.isNotEmpty) {
          delta.add({'insert': {'offynexbd-writer-table': jsonEncode({'rows': rows, 'headerRow': false, 'version': 1})}});
          delta.add({'insert': '\n'});
        }
      }
    }
    if (delta.isEmpty) delta.add({'insert': '\n'});
    _ensureTrailingNewline(delta);
    return WriterImportedDocument(delta: delta, title: _safeTitle(title), format: 'ODT');
  }

  static Future<void> _appendOdtParagraph(
    XmlElement paragraph,
    Map<String, Map<String, dynamic>> styles,
    List<Map<String, dynamic>> delta,
    Archive archive,
    Directory imageDirectory,
    int Function() nextImage,
  ) async {
    Future<void> walk(XmlNode node, Map<String, dynamic> attrs) async {
      if (node is XmlText) { _addText(delta, node.value, attrs); return; }
      if (node is! XmlElement) return;
      final name = node.name.local;
      if (name == 'span') {
        final style = _attribute(node, 'style-name');
        final merged = <String, dynamic>{...attrs, if (style != null && styles.containsKey(style)) ...styles[style]!};
        for (final child in node.children) { await walk(child, merged); }
        return;
      }
      if (name == 's') {
        final count = (int.tryParse(_attribute(node, 'c') ?? '1') ?? 1).clamp(1, 100).toInt();
        _addText(delta, ' ' * count, attrs);
        return;
      }
      if (name == 'tab') { _addText(delta, '\t', attrs); return; }
      if (name == 'line-break') { _addText(delta, '\n', attrs); return; }
      if (name == 'image') {
        final href = _attribute(node, 'href');
        if (href != null && !href.startsWith('/') && !href.contains('..')) {
          final image = archive.findFile(href);
          if (image != null) {
            final data = _fileBytes(image);
            if (data.isNotEmpty && data.length <= maxImageBytes) {
              final ext = _safeImageExtension(href);
              final path = '${imageDirectory.path}/odt_${DateTime.now().microsecondsSinceEpoch}_${nextImage()}.$ext';
              await File(path).writeAsBytes(data, flush: true);
              delta.add({'insert': {'image': path}});
            }
          }
        }
        return;
      }
      for (final child in node.children) { await walk(child, attrs); }
    }
    for (final child in paragraph.children) { await walk(child, const <String, dynamic>{}); }
  }

  static Map<String, dynamic> _odtTextAttributes(XmlElement props) {
    final result = <String, dynamic>{};
    final weight = _attribute(props, 'font-weight');
    if (weight == 'bold' || weight == '700') result['bold'] = true;
    if (_attribute(props, 'font-style') == 'italic') result['italic'] = true;
    final underline = _attribute(props, 'text-underline-style');
    if (underline != null && underline != 'none') result['underline'] = true;
    final color = _attribute(props, 'color');
    if (color != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) result['color'] = color;
    final family = _attribute(props, 'font-family');
    if (family != null) result['font'] = family.toLowerCase().contains('serif') ? 'serif' : 'sans-serif';
    return result;
  }

  static List<List<String>> _odtTable(XmlElement table) {
    final rows = <List<String>>[];
    for (final row in _descendants(table, 'table-row')) {
      final cells = <String>[];
      for (final cell in _elementChildren(row).where((e) => e.name.local == 'table-cell' || e.name.local == 'covered-table-cell')) {
        cells.add(_descendants(cell, 'p').map(_plainText).join('\n'));
      }
      if (cells.isNotEmpty) rows.add(cells.take(10).toList());
      if (rows.length >= 20) break;
    }
    return rows;
  }

  static Future<Uint8List> exportOdt({
    required String title,
    required List<Map<String, dynamic>> delta,
    required Directory imageDirectory,
    required Map<String, dynamic> pageLayout,
    String headerText = '',
    String footerText = '',
  }) async {
    final archive = Archive();
    final manifestImages = <String>[];
    final content = StringBuffer(
      '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
      'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
      'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
      'xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" '
      'xmlns:xlink="http://www.w3.org/1999/xlink" office:version="1.2"><office:body><office:text>',
    );
    final paragraph = StringBuffer();
    var imageIndex = 0;
    void flushParagraph([Map<String, dynamic> block = const {}]) {
      final value = paragraph.toString();
      paragraph.clear();
      final heading = block['header'];
      final tag = heading is int && heading >= 1 && heading <= 3 ? 'text:h' : 'text:p';
      final level = heading is int ? ' text:outline-level="$heading"' : '';
      final element = '<$tag$level>$value</$tag>';
      if (block['list'] == 'bullet') {
        content.write('<text:list><text:list-item>$element</text:list-item></text:list>');
      } else {
        content.write(element);
      }
    }

    for (final operation in delta) {
      final insert = operation['insert'];
      final raw = operation['attributes'];
      final attrs = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            var value = _xmlEscape(parts[i]);
            if (attrs['bold'] == true) value = '<text:span text:style-name="T_Bold">$value</text:span>';
            if (attrs['italic'] == true) value = '<text:span text:style-name="T_Italic">$value</text:span>';
            if (attrs['underline'] == true) value = '<text:span text:style-name="T_Underline">$value</text:span>';
            paragraph.write(value);
          }
          if (i < parts.length - 1) flushParagraph(attrs);
        }
      } else if (insert is Map && insert['image'] is String) {
        flushParagraph();
        final source = File(insert['image'] as String);
        if (!await source.exists()) throw StateError('Writer image is missing: ${source.path}');
        final data = await source.readAsBytes();
        if (data.isEmpty || data.length > maxImageBytes) throw const FormatException('Image exceeds 15 MB.');
        final ext = _safeImageExtension(source.path);
        final name = 'Pictures/image_${imageIndex++}.$ext';
        archive.addFile(ArchiveFile(name, data.length, data));
        manifestImages.add('<manifest:file-entry manifest:full-path="$name" manifest:media-type="${_imageMime(ext)}"/>');
        content.write('<text:p><draw:frame draw:name="Image${imageIndex}" text:anchor-type="as-char"><draw:image xlink:href="$name" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad"/></draw:frame></text:p>');
      } else if (insert is Map && insert['offynexbd-writer-table'] is String) {
        flushParagraph();
        final rows = _decodeTable(insert['offynexbd-writer-table'] as String);
        if (rows.isNotEmpty) {
          content.write('<table:table table:name="WriterTable${imageIndex++}">');
          for (final row in rows) {
            content.write('<table:table-row>');
            for (final cell in row) {
              content.write('<table:table-cell office:value-type="string"><text:p>${_xmlEscape(cell)}</text:p></table:table-cell>');
            }
            content.write('</table:table-row>');
          }
          content.write('</table:table>');
        }
      }
    }
    if (paragraph.isNotEmpty || delta.isEmpty) flushParagraph();
    content.write('</office:text></office:body></office:document-content>');

    const sizes = <String, List<double>>{
      'A4': [21.0, 29.7], 'A5': [14.8, 21.0], 'Letter': [21.59, 27.94], 'Legal': [21.59, 35.56],
    };
    final page = List<double>.from(sizes[pageLayout['pageSize']] ?? sizes['A4']!);
    if (pageLayout['orientation'] == 'Landscape') {
      final oldWidth = page[0]; page[0] = page[1]; page[1] = oldWidth;
    }
    String margin(String key) {
      final value = pageLayout[key];
      final inches = value is num && value.isFinite ? value.toDouble().clamp(0.25, 2.5) : 1.0;
      return '${(inches * 2.54).toStringAsFixed(2)}cm';
    }
    final styles = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" office:version="1.2">
<office:styles>
<style:style style:name="T_Bold" style:family="text"><style:text-properties fo:font-weight="bold"/></style:style>
<style:style style:name="T_Italic" style:family="text"><style:text-properties fo:font-style="italic"/></style:style>
<style:style style:name="T_Underline" style:family="text"><style:text-properties style:text-underline-style="solid"/></style:style>
</office:styles>
<office:automatic-styles><style:page-layout style:name="pm1"><style:page-layout-properties fo:page-width="${page[0].toStringAsFixed(2)}cm" fo:page-height="${page[1].toStringAsFixed(2)}cm" style:print-orientation="${pageLayout['orientation'] == 'Landscape' ? 'landscape' : 'portrait'}" fo:margin-top="${margin('top')}" fo:margin-bottom="${margin('bottom')}" fo:margin-left="${margin('left')}" fo:margin-right="${margin('right')}"/></style:page-layout></office:automatic-styles>
<office:master-styles><style:master-page style:name="Default" style:page-layout-name="pm1"><style:header><text:p>${_xmlEscape(headerText)}</text:p></style:header><style:footer><text:p>${_xmlEscape(footerText)}</text:p></style:footer></style:master-page></office:master-styles>
</office:document-styles>''';
    final manifest = '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
<manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/>
<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
<manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>
${manifestImages.join('\n')}
</manifest:manifest>''';
    final mime = utf8.encode('application/vnd.oasis.opendocument.text');
    final contentBytes = utf8.encode(content.toString());
    final styleBytes = utf8.encode(styles);
    final manifestBytes = utf8.encode(manifest);
    archive.addFile(ArchiveFile.noCompress('mimetype', mime.length, mime));
    archive.addFile(ArchiveFile('content.xml', contentBytes.length, contentBytes));
    archive.addFile(ArchiveFile('styles.xml', styleBytes.length, styleBytes));
    final meta = utf8.encode('<?xml version="1.0" encoding="UTF-8"?><office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/" office:version="1.2"><office:meta><dc:title>${_xmlEscape(title)}</dc:title></office:meta></office:document-meta>');
    archive.addFile(ArchiveFile('meta.xml', meta.length, meta));
    archive.addFile(ArchiveFile('META-INF/manifest.xml', manifestBytes.length, manifestBytes));
    final encoded = ZipEncoder().encode(archive);
    if (encoded.isEmpty || encoded.length > maxInputBytes) throw const FormatException('ODT export exceeded the 25 MB limit.');
    return Uint8List.fromList(encoded);
  }

  static Archive _decodeArchive(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.files.isEmpty || archive.files.length > maxEntries) throw const FormatException('Invalid document archive entry count.');
    var expanded = 0;
    for (final file in archive.files) {
      expanded += file.size;
      if (expanded > maxExpandedBytes) throw const FormatException('Expanded document exceeds 60 MB.');
    }
    return archive;
  }

  static List<int> _fileBytes(ArchiveFile file) => file.readBytes() ?? const <int>[];
  static Iterable<XmlElement> _elementChildren(XmlElement e) => e.children.whereType<XmlElement>();
  static Iterable<XmlElement> _descendants(XmlNode n, String name) => n.descendants.whereType<XmlElement>().where((e) => e.name.local == name);

  static XmlElement? _firstChild(XmlElement e, String name) {
    for (final child in _elementChildren(e)) { if (child.name.local == name) return child; }
    return null;
  }

  static XmlElement? _firstDescendant(XmlNode n, String name) {
    for (final child in n.descendants.whereType<XmlElement>()) { if (child.name.local == name) return child; }
    return null;
  }

  static String? _attribute(XmlElement e, String name) {
    for (final a in e.attributes) { if (a.name.local == name) return a.value; }
    return null;
  }

  static String _plainText(XmlElement e) => e.descendants.whereType<XmlText>().map((x) => x.value).join();
  static void _addText(List<Map<String, dynamic>> delta, String value, Map<String, dynamic> attrs) {
    if (value.isNotEmpty) delta.add({'insert': value, if (attrs.isNotEmpty) 'attributes': Map<String, dynamic>.from(attrs)});
  }

  static void _ensureTrailingNewline(List<Map<String, dynamic>> delta) {
    final last = delta.isEmpty ? null : delta.last['insert'];
    if (last is String && last.endsWith('\n')) return;
    delta.add({'insert': '\n'});
  }

  static String _normalizeZipPath(String path) {
    final parts = <String>[];
    for (final part in path.replaceAll('\\', '/').split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') { if (parts.isNotEmpty) parts.removeLast(); } else { parts.add(part); }
    }
    return parts.join('/');
  }

  static String _safeImageExtension(String path) {
    final ext = path.split('.').last.toLowerCase().split('?').first;
    return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext) ? ext : 'png';
  }

  static String _imageMime(String ext) => switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg', 'gif' => 'image/gif', 'webp' => 'image/webp', 'bmp' => 'image/bmp', _ => 'image/png',
  };

  static List<List<String>> _decodeTable(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map || value['rows'] is! List) return [];
      return (value['rows'] as List).take(20).whereType<List>().map((row) => row.take(10).map((v) => v?.toString() ?? '').toList()).toList();
    } catch (_) { return []; }
  }

  static String _xmlEscape(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  static String _safeTitle(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Imported Document';
    return text.length > 180 ? text.substring(0, 180) : text;
  }
}
