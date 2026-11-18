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
}
