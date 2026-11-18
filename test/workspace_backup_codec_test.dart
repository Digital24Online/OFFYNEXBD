import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offynexbd/lib/modules/workspace/workspace_backup_codec.dart';

void main() {
  test('backup codec round-trips supported OFFYNEXBD preference values', () {
    final source = <String, Object?>{
      'offynex_writer_documents': '[{"id":"doc-1"}]',
      'offynex_language_bangla_v1': true,
      'offynex_sheets_count': 12,
      'offynex_scale': 1.25,
      'offynex_recent_files': <String>['a.docx', 'b.xlsx'],
      'unrelated_app_key': 'must not be exported',
    };

    final encoded = WorkspaceBackupCodec.encode(
      source,
      createdAt: DateTime.utc(2026, 11, 18),
    );
    final decoded = WorkspaceBackupCodec.decode(encoded);

    expect(decoded, hasLength(5));
    expect(decoded['offynex_writer_documents'], source['offynex_writer_documents']);
    expect(decoded['offynex_language_bangla_v1'], true);
    expect(decoded['offynex_sheets_count'], 12);
    expect(decoded['offynex_scale'], 1.25);
    expect(decoded['offynex_recent_files'], ['a.docx', 'b.xlsx']);
    expect(encoded, isNot(contains('unrelated_app_key')));
  });

  test('backup codec rejects malformed or unsupported backup versions', () {
    expect(
      () => WorkspaceBackupCodec.decode('not json'),
      throwsFormatException,
    );
    expect(
      () => WorkspaceBackupCodec.decode(
        '{"format":"OFFYNEXBD_LOCAL_BACKUP","version":99,"data":{}}',
      ),
      throwsFormatException,
    );
  });

  test('backup codec rejects foreign keys and unsupported value types', () {
    expect(
      () => WorkspaceBackupCodec.decode(
        '{"format":"OFFYNEXBD_LOCAL_BACKUP","version":1,"data":{"other_app_key":"x"}}',
      ),
      throwsFormatException,
    );
    expect(
      () => WorkspaceBackupCodec.decode(
        '{"format":"OFFYNEXBD_LOCAL_BACKUP","version":1,"data":{"offynex_bad":[1,2]}}',
      ),
      throwsFormatException,
    );
  });
 
  test('backup export refuses to silently omit unsupported OFFYNEXBD data', () {
    expect(
      () => WorkspaceBackupCodec.encode({
        'offynex_supported': 'keep',
        'offynex_unsupported': <int>[1, 2, 3],
      }),
      throwsFormatException,
    );
  });

  test('restore rejects foreign keys before changing any stored data', () async {
    SharedPreferences.setMockInitialValues({
      'offynex_writer_documents': 'original',
    });
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      WorkspaceBackupRestore.restore(prefs, {
        'offynex_writer_documents': 'replacement',
        'another_app_private_data': 'must not be written',
      }),
      throwsFormatException,
    );
    expect(prefs.getString('offynex_writer_documents'), 'original');
    expect(prefs.containsKey('another_app_private_data'), isFalse);
  });

  test('backup codec enforces the documented 25 MB limit', () {
    final oversized = List<String>.filled(WorkspaceBackupCodec.maxBackupBytes + 1, 'x').join();
    expect(() => WorkspaceBackupCodec.decode(oversized), throwsFormatException);
  });

  test('restore replaces only included keys and preserves unrelated data', () async {
    SharedPreferences.setMockInitialValues({
      'offynex_writer_documents': 'old',
      'offynex_language_bangla_v1': true,
      'unrelated': 'keep',
    });
    final prefs = await SharedPreferences.getInstance();
    await WorkspaceBackupRestore.restore(prefs, {
      'offynex_writer_documents': 'new',
      'offynex_sheets_workbook_v1': 'sheet',
    });
    expect(prefs.getString('offynex_writer_documents'), 'new');
    expect(prefs.getString('offynex_sheets_workbook_v1'), 'sheet');
    expect(prefs.getBool('offynex_language_bangla_v1'), true);
    expect(prefs.getString('unrelated'), 'keep');
  });

  test('restore rejects unsupported runtime values without partial changes', () async {
    SharedPreferences.setMockInitialValues({
      'offynex_writer_documents': 'old',
    });
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      WorkspaceBackupRestore.restore(prefs, {
        'offynex_writer_documents': 'new',
        'offynex_invalid': <int>[1, 2],
      }),
      throwsFormatException,
    );
    expect(prefs.getString('offynex_writer_documents'), 'old');
    expect(prefs.containsKey('offynex_invalid'), isFalse);
  });
}
