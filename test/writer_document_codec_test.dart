import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_document_codec.dart';

void main() {
  final documents = <Map<String, dynamic>>[
    {
      'id': 'writer-1',
      'title': 'Bangla Report',
      'content': [
        {'insert': 'বাংলা লেখা\n'},
        {'insert': 'Bold text', 'attributes': {'bold': true}},
      ],
      'updated': '2026-11-18T10:30:00.000Z',
      'pageLayout': {'pageSize': 'A4', 'orientation': 'Portrait'},
      'writerMeta': {
        'fontFamily': 'serif',
        'comments': [
          {'id': 'comment-1', 'text': 'Review this paragraph'}
        ],
      },
    },
  ];

  test('Writer document codec preserves full document content and metadata', () {
    final encoded = WriterDocumentCodec.encode(
      documents,
      createdAt: DateTime.utc(2026, 11, 18),
    );
    final decoded = WriterDocumentCodec.decode(encoded);
    expect(decoded, documents);
  });

  test('Writer document codec rejects invalid version and malformed records', () {
    expect(
      () => WriterDocumentCodec.decode(
        '{"format":"OFFYNEXBD_WRITER_DOCUMENTS","version":2,"documents":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => WriterDocumentCodec.encode([
        {'id': '', 'title': 'No ID', 'content': []}
      ]),
      throwsFormatException,
    );
  });

  test('Writer document codec rejects malformed rich-text operations', () {
    expect(
      () => WriterDocumentCodec.encode([
        {'id': 'bad-delta', 'title': 'Broken', 'content': [{'attributes': {'bold': true}}]},
      ]),
      throwsFormatException,
    );
    expect(
      () => WriterDocumentCodec.encode([
        {'id': 'bad-embed', 'title': 'Broken', 'content': [{'insert': {'unknown-embed': 'x'}}]},
      ]),
      throwsFormatException,
    );
    expect(
      () => WriterDocumentCodec.encode([
        {'id': 'bad-content', 'title': 'Broken', 'content': 42},
      ]),
      throwsFormatException,
    );
  });

  test('Writer document codec rejects duplicate IDs', () {
    expect(
      () => WriterDocumentCodec.encode([documents.single, documents.single]),
      throwsFormatException,
    );
  });
}
