import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_docx_export_service.dart';

void main() {
  test('Writer DOCX export produces a valid Office document with formatted text', () async {
    final bytes = await WriterDocxExportService.build(
      title: 'বাংলা Report',
      pageLayout: {'pageSize': 'A5', 'orientation': 'Landscape', 'top': 0.5, 'bottom': 0.75, 'left': 1.0, 'right': 1.25},
      headerText: 'পরীক্ষার Header',
      footerText: 'Footer text',
      delta: [
        {'insert': 'শিরোনাম\n', 'attributes': {'header': 1}},
        {'insert': 'বাংলা ও English ', 'attributes': {'bold': true}},
        {'insert': 'লেখা', 'attributes': {'italic': true, 'color': '#123456'}},
        {'insert': '\nশেষ অনুচ্ছেদ\n'},
      ],
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(archive.findFile('word/document.xml')!.readBytes()!);
    expect(documentXml, contains('<w:pgSz w:w="11906" w:h="8391" w:orient="landscape"/>'));
    expect(documentXml, contains('w:top="720"'));
    expect(documentXml, contains('<w:header w:type="default"'));
    expect(documentXml, contains('<w:footer w:type="default"'));
    expect(utf8.decode(archive.findFile('word/header1.xml')!.readBytes()!), contains('পরীক্ষার Header'));
    expect(utf8.decode(archive.findFile('word/footer1.xml')!.readBytes()!), contains('Footer text'));
  });

  test('Writer DOCX export keeps consecutive numbered items in one numbering sequence', () async {
    final bytes = await WriterDocxExportService.build(
      title: 'List test',
      delta: [
        {'insert': 'First\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'Second\n', 'attributes': {'list': 'ordered'}},
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = utf8.decode(archive.findFile('word/document.xml')!.readBytes()!);
    expect(RegExp(r'<w:numPr>').allMatches(document).length, 2);
    final ids = RegExp(r'<w:numId w:val="(\d+)"').allMatches(document).map((m) => m.group(1)).toSet();
    expect(ids.length, 1);
  });

  test('Writer DOCX export preserves nested list levels', () async {
    final bytes = await WriterDocxExportService.build(
      title: 'Nested list',
      delta: [
        {'insert': 'Parent one\n', 'attributes': {'list': 'ordered'}},
        {'insert': 'Nested child\n', 'attributes': {'list': 'bullet', 'indent': 1}},
        {'insert': 'Parent two\n', 'attributes': {'list': 'ordered'}},
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = utf8.decode(archive.findFile('word/document.xml')!.readBytes()!);
    expect(RegExp(r'<w:numPr>').allMatches(document).length, 3);
    expect(document, contains('<w:ilvl w:val="1"/>'));
    expect(document, contains('<w:ilvl w:val="0"/>'));
  });

  test('Writer DOCX export rejects missing local image instead of creating broken link', () async {
    expect(
      () => WriterDocxExportService.build(
        title: 'Image test',
        delta: [
          {'insert': {'image': '/missing/offynex-image.png'}},
        ],
      ),
      throwsA(isA<StateError>()),
    );
  });
  test('Writer DOCX export embeds local image bytes', () async {
    final directory = await Directory.systemTemp.createTemp('writer-docx-test-');
    try {
      final image = File('${directory.path}/pixel.png');
      await image.writeAsBytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x04, 0x00, 0x00, 0x00, 0xB5, 0x1C, 0x0C,
        0x02, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41,
        0x54, 0x78, 0xDA, 0x63, 0xFC, 0xFF, 0x1F, 0x00,
        0x03, 0x03, 0x02, 0x00, 0xEF, 0xBF, 0x19, 0x99,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82,
      ]);
      final bytes = await WriterDocxExportService.build(
        title: 'Image report',
        delta: [{'insert': {'image': image.path}}],
      );
      expect(bytes.length, greaterThan(1000));
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('DOCX export writes a real Word hard page break', () async {
    final bytes = await WriterDocxExportService.build(
      title: 'Page break test',
      delta: [
        {'insert': 'Before\n'},
        {'insert': {'offynexbd-writer-page-break': 'page'}},
        {'insert': 'After\n'},
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = utf8.decode(archive.findFile('word/document.xml')!.readBytes()!);
    expect(document, contains('<w:br w:type="page"/>'));
    expect(document, isNot(contains('OFFYNEXBD_WRITER_PAGE_BREAK')));
  });
}
