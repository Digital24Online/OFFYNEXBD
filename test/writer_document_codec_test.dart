import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_document_codec.dart';
import 'package:offynexbd/lib/modules/writer/writer_page_break.dart';

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

  test('Writer document codec preserves explicit page-break embeds', () {
    final withPageBreak = <Map<String, dynamic>>[
      {
        'id': 'page-break-doc',
        'title': 'Page break document',
        'content': [
          {'insert': 'প্রথম পৃষ্ঠা\\n'},
          {'insert': {WriterPageBreakEmbed.embedType: 'page'}},
          {'insert': 'দ্বিতীয় পৃষ্ঠা\\n'},
        ],
      },
    ];

    final decoded = WriterDocumentCodec.decode(
      WriterDocumentCodec.encode(withPageBreak),
    );
    expect(decoded, withPageBreak);
  });

  test('Writer document codec rejects malformed page-break embeds', () {
    expect(
      () => WriterDocumentCodec.encode([
        {
          'id': 'bad-page-break',
          'title': 'Broken page break',
          'content': [
            {'insert': {WriterPageBreakEmbed.embedType: 42}},
          ],
        },
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

  test('Writer document codec enforces the 25 MB archive limit', () {
    final largeText = ''.padRight(WriterDocumentCodec.maxArchiveBytes, 'x');
    expect(
      () => WriterDocumentCodec.encode([
        {'id': 'large', 'title': 'Large', 'content': largeText},
      ]),
      throwsFormatException,
    );
    final oversized = ''.padRight(WriterDocumentCodec.maxArchiveBytes + 1, 'x');
    expect(() => WriterDocumentCodec.decode(oversized), throwsFormatException);
  });
}
