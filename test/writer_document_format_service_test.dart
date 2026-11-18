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
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Heading</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Bold text</w:t></w:r></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Cell A</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Cell B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>''';
    final data = utf8.encode(xml);
    archive.addFile(ArchiveFile('word/document.xml', data.length, data));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'docx', imageDirectory: temp, title: 'sample.docx',
    );
    expect(imported.format, 'DOCX');
    expect(imported.title, 'sample');
    expect(imported.delta.any((op) => op['insert'] == 'Heading'), isTrue);
    expect(imported.delta.any((op) => (op['attributes'] as Map?)?['header'] == 1), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Bold text' && (op['attributes'] as Map?)?['bold'] == true), isTrue);
    expect(imported.delta.any((op) => op['insert'] is Map && (op['insert'] as Map).containsKey('offynexbd-writer-table')), isTrue);
  });

  test('ODT export/import round-trip preserves text, bold style, heading and editable table', () async {
    final delta = <Map<String, dynamic>>[
      {'insert': 'Hello বাংলা'},
      {'insert': '\n', 'attributes': {'header': 1}},
      {'insert': 'Bold', 'attributes': {'bold': true}},
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
    expect(imported.delta.any((op) => op['insert'] == 'Hello বাংলা'), isTrue);
    expect(imported.delta.any((op) => op['insert'] == 'Bold' && (op['attributes'] as Map?)?['bold'] == true), isTrue);
    expect(imported.delta.any((op) => op['insert'] is Map && (op['insert'] as Map).containsKey('offynexbd-writer-table')), isTrue);
    final exportedArchive = ZipDecoder().decodeBytes(bytes);
    expect(exportedArchive.findFile('styles.xml'), isNotNull);
    final styles = utf8.decode(exportedArchive.findFile('styles.xml')!.readBytes()!);
    expect(styles, contains('Header'));
    expect(styles, contains('Footer'));
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
}
