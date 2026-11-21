import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'writer_page_break.dart';

class WriterImportedDocument {
  const WriterImportedDocument({required this.delta, required this.title, required this.format, this.pageLayout, this.headerText = '', this.footerText = ''});
  final List<Map<String, dynamic>> delta;
  final String title;
  final String format;
  final Map<String, dynamic>? pageLayout;
  final String headerText;
  final String footerText;
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
          relationships[id] = _attribute(rel, 'TargetMode') == 'External'
              ? target
              : _normalizeZipPath(
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

    final numberingFormats = _docxNumberingFormats(archive);
    final delta = <Map<String, dynamic>>[];
    for (final child in _elementChildren(body)) {
      if (child.name.local == 'p') {
        await _appendDocxParagraph(child, _docxParagraphAttributes(child, numberingFormats), delta, saveImage, relationships);
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
    final pageLayout = _docxPageLayout(body);
    final headerFooter = _docxHeaderFooter(archive, body, relationships);
    return WriterImportedDocument(
      delta: delta, title: _safeTitle(title), format: 'DOCX',
      pageLayout: pageLayout, headerText: headerFooter.$1, footerText: headerFooter.$2,
    );
  }

  static Future<void> _appendDocxParagraph(
    XmlElement paragraph,
    Map<String, dynamic> block,
    List<Map<String, dynamic>> delta,
    Future<String?> Function(String) saveImage,
    Map<String, String> relationships,
  ) async {
    Future<void> walk(XmlNode node, Map<String, dynamic> attrs) async {
      if (node is! XmlElement) return;
      final name = node.name.local;
      if (name == 'rPr' || name == 'pPr') return;
      if (name == 'hyperlink') {
        final id = _attribute(node, 'id');
        final target = id == null ? null : _safeLink(relationships[id]);
        final linked = <String, dynamic>{...attrs, 'link': ?target};
        for (final child in node.children) { await walk(child, linked); }
        return;
      }
      if (name == 'r') {
        final runAttrs = <String, dynamic>{...attrs, ..._docxRunAttributes(_firstChild(node, 'rPr'))};
        for (final child in node.children) { await walk(child, runAttrs); }
        return;
      }
      if (name == 't') { _addText(delta, node.innerText, attrs); return; }
      if (name == 'tab') { _addText(delta, '\t', attrs); return; }
      if (name == 'br' && _attribute(node, 'type') == 'page') {
        delta.add({'insert': {WriterPageBreakEmbed.embedType: 'page'}});
        return;
      }
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

  static Map<String, Map<int, String>> _docxNumberingFormats(Archive archive) {
    final file = archive.findFile('word/numbering.xml');
    if (file == null) return const {};
    final document = XmlDocument.parse(utf8.decode(_fileBytes(file)));
    final abstractFormats = <String, Map<int, String>>{};
    for (final abstractNum in _descendants(document, 'abstractNum')) {
      final abstractId = _attribute(abstractNum, 'abstractNumId');
      if (abstractId == null) continue;
      final levels = <int, String>{};
      for (final level in _descendants(abstractNum, 'lvl')) {
        final levelIndex = (int.tryParse(_attribute(level, 'ilvl') ?? '0') ?? 0).clamp(0, 8).toInt();
        final numFmt = _firstChild(level, 'numFmt');
        final format = numFmt == null ? null : _attribute(numFmt, 'val');
        if (format != null) levels[levelIndex] = format;
      }
      if (levels.isNotEmpty) abstractFormats[abstractId] = levels;
    }
    final result = <String, Map<int, String>>{};
    for (final num in _descendants(document, 'num')) {
      final numId = _attribute(num, 'numId');
      final abstract = _firstChild(num, 'abstractNumId');
      final abstractId = abstract == null ? null : _attribute(abstract, 'val');
      final levels = abstractId == null ? null : abstractFormats[abstractId];
      if (numId == null || levels == null) continue;
      final resolved = Map<int, String>.from(levels);
      for (final override in _elementChildren(num).where((element) => element.name.local == 'lvlOverride')) {
        final levelIndex = (int.tryParse(_attribute(override, 'ilvl') ?? '0') ?? 0).clamp(0, 8).toInt();
        final overrideLevel = _firstChild(override, 'lvl');
        final overrideFormat = overrideLevel == null ? null : _firstChild(overrideLevel, 'numFmt');
        final format = overrideFormat == null ? null : _attribute(overrideFormat, 'val');
        if (format != null) resolved[levelIndex] = format;
      }
      result[numId] = resolved;
    }
    return result;
  }

  static Map<String, dynamic> _docxParagraphAttributes(
    XmlElement paragraph,
    Map<String, Map<int, String>> numberingFormats,
  ) {
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
    final numbering = _firstChild(props, 'numPr');
    final numIdElement = numbering == null ? null : _firstChild(numbering, 'numId');
    final levelElement = numbering == null ? null : _firstChild(numbering, 'ilvl');
    final numId = numIdElement == null ? null : _attribute(numIdElement, 'val');
    final level = (int.tryParse(levelElement == null ? '0' : (_attribute(levelElement, 'val') ?? '0')) ?? 0).clamp(0, 8).toInt();
    final format = numId == null ? null : numberingFormats[numId]?[level] ?? numberingFormats[numId]?[0];
    if (format == 'bullet') {
      result['list'] = 'bullet';
    } else if (const {'decimal', 'decimalZero', 'lowerLetter', 'upperLetter', 'lowerRoman', 'upperRoman'}.contains(format)) {
      result['list'] = 'ordered';
    }
    if (level > 0 && result.containsKey('list')) result['indent'] = level;
    return result;
  }

  static Map<String, dynamic> _docxPageLayout(XmlElement body) {
    final section = _firstDescendant(body, 'sectPr');
    final defaults = <String, dynamic>{
      'pageSize': 'A4', 'orientation': 'Portrait', 'marginPreset': 'Normal',
      'top': 1.0, 'bottom': 1.0, 'left': 1.0, 'right': 1.0,
    };
    if (section == null) return defaults;
    final size = _firstChild(section, 'pgSz');
    final width = size == null ? null : double.tryParse(_attribute(size, 'w') ?? '');
    final height = size == null ? null : double.tryParse(_attribute(size, 'h') ?? '');
    if (width != null && height != null && width > 0 && height > 0) {
      final w = width / 1440;
      final h = height / 1440;
      final landscape = _attribute(size!, 'orient') == 'landscape' || w > h;
      final short = landscape ? h : w;
      final long = landscape ? w : h;
      const pages = <String, List<double>>{
        'A4': [8.27, 11.69], 'A5': [5.83, 8.27], 'Letter': [8.5, 11.0], 'Legal': [8.5, 14.0],
      };
      var closest = 'A4';
      var distance = double.infinity;
      for (final entry in pages.entries) {
        final d = (entry.value[0] - short).abs() + (entry.value[1] - long).abs();
        if (d < distance) { distance = d; closest = entry.key; }
      }
      defaults['pageSize'] = closest;
      defaults['orientation'] = landscape ? 'Landscape' : 'Portrait';
    }
    final margins = _firstChild(section, 'pgMar');
    if (margins != null) {
      for (final key in ['top', 'bottom', 'left', 'right']) {
        final value = double.tryParse(_attribute(margins, key) ?? '');
        if (value != null && value.isFinite) defaults[key] = (value / 1440).clamp(0.25, 2.5);
      }
    }
    return defaults;
  }

  static (String, String) _docxHeaderFooter(
    Archive archive, XmlElement body, Map<String, String> relationships,
  ) {
    final section = _firstDescendant(body, 'sectPr');
    if (section == null) return ('', '');
    String readPart(String referenceName) {
      final reference = _firstChild(section, referenceName);
      if (reference == null) return '';
      final id = _attribute(reference, 'id');
      final path = id == null ? null : relationships[id];
      if (path == null || path.startsWith('http:') || path.startsWith('https:')) return '';
      final file = archive.findFile(path);
      if (file == null || file.size > 2 * 1024 * 1024) return '';
      try {
        final xml = XmlDocument.parse(utf8.decode(_fileBytes(file)));
        return _descendants(xml, 'p').map(_plainText).where((line) => line.isNotEmpty).join('\n');
      } catch (_) { return ''; }
    }
    return (readPart('headerReference'), readPart('footerReference'));
  }

  static double? _lengthInches(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)(cm|mm|in|pt)$').firstMatch(raw.trim());
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null || !amount.isFinite) return null;
    return switch (match.group(2)) {
      'cm' => amount / 2.54, 'mm' => amount / 25.4, 'pt' => amount / 72, 'in' => amount, _ => null,
    };
  }

  static Map<String, dynamic> _odtPageLayout(ArchiveFile? stylesFile) {
    final defaults = <String, dynamic>{
      'pageSize': 'A4', 'orientation': 'Portrait', 'marginPreset': 'Normal',
      'top': 1.0, 'bottom': 1.0, 'left': 1.0, 'right': 1.0,
    };
    if (stylesFile == null) return defaults;
    try {
      final doc = XmlDocument.parse(utf8.decode(_fileBytes(stylesFile)));
      final props = _firstDescendant(doc, 'page-layout-properties');
      if (props == null) return defaults;
      final width = _lengthInches(_attribute(props, 'page-width'));
      final height = _lengthInches(_attribute(props, 'page-height'));
      if (width != null && height != null) {
        final landscape = _attribute(props, 'print-orientation') == 'landscape' || width > height;
        final short = landscape ? height : width;
        final long = landscape ? width : height;
        const pages = <String, List<double>>{
          'A4': [8.27, 11.69], 'A5': [5.83, 8.27], 'Letter': [8.5, 11.0], 'Legal': [8.5, 14.0],
        };
        var closest = 'A4';
        var distance = double.infinity;
        for (final entry in pages.entries) {
          final d = (entry.value[0] - short).abs() + (entry.value[1] - long).abs();
          if (d < distance) { distance = d; closest = entry.key; }
        }
        defaults['pageSize'] = closest;
        defaults['orientation'] = landscape ? 'Landscape' : 'Portrait';
      }
      for (final pair in const {'top': 'margin-top', 'bottom': 'margin-bottom', 'left': 'margin-left', 'right': 'margin-right'}.entries) {
        final value = _lengthInches(_attribute(props, pair.value));
        if (value != null) defaults[pair.key] = value.clamp(0.25, 2.5);
      }
    } catch (_) {}
    return defaults;
  }

  static (String, String) _odtHeaderFooter(ArchiveFile? stylesFile) {
    if (stylesFile == null) return ('', '');
    try {
      final doc = XmlDocument.parse(utf8.decode(_fileBytes(stylesFile)));
      final master = _firstDescendant(doc, 'master-page');
      if (master == null) return ('', '');
      final header = _firstChild(master, 'header');
      final footer = _firstChild(master, 'footer');
      return (
        header == null ? '' : _descendants(header, 'p').map(_plainText).join('\n'),
        footer == null ? '' : _descendants(footer, 'p').map(_plainText).join('\n'),
      );
    } catch (_) { return ('', ''); }
  }

  static bool _isOn(XmlElement? element) {
    if (element == null) return false;
    final value = _attribute(element, 'val')?.toLowerCase();
    return value == null || !const {'0', 'false', 'off', 'none'}.contains(value);
  }

  static String _fontFamilyCategory(String family) {
    final value = family.trim();
    final normalized = value.toLowerCase();
    if (normalized.isEmpty) return 'sans-serif';
    if (normalized == 'serif' || normalized.contains('noto serif') ||
        normalized.contains('times') || normalized.contains('georgia') ||
        normalized.contains('cambria')) return 'serif';
    if (normalized == 'sans-serif' || normalized.contains('sans') ||
        normalized.contains('arial') || normalized.contains('calibri') ||
        normalized.contains('helvetica') || normalized.contains('roboto')) return 'sans-serif';
    return value;
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
    if (family != null) result['font'] = _fontFamilyCategory(family);
    return result;
  }

  static List<List<String>> _docxTable(XmlElement table) {
    // Expand Word gridSpan cells into their logical grid positions. The
    // current Writer table embed cannot draw merged cells yet, but retaining
    // blank span slots prevents subsequent columns from shifting left.
    final rows = <List<String>>[];
    for (final row in _elementChildren(table).where((e) => e.name.local == 'tr')) {
      if (rows.length >= 20) break;
      final cells = <String>[];
      for (final cell in _elementChildren(row).where((e) => e.name.local == 'tc')) {
        if (cells.length >= 10) break;
        final value = _descendants(cell, 'p').map(_plainText).join('\n');
        final properties = _firstChild(cell, 'tcPr');
        final spanNode = properties == null ? null : _firstChild(properties, 'gridSpan');
        final span = (int.tryParse(spanNode == null ? '1' : _attribute(spanNode, 'val') ?? '1') ?? 1)
            .clamp(1, 10 - cells.length).toInt();
        cells.add(value);
        for (var index = 1; index < span; index++) {
          cells.add('');
        }
      }
      if (cells.isNotEmpty) rows.add(cells);
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
        if (_attribute(child, 'style-name') == 'OFFYNEXPageBreak') {
          delta.add({'insert': {WriterPageBreakEmbed.embedType: 'page'}});
          delta.add({'insert': '\n'});
          continue;
        }
        final block = <String, dynamic>{};
        if (child.name.local == 'h') {
          final level = int.tryParse(_attribute(child, 'outline-level') ?? '1') ?? 1;
          block['header'] = level.clamp(1, 3).toInt();
        }
        await _appendOdtParagraph(child, styles, delta, archive, imageDirectory, () => imageIndex++);
        delta.add({'insert': '\n', if (block.isNotEmpty) 'attributes': block});
      } else if (child.name.local == 'list') {
        final listKind = _odtListKind(stylesFile, _attribute(child, 'style-name'));
        for (final item in _elementChildren(child).where((e) => e.name.local == 'list-item')) {
          for (final p in _elementChildren(item).where((e) => e.name.local == 'p' || e.name.local == 'h')) {
            await _appendOdtParagraph(p, styles, delta, archive, imageDirectory, () => imageIndex++);
            delta.add({'insert': '\n', 'attributes': {'list': listKind}});
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
    final pageLayout = _odtPageLayout(stylesFile);
    final headerFooter = _odtHeaderFooter(stylesFile);
    return WriterImportedDocument(
      delta: delta, title: _safeTitle(title), format: 'ODT',
      pageLayout: pageLayout, headerText: headerFooter.$1, footerText: headerFooter.$2,
    );
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
      if (name == 'a') {
        final target = _safeLink(_attribute(node, 'href'));
        final linked = <String, dynamic>{...attrs, 'link': ?target};
        for (final child in node.children) { await walk(child, linked); }
        return;
      }
      if (name == 'span') {
        final style = _attribute(node, 'style-name');
        final merged = <String, dynamic>{...attrs, if (style != null && styles.containsKey(style)) ...styles[style]!};
        for (final child in node.children) { await walk(child, merged); }
        return;
      }
      if (name == 's') {
        final count = (int.tryParse(_attribute(node, 'c') ?? '1') ?? 1).clamp(1, 100).toInt();
        _addText(delta, List<String>.filled(count, ' ').join(), attrs);
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

  static String _odtListKind(ArchiveFile? stylesFile, String? styleName) {
    if (stylesFile == null || styleName == null) return 'bullet';
    try {
      final document = XmlDocument.parse(utf8.decode(_fileBytes(stylesFile)));
      for (final listStyle in _descendants(document, 'list-style')) {
        if (_attribute(listStyle, 'name') != styleName) continue;
        return _firstDescendant(listStyle, 'list-level-style-number') == null
            ? 'bullet'
            : 'ordered';
      }
    } catch (_) {
      return 'bullet';
    }
    return 'bullet';
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
    final strike = _attribute(props, 'text-line-through-style');
    if (strike != null && strike != 'none') result['strike'] = true;
    final background = _attribute(props, 'background-color');
    if (background != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(background)) result['background'] = background;
    final size = _attribute(props, 'font-size');
    if (size != null) {
      final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)(pt|px)$').firstMatch(size.trim());
      if (match != null) {
        final amount = double.tryParse(match.group(1)!);
        if (amount != null && amount >= 5 && amount <= 144) {
          result['size'] = (match.group(2) == 'px' ? amount * 0.75 : amount).toStringAsFixed(2);
        }
      }
    }
    final family = _attribute(props, 'font-family');
    if (family != null) result['font'] = _fontFamilyCategory(family);
    return result;
  }

  static List<List<String>> _odtTable(XmlElement table) {
    final rows = <List<String>>[];
    for (final row in _descendants(table, 'table-row')) {
      if (rows.length >= 20) break;
      final cells = <String>[];
      for (final cell in _elementChildren(row).where((e) => e.name.local == 'table-cell' || e.name.local == 'covered-table-cell')) {
        if (cells.length >= 10) break;
        final value = _descendants(cell, 'p').map(_plainText).join('\n');
        final repeated = (int.tryParse(_attribute(cell, 'number-columns-repeated') ?? '1') ?? 1)
            .clamp(1, 10 - cells.length).toInt();
        for (var index = 0; index < repeated; index++) {
          cells.add(cell.name.local == 'covered-table-cell' ? '' : value);
        }
      }
      if (cells.isEmpty) continue;
      final repeatedRows = (int.tryParse(_attribute(row, 'number-rows-repeated') ?? '1') ?? 1)
          .clamp(1, 20 - rows.length).toInt();
      for (var index = 0; index < repeatedRows; index++) {
        rows.add(List<String>.from(cells));
      }
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
    final imageFiles = <ArchiveFile>[];
    final manifestImages = <String>[];
    final content = StringBuffer(
      '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
      'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
      'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
      'xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" '
      'xmlns:xlink="http://www.w3.org/1999/xlink" office:version="1.2"><office:body><office:text>',
    );
    final paragraph = StringBuffer();
    final inlineTextStyles = <String, String>{};
    String inlineStyleName(Map<String, dynamic> attrs) {
      final properties = <String>[];
      if (attrs['bold'] == true) properties.add('fo:font-weight="bold"');
      if (attrs['italic'] == true) properties.add('fo:font-style="italic"');
      if (attrs['underline'] == true) properties.add('style:text-underline-style="solid"');
      if (attrs['strike'] == true) properties.add('style:text-line-through-style="solid"');
      final color = attrs['color']?.toString();
      if (color != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) properties.add('fo:color="$color"');
      final background = attrs['background']?.toString();
      if (background != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(background)) properties.add('fo:background-color="$background"');
      final rawSize = double.tryParse(attrs['size']?.toString() ?? '');
      if (rawSize != null && rawSize.isFinite && rawSize >= 5 && rawSize <= 144) properties.add('fo:font-size="${rawSize.toStringAsFixed(2)}pt"');
      final font = attrs['font']?.toString().trim();
      if (font == 'serif') {
        properties.add('fo:font-family="Noto Serif Bengali"');
      } else if (font == 'sans-serif') {
        properties.add('fo:font-family="Noto Sans Bengali"');
      } else if (font != null) {
        final safeFont = font.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
        if (safeFont.isNotEmpty) properties.add('fo:font-family="${_xmlEscape(safeFont)}"');
      }
      if (properties.isEmpty) return '';
      final key = properties.join(' ');
      return inlineTextStyles.putIfAbsent(key, () => 'T_Inline${inlineTextStyles.length + 1}');
    }
    var imageIndex = 0;
    String? openListKind;
    void closeList() {
      if (openListKind == null) return;
      content.write('</text:list>');
      openListKind = null;
    }

    void flushParagraph([Map<String, dynamic> block = const {}]) {
      final value = paragraph.toString();
      paragraph.clear();
      final heading = block['header'];
      final tag = heading is int && heading >= 1 && heading <= 3 ? 'text:h' : 'text:p';
      final level = heading is int ? ' text:outline-level="$heading"' : '';
      final element = '<$tag$level>$value</$tag>';
      final listKind = block['list'];
      if (listKind == 'bullet' || listKind == 'ordered') {
        if (openListKind != listKind) {
          closeList();
          openListKind = listKind as String;
          final styleName = listKind == 'ordered' ? 'L_Numbered' : 'L_Bullet';
          content.write('<text:list text:style-name="$styleName">');
        }
        content.write('<text:list-item>$element</text:list-item>');
      } else {
        closeList();
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
            final styleName = inlineStyleName(attrs);
            if (styleName.isNotEmpty) value = '<text:span text:style-name="$styleName">$value</text:span>';
            final link = _safeLink(attrs['link']?.toString());
            if (link != null) value = '<text:a xlink:href="${_xmlEscape(link)}">$value</text:a>';
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
        imageFiles.add(ArchiveFile(name, data.length, data));
        manifestImages.add('<manifest:file-entry manifest:full-path="$name" manifest:media-type="${_imageMime(ext)}"/>');
        content.write('<text:p><draw:frame draw:name="Image$imageIndex" text:anchor-type="as-char"><draw:image xlink:href="$name" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad"/></draw:frame></text:p>');
      } else if (insert is Map && insert.containsKey(WriterPageBreakEmbed.embedType)) {
        flushParagraph();
        closeList();
        content.write('<text:p text:style-name="OFFYNEXPageBreak"/>');
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
    closeList();
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
<text:list-style style:name="L_Bullet"><text:list-level-style-bullet text:level="1" text:bullet-char="•"/></text:list-style>
<text:list-style style:name="L_Numbered"><text:list-level-style-number text:level="1" style:num-format="1"/></text:list-style>
<style:style style:name="T_Bold" style:family="text"><style:text-properties fo:font-weight="bold"/></style:style>
<style:style style:name="T_Italic" style:family="text"><style:text-properties fo:font-style="italic"/></style:style>
<style:style style:name="T_Underline" style:family="text"><style:text-properties style:text-underline-style="solid"/></style:style>
${inlineTextStyles.entries.map((entry) => '<style:style style:name="${entry.value}" style:family="text"><style:text-properties ${entry.key}/></style:style>').join('\n')}
</office:styles>
<office:automatic-styles><style:style style:name="OFFYNEXPageBreak" style:family="paragraph"><style:paragraph-properties fo:break-before="page"/></style:style><style:page-layout style:name="pm1"><style:page-layout-properties fo:page-width="${page[0].toStringAsFixed(2)}cm" fo:page-height="${page[1].toStringAsFixed(2)}cm" style:print-orientation="${pageLayout['orientation'] == 'Landscape' ? 'landscape' : 'portrait'}" fo:margin-top="${margin('top')}" fo:margin-bottom="${margin('bottom')}" fo:margin-left="${margin('left')}" fo:margin-right="${margin('right')}"/></style:page-layout></office:automatic-styles>
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
    for (final imageFile in imageFiles) { archive.addFile(imageFile); }
    archive.addFile(ArchiveFile('content.xml', contentBytes.length, contentBytes));
    archive.addFile(ArchiveFile('styles.xml', styleBytes.length, styleBytes));
    final meta = utf8.encode('<?xml version="1.0" encoding="UTF-8"?><office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/" office:version="1.2"><office:meta><dc:title>${_xmlEscape(title)}</dc:title></office:meta></office:document-meta>');
    archive.addFile(ArchiveFile('meta.xml', meta.length, meta));
    archive.addFile(ArchiveFile('META-INF/manifest.xml', manifestBytes.length, manifestBytes));
    final encoded = ZipEncoder().encodeBytes(archive);
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
      if (part == '..') {
        if (parts.isEmpty) {
          throw const FormatException(
            'Document archive contains a relationship path outside the package root.',
          );
        }
        parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    if (parts.isEmpty) {
      throw const FormatException('Document archive contains an empty relationship path.');
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

  static String? _safeLink(String? raw) {
    if (raw == null || raw.length > 2048) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return uri.host.isEmpty ? null : uri.toString();
    }
    if (uri.scheme == 'mailto') {
      return uri.path.isEmpty || uri.path.contains(RegExp(r'[\\r\\n]')) ? null : uri.toString();
    }
    return null;
  }

  static String _xmlEscape(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  static String _safeTitle(String value) {
    var text = value.trim();
    final dot = text.lastIndexOf('.');
    if (dot > 0) {
      final extension = text.substring(dot + 1).toLowerCase();
      if (extension == 'docx' || extension == 'odt') {
        text = text.substring(0, dot).trim();
      }
    }
    if (text.isEmpty) return 'Imported Document';
    return text.length > 180 ? text.substring(0, 180) : text;
  }
}
