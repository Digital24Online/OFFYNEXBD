import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/workspace_record_codec.dart';

void main() {
  final records = <Map<String, dynamic>>[
    {
      'id': 'slide-1',
      'title': 'Quarterly Review',
      'content': 'Revenue\nCosts\nForecast',
      'updatedAt': '2026-11-18T10:30:00.000Z',
    },
  ];

  test('workspace record codec round-trips a module export', () {
    final encoded = WorkspaceRecordCodec.encode(
      'Slides',
      records,
      createdAt: DateTime.utc(2026, 11, 18),
    );
    final decoded = WorkspaceRecordCodec.decode(
      encoded,
      expectedModule: 'Slides',
    );

    expect(decoded, records);
  });

  test('workspace record codec rejects another module export', () {
    final encoded = WorkspaceRecordCodec.encode('Forms', records);
    expect(
      () => WorkspaceRecordCodec.decode(encoded, expectedModule: 'Slides'),
      throwsFormatException,
    );
  });

  test('workspace record codec rejects duplicate or invalid records', () {
    final duplicate = [records.single, records.single];
    expect(
      () => WorkspaceRecordCodec.encode('Database', duplicate),
      throwsFormatException,
    );

    final invalid = WorkspaceRecordCodec.encode('Fonts', records);
    final tampered = invalid.replaceFirst('"title": "Quarterly Review"', '"title": ""');
    expect(
      () => WorkspaceRecordCodec.decode(tampered, expectedModule: 'Fonts'),
      throwsFormatException,
    );
  });

  test('workspace record codec supports every record-based workspace module', () {
    for (final module in [
      'Slides',
      'Fonts',
      'AI Assistant',
      'Cloud',
      'Forms',
      'Scan',
      'Database',
    ]) {
      final encoded = WorkspaceRecordCodec.encode(module, records);
      expect(
        WorkspaceRecordCodec.decode(encoded, expectedModule: module),
        records,
        reason: '$module must support portable record export and import',
      );
    }
  });

  test('workspace record codec still rejects unknown module names', () {
    expect(
      () => WorkspaceRecordCodec.encode('Unknown Module', records),
      throwsArgumentError,
    );
  });
}
