import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_document_backup_service.dart';

void main() {
  test('portable Writer backup embeds images and restores them to a new folder', () async {
    final source = await Directory.systemTemp.createTemp('writer-backup-source-');
    final target = await Directory.systemTemp.createTemp('writer-backup-target-');
    try {
      final image = File('${source.path}/sample.png');
      await image.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
      final documents = <Map<String, dynamic>>[
        {
          'id': 'portable-1',
          'title': 'Portable document',
          'content': [
            {'insert': 'Before'},
            {'insert': {'image': image.path}},
            {'insert': '\n'},
          ],
        },
      ];
      final bytes = await WriterDocumentBackupService.exportArchive(
        documents,
        imageDirectory: source,
      );
      expect(bytes.length, greaterThan(100));
      final restored = await WriterDocumentBackupService.importArchive(
        bytes,
        imageDirectory: target,
      );
      final restoredPath = ((restored.single['content'] as List)[1] as Map)['insert']['image'] as String;
      expect(restoredPath, isNot(image.path));
      expect(await File(restoredPath).exists(), isTrue);
      expect(await File(restoredPath).readAsBytes(), [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
    } finally {
      await source.delete(recursive: true);
      await target.delete(recursive: true);
    }
  });

  test('portable Writer backup refuses image paths outside the app image directory', () async {
    final allowed = await Directory.systemTemp.createTemp('writer-backup-allowed-');
    final outside = await Directory.systemTemp.createTemp('writer-backup-outside-');
    try {
      final image = File('${outside.path}/private.png');
      await image.writeAsBytes([1, 2, 3]);
      await expectLater(
        WriterDocumentBackupService.exportArchive([
          {'id': 'outside', 'title': 'Outside', 'content': [{'insert': {'image': image.path}}]},
        ], imageDirectory: allowed),
        throwsA(isA<StateError>()),
      );
    } finally {
      await allowed.delete(recursive: true);
      await outside.delete(recursive: true);
    }
  });

}
