import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_docx_export_service.dart';

void main() {
  test('Writer DOCX export produces a valid Office document with formatted text', () async {
    final bytes = await WriterDocxExportService.build(
      title: 'বাংলা Report',
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

}
