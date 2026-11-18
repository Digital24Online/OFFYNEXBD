import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('damaged Writer library is copied to recovery storage, not discarded', () async {
    const damaged = '{"not":"a list"}';
    SharedPreferences.setMockInitialValues({
      documentsKey: damaged,
    });

    final documents = await loadDocuments();
    final prefs = await SharedPreferences.getInstance();
    final recoveryKeys = prefs.getKeys()
        .where((key) => key.startsWith('offynex_writer_documents_recovery_'))
        .toList();

    expect(documents, isEmpty);
    expect(recoveryKeys, hasLength(1));
    expect(prefs.getString(recoveryKeys.single), damaged);
    expect(prefs.getString(documentsKey), damaged);
    expect(writerDataRecoveryNotice, contains(recoveryKeys.single));

    await expectLater(
      storeDocuments([
        {'id': 'new-doc', 'title': 'New document', 'content': ''},
      ]),
      throwsStateError,
    );
    expect(prefs.getString(documentsKey), damaged);
  });

  test('malformed document content is preserved and blocks library writes', () async {
    const damaged = '[{"id":"doc-1","title":"Damaged","content":[{"attributes":{"bold":true}}]}]';
    SharedPreferences.setMockInitialValues({documentsKey: damaged});

    final documents = await loadDocuments();
    final prefs = await SharedPreferences.getInstance();
    final recoveryKeys = prefs.getKeys()
        .where((key) => key.startsWith('offynex_writer_documents_recovery_'))
        .toList();

    expect(documents, isEmpty);
    expect(writerLibraryDataBlocked, isTrue);
    expect(recoveryKeys, hasLength(1));
    expect(prefs.getString(recoveryKeys.single), damaged);
    expect(prefs.getString(documentsKey), damaged);
    await expectLater(
      storeDocuments([
        {'id': 'replacement', 'title': 'Replacement', 'content': ''},
      ]),
      throwsStateError,
    );
    expect(prefs.getString(documentsKey), damaged);
  });
}
