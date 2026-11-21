import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_document_format_service.dart';

void main() {
  late Directory temp;
  setUp(() async { temp = await Directory.systemTemp.createTemp('writer-format-test-'); });
  tearDown(() async { if (await temp.exists()) await temp.delete(recursive: true); });

  test('DOCX import maps heading, bold run and text into editable Quill Delta', () async {
    final archive = Archive();
    final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<w:body>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Heading</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Bold text</w:t></w:r></w:p>
<w:p><w:r><w:br w:type="page"/></w:r></w:p>
<w:p><w:hyperlink r:id="rLink"><w:r><w:t>Open link</w:t></w:r></w:hyperlink></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Cell A</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Cell B</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:bottom="1440" w:left="1440" w:right="1440"/><w:headerReference w:type="default" r:id="rHeader"/><w:footerReference w:type="default" r:id="rFooter"/></w:sectPr></w:body></w:document>''';
    const rels = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rLink" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com/docs" TargetMode="External"/><Relationship Id="rHeader" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/><Relationship Id="rFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/></Relationships>';
    final relBytes = utf8.encode(rels);
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', relBytes.length, relBytes));
    final headerBytes = utf8.encode('<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>DOCX Header</w:t></w:r></w:p></w:hdr>');
    final footerBytes = utf8.encode('<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>DOCX Footer</w:t></w:r></w:p></w:ftr>');
    archive.addFile(ArchiveFile('word/header1.xml', headerBytes.length, headerBytes));
    archive.addFile(ArchiveFile('word/footer1.xml', footerBytes.length, footerBytes));
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile('word/document.xml', data.length, data));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'docx', imageDirectory: temp, title: 'sample.docx',
    );
    expect(imported.format, 'DOCX');
    expect(imported.pageLayout?['pageSize'], 'A4');
    expect(imported.pageLayout?['orientation'], 'Portrait');
    expect(imported.headerText, 'DOCX Header');
    expect(imported.footerText, 'DOCX Footer');
    expect(imported.title, 'sample');
    expect(imported.delta.any((op) => op['insert'] == 'Heading'), isTrue);
    expect(imported.delta.any((op) => (op['attributes'] as Map?)?['header'] == 1), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Bold text' && (op['attributes'] as Map?)?['bold'] == true), isTrue);
    expect(imported.delta.any((op) => op['insert'] is Map && (op['insert'] as Map).containsKey('offynexbd-writer-page-break')), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Open link' && (op['attributes'] as Map?)?['link'] == 'https://example.com/docs'), isTrue);
    expect(imported.delta.any((op) => op['insert'] is Map && (op['insert'] as Map).containsKey('offynexbd-writer-table')), isTrue);
  });

  test('DOCX import preserves ordered and bullet numbering formats', () async {
    final archive = Archive();
    const documentXml = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="7"/></w:numPr></w:pPr><w:r><w:t>First</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="7"/></w:numPr></w:pPr><w:r><w:t>Second</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="7"/></w:numPr></w:pPr><w:r><w:t>Nested</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="8"/></w:numPr></w:pPr><w:r><w:t>Bullet</w:t></w:r></w:p>
<w:sectPr/></w:body></w:document>''';
    const numberingXml = '''
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/></w:lvl><w:lvl w:ilvl="1"><w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>
<w:abstractNum w:abstractNumId="2"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>
<w:num w:numId="7"><w:abstractNumId w:val="1"/></w:num>
<w:num w:numId="8"><w:abstractNumId w:val="2"/></w:num>
</w:numbering>''';
    final docBytes = utf8.encode(documentXml), numBytes = utf8.encode(numberingXml);
    archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));
    archive.addFile(ArchiveFile('word/numbering.xml', numBytes.length, numBytes));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
      extension: 'docx', imageDirectory: temp, title: 'numbered.docx',
    );
    final first = imported.delta.firstWhere((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'ordered');
    final second = imported.delta.where((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'ordered').length;
    expect(first['attributes']['list'], 'ordered');
    expect(second, 2);
    expect(imported.delta.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'bullet'), isTrue);
    final nested = imported.delta.firstWhere((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['indent'] == 1);
    expect(nested['attributes']['list'], 'bullet');
  });

  test('ODT export/import groups and preserves ordered list items', () async {
    final bytes = await WriterDocumentFormatService.exportOdt(
      title: 'Numbered list',
      delta: [
        {'insert': 'First\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'Second\n', 'attributes': {'list': 'ordered'}},
      ],
      imageDirectory: temp,
      pageLayout: {'pageSize': 'A4', 'orientation': 'Portrait'},
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final content = utf8.decode(archive.findFile('content.xml')!.readBytes()!);
    expect(RegExp(r'<text:list text:style-name="L_Numbered">').allMatches(content).length, 1);
    expect(RegExp(r'<text:list-item>').allMatches(content).length, 2);
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'odt', imageDirectory: temp, title: 'numbered.odt',
    );
    expect(imported.delta.where((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'ordered').length, 2);
  });

  test('ODT export/import round-trip preserves text, bold style, heading and editable table', () async {
    final delta = <Map<String, dynamic>>[
      {'insert': 'Hello বাংলা'},
      {'insert': '\n', 'attributes': {'header': 1}},
      {'insert': 'Bold', 'attributes': {'bold': true}},
      {'insert': 'Linked', 'attributes': {'link': 'https://example.com/docs'}},
      {'insert': 'Styled', 'attributes': {'bold': true, 'italic': true, 'underline': true, 'strike': true, 'color': '#123456', 'background': '#F0E0D0', 'size': '18', 'font': 'serif'}},
      {'insert': 'Custom font', 'attributes': {'font': 'SolaimanLipi'}},
      {'insert': '\n'},
      {'insert': {'offynexbd-writer-table': jsonEncode({'rows': [['A', 'B'], ['1', '2']], 'headerRow': true})}},
      {'insert': '\n'},
    ];
    final bytes = await WriterDocumentFormatService.exportOdt(
      title: 'Round trip', delta: delta, imageDirectory: temp,
      pageLayout: {'pageSize': 'A4', 'orientation': 'Portrait', 'top': 1.0, 'bottom': 1.0, 'left': 1.0, 'right': 1.0},
      headerText: 'Header', footerText: 'Footer',
    );
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'odt', imageDirectory: temp, title: 'roundtrip.odt',
    );
    expect(imported.format, 'ODT');
    expect(imported.pageLayout?['pageSize'], 'A4');
    expect(imported.pageLayout?['orientation'], 'Portrait');
    expect(imported.headerText, 'Header');
    expect(imported.footerText, 'Footer');
    expect(imported.delta.any((op) => op['insert'] == 'Hello বাংলা'), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Bold' && (op['attributes'] as Map?)?['bold'] == true), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Linked' && (op['attributes'] as Map?)?['link'] == 'https://example.com/docs'), isTrue);
    final styled = imported.delta.firstWhere((op) => op['insert'] == 'Styled');
    final styleAttrs = styled['attributes'] as Map;
    expect(styleAttrs['bold'], isTrue);
    expect(styleAttrs['italic'], isTrue);
    expect(styleAttrs['underline'], isTrue);
    expect(styleAttrs['strike'], isTrue);
    expect(styleAttrs['color'], '#123456');
    expect(styleAttrs['background'], '#F0E0D0');
    expect(double.parse(styleAttrs['size'].toString()), closeTo(18, 0.01));
    expect(styleAttrs['font'], 'serif');
    final customFont = imported.delta.firstWhere((op) => op['insert'] == 'Custom font');
    expect(customFont['attributes']['font'], 'SolaimanLipi');
    expect(imported.delta.any((op) => op['insert'] is Map && (op['insert'] as Map).containsKey('offynexbd-writer-table')), isTrue);
    final exportedArchive = ZipDecoder().decodeBytes(bytes);
    expect(exportedArchive.files.first.name, 'mimetype');
    expect(exportedArchive.findFile('styles.xml'), isNotNull);
    final styles = utf8.decode(exportedArchive.findFile('styles.xml')!.readBytes()!);
    expect(styles, contains('Header'));
    expect(styles, contains('Footer'));
    expect(styles, contains('fo:font-family="SolaimanLipi"'));
    final content = utf8.decode(exportedArchive.findFile('content.xml')!.readBytes()!);
    expect(content, contains('<text:a xlink:href="https://example.com/docs">Linked</text:a>'));
    expect(styles, contains('fo:page-width="21.00cm"'));
  });

  test('rejects unsupported formats and oversized input before ZIP parsing', () async {
    await expectLater(
      WriterDocumentFormatService.importFile(
        bytes: Uint8List.fromList([1, 2, 3]), extension: 'pdf', imageDirectory: temp, title: 'file.pdf',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      WriterDocumentFormatService.importFile(
        bytes: Uint8List(WriterDocumentFormatService.maxInputBytes + 1),
        extension: 'docx', imageDirectory: temp, title: 'large.docx',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('DOCX font family classification checks sans-serif before serif', () async {
    final archive = Archive();
    final xml = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:r><w:rPr><w:rFonts w:ascii="Arial"/></w:rPr><w:t>Sans</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:rFonts w:ascii="Noto Serif Bengali"/></w:rPr><w:t>Serif</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:rFonts w:ascii="SolaimanLipi"/></w:rPr><w:t>Custom font</w:t></w:r></w:p>
<w:sectPr/></w:body></w:document>''';
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile('word/document.xml', data.length, data));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'docx', imageDirectory: temp, title: 'fonts.docx',
    );
    expect(imported.delta.any((op) => op['insert'] == 'Sans' && (op['attributes'] as Map?)?['font'] == 'sans-serif'), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Serif' && (op['attributes'] as Map?)?['font'] == 'serif'), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Custom font' && (op['attributes'] as Map?)?['font'] == 'SolaimanLipi'), isTrue);
  });

  test('ODT sans-serif family is not misclassified as serif', () async {
    final archive = Archive();
    const content = '''<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style"><office:body><office:text><text:p><text:span text:style-name="Sans">Sans text</text:span><text:span text:style-name="Custom">Custom text</text:span></text:p></office:text></office:body></office:document-content>''';
    const styles = '''<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"><office:styles><style:style style:name="Sans" style:family="text"><style:text-properties fo:font-family="sans-serif"/></style:style><style:style style:name="Custom" style:family="text"><style:text-properties fo:font-family="SolaimanLipi"/></style:style></office:styles></office:document-styles>''';
    final contentBytes = utf8.encode(content), styleBytes = utf8.encode(styles);
    archive.addFile(ArchiveFile('content.xml', contentBytes.length, contentBytes));
    archive.addFile(ArchiveFile('styles.xml', styleBytes.length, styleBytes));
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'odt', imageDirectory: temp, title: 'fonts.odt',
    );
    expect(imported.delta.any((op) => op['insert'] == 'Sans text' && (op['attributes'] as Map?)?['font'] == 'sans-serif'), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Custom text' && (op['attributes'] as Map?)?['font'] == 'SolaimanLipi'), isTrue);
  });

  test('ODT round-trip preserves explicit page breaks', () async {
    final bytes = await WriterDocumentFormatService.exportOdt(
      title: 'Page break test',
      delta: [
        {'insert': 'Before\n'},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
        {'insert': 'After\n'},
      ],
      imageDirectory: temp,
      pageLayout: {'pageSize': 'A4', 'orientation': 'Portrait'},
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final content = utf8.decode(archive.findFile('content.xml')!.readBytes()!);
    expect(content, contains('OFFYNEXPageBreak'));
    expect(utf8.decode(archive.findFile('styles.xml')!.readBytes()!), contains('fo:break-before="page"'));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'odt', imageDirectory: temp, title: 'page-break.odt',
    );
    expect(imported.delta.any((op) => op['insert'] is Map && (op['insert'] as Map).containsKey('offynexbd-writer-page-break')), isTrue);
  });


  test('DOCX import rejects relationship paths that escape the archive root', () async {
    final archive = Archive();
    const documentXml = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body><w:p><w:r><w:t>Safe text</w:t></w:r></w:p></w:body>
</w:document>''';
    const relationshipsXml = '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rEscape"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
    Target="../../../escape.png"/>
</Relationships>''';
    final documentBytes = utf8.encode(documentXml);
    final relationshipBytes = utf8.encode(relationshipsXml);
    archive.addFile(ArchiveFile('word/document.xml', documentBytes.length, documentBytes));
    archive.addFile(
      ArchiveFile(
        'word/_rels/document.xml.rels',
        relationshipBytes.length,
        relationshipBytes,
      ),
    );

    await expectLater(
      WriterDocumentFormatService.importFile(
        bytes: Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
        extension: 'docx',
        imageDirectory: temp,
        title: 'unsafe.docx',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(temp.listSync(), isEmpty);
  });
}
