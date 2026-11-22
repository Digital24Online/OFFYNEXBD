import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_document_format_service.dart';

Uint8List makeZip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Map<String, dynamic> tableData(WriterImportedDocument document) {
  final operation = document.delta.firstWhere((item) =>
      item['insert'] is Map &&
      (item['insert'] as Map).containsKey('offynexbd-writer-table'));
  return jsonDecode((operation['insert'] as Map)['offynexbd-writer-table'] as String)
      as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DOCX gridSpan keeps the logical table columns aligned', () async {
    final bytes = makeZip({
      'word/document.xml': '''
        <w:document xmlns:w="urn:schemas-microsoft-com:office:word">
          <w:body><w:tbl><w:tr>
            <w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr><w:p><w:r><w:t>Wide</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t>Third</w:t></w:r></w:p></w:tc>
          </w:tr></w:tbl></w:body>
        </w:document>
      ''',
    });
    final directory = await Directory.systemTemp.createTemp('offynex-docx-');
    addTearDown(() => directory.delete(recursive: true));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'docx', imageDirectory: directory, title: 'Grid.docx',
    );
    expect(tableData(imported)['rows'], [['Wide', '', 'Third']]);
    expect(tableData(imported)['merges'], [
      {'row': 0, 'column': 0, 'rowSpan': 1, 'columnSpan': 2},
    ]);
  });

  test('DOCX vMerge restart and continuation import as a vertical span', () async {
    final bytes = makeZip({
      'word/document.xml': '''
        <w:document xmlns:w="urn:schemas-microsoft-com:office:word">
          <w:body><w:tbl>
            <w:tr>
              <w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>Vertical</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Top</w:t></w:r></w:p></w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p/></w:tc>
              <w:tc><w:p><w:r><w:t>Bottom</w:t></w:r></w:p></w:tc>
            </w:tr>
          </w:tbl></w:body>
        </w:document>
      ''',
    });
    final directory = await Directory.systemTemp.createTemp('offynex-docx-vmerge-');
    addTearDown(() => directory.delete(recursive: true));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'docx', imageDirectory: directory, title: 'Vertical.docx',
    );
    expect(tableData(imported)['merges'], [
      {'row': 0, 'column': 0, 'rowSpan': 2, 'columnSpan': 1},
    ]);
    expect(tableData(imported)['rows'], [
      ['Vertical', 'Top'], ['', 'Bottom'],
    ]);
  });

  test('ODT column and row spans import as one merged rectangle', () async {
    final bytes = makeZip({
      'content.xml': '''
        <office:document-content
          xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
          xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
          xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">
          <office:body><office:text><table:table>
            <table:table-row>
              <table:table-cell table:number-columns-spanned="2" table:number-rows-spanned="2"><text:p>Joined</text:p></table:table-cell>
              <table:covered-table-cell/>
              <table:table-cell><text:p>Top</text:p></table:table-cell>
            </table:table-row>
            <table:table-row>
              <table:covered-table-cell/>
              <table:covered-table-cell/>
              <table:table-cell><text:p>Bottom</text:p></table:table-cell>
            </table:table-row>
          </table:table></office:text></office:body>
        </office:document-content>
      ''',
    });
    final directory = await Directory.systemTemp.createTemp('offynex-odt-span-');
    addTearDown(() => directory.delete(recursive: true));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'odt', imageDirectory: directory, title: 'Merged.odt',
    );
    expect(tableData(imported)['merges'], [
      {'row': 0, 'column': 0, 'rowSpan': 2, 'columnSpan': 2},
    ]);
    expect(tableData(imported)['rows'], [
      ['Joined', '', 'Top'], ['', '', 'Bottom'],
    ]);
  });

  test('ODT export writes merged-cell row and column spans', () async {
    final directory = await Directory.systemTemp.createTemp('offynex-odt-export-');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = await WriterDocumentFormatService.exportOdt(
      title: 'Merged table',
      delta: [
        {'insert': {
          'offynexbd-writer-table': jsonEncode({
            'rows': [['Merged', '', 'Right'], ['', '', 'Below']],
            'merges': [
              {'row': 0, 'column': 0, 'rowSpan': 2, 'columnSpan': 2},
            ],
          }),
        }},
        {'insert': '\\n'},
      ],
      imageDirectory: directory,
      pageLayout: {'pageSize': 'A4', 'orientation': 'Portrait'},
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final content = utf8.decode(archive.findFile('content.xml')!.readBytes()!);
    expect(content, contains('table:number-columns-spanned="2"'));
    expect(content, contains('table:number-rows-spanned="2"'));
    expect(content, contains('<table:covered-table-cell/>'));
  });

  test('ODT repeated rows and columns expand within table safety limits', () async {
    final bytes = makeZip({
      'content.xml': '''
        <office:document-content
          xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
          xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
          xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">
          <office:body><office:text><table:table>
            <table:table-row table:number-rows-repeated="2">
              <table:table-cell table:number-columns-repeated="2"><text:p>A</text:p></table:table-cell>
              <table:covered-table-cell/>
            </table:table-row>
          </table:table></office:text></office:body>
        </office:document-content>
      ''',
    });
    final directory = await Directory.systemTemp.createTemp('offynex-odt-');
    addTearDown(() => directory.delete(recursive: true));
    final imported = await WriterDocumentFormatService.importFile(
      bytes: bytes, extension: 'odt', imageDirectory: directory, title: 'Repeated.odt',
    );
    expect(tableData(imported)['rows'], [
      ['A', 'A', ''], ['A', 'A', ''],
    ]);
  });
}
