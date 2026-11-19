import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/portable_workspace_backup_service.dart';
import 'package:offynexbd/lib/modules/workspace/workspace_backup_codec.dart';

void main() {
  test('portable backup includes Writer images, scanned PDFs and all app preferences', () async {
    final root = await Directory.systemTemp.createTemp('offynex-portable-');
    final sourceImages = Directory('${root.path}/source/images');
    final sourceScans = Directory('${root.path}/source/scans');
    final targetImages = Directory('${root.path}/target/images');
    final targetScans = Directory('${root.path}/target/scans');
    await sourceImages.create(recursive: true);
    await sourceScans.create(recursive: true);
    try {
      final image = File('${sourceImages.path}/photo.png');
      final scan = File('${sourceScans.path}/scan.pdf');
      await image.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 1, 2]);
      await scan.writeAsBytes([37, 80, 68, 70, 45, 49, 46, 55, 1, 2]);
      final source = <String, Object?>{
        'offynex_writer_documents': jsonEncode([
          {'id': 'writer-1', 'title': 'Photo document', 'content': [
            {'insert': {'image': image.path}}, {'insert': '\n'},
          ]},
        ]),
        'offynex_workspace_scan_v1': jsonEncode([
          {'id': 'scan-1', 'title': 'Scanned pages', 'content': 'OCR', 'updatedAt': '2026-11-19T00:00:00Z', 'scanPdfPath': scan.path},
        ]),
        'offynex_language_bangla_v1': true,
        'offynex_sheets_workbook_v1': '{"workbook":"preserved"}',
      };
      final archive = await PortableWorkspaceBackupService.exportArchive(
        source,
        writerImageDirectory: sourceImages,
        scanDirectory: sourceScans,
      );
      final restored = await PortableWorkspaceBackupService.importArchive(
        archive,
        writerImageDirectory: targetImages,
        scanDirectory: targetScans,
      );
      expect(restored['offynex_language_bangla_v1'], true);
      expect(restored['offynex_sheets_workbook_v1'], source['offynex_sheets_workbook_v1']);
      final writer = jsonDecode(restored['offynex_writer_documents']! as String) as List;
      final restoredImage = (((writer.single as Map)['content'] as List).first as Map)['insert']['image'] as String;
      expect(restoredImage, isNot(image.path));
      expect(await File(restoredImage).readAsBytes(), await image.readAsBytes());
      final scans = jsonDecode(restored['offynex_workspace_scan_v1']! as String) as List;
      final restoredScan = (scans.single as Map)['scanPdfPath'] as String;
      expect(restoredScan, isNot(scan.path));
      expect(await File(restoredScan).readAsBytes(), await scan.readAsBytes());
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('portable backup rejects local asset paths outside managed folders', () async {
    final root = await Directory.systemTemp.createTemp('offynex-portable-guard-');
    final images = Directory('${root.path}/images');
    final scans = Directory('${root.path}/scans');
    final outside = File('${root.path}/outside.png');
    try {
      await images.create();
      await scans.create();
      await outside.writeAsBytes([1, 2, 3]);
      await expectLater(
        PortableWorkspaceBackupService.exportArchive({
          'offynex_writer_documents': jsonEncode([
            {'id': 'writer-2', 'title': 'Unsafe', 'content': [
              {'insert': {'image': outside.path}},
            ]},
          ]),
        }, writerImageDirectory: images, scanDirectory: scans),
        throwsA(isA<StateError>()),
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('portable backup rejects corrupt and oversized archive input', () async {
    final root = await Directory.systemTemp.createTemp('offynex-portable-invalid-');
    try {
      await expectLater(
        PortableWorkspaceBackupService.importArchive(
          Uint8List.fromList([1, 2, 3]),
          writerImageDirectory: Directory('${root.path}/images'),
          scanDirectory: Directory('${root.path}/scans'),
        ),
        throwsA(anything),
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('portable backup rejects duplicate manifests and mismatched asset folders', () async {
    final root = await Directory.systemTemp.createTemp('offynex-portable-entries-');
    try {
      final manifest = utf8.encode(WorkspaceBackupCodec.encode({}));
      final invalidArchives = <Archive>[
        Archive()
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest)),
        Archive()
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
          ..addFile(ArchiveFile('writer-images/asset_1.pdf', 3, [1, 2, 3])),
        Archive()
          ..addFile(ArchiveFile('../outside.png', 3, [1, 2, 3]))
          ..addFile(ArchiveFile('manifest.json', manifest.length, manifest)),
      ];
      for (final invalid in invalidArchives) {
        final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(invalid));
        await expectLater(
          PortableWorkspaceBackupService.importArchive(
            bytes,
            writerImageDirectory: Directory('${root.path}/images'),
            scanDirectory: Directory('${root.path}/scans'),
          ),
          throwsA(isA<FormatException>()),
        );
      }
    } finally {
      await root.delete(recursive: true);
    }
  });

}
