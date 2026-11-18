import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'workspace_backup_codec.dart';

/// Portable app backup that packages SharedPreferences plus local Writer
/// images and scanned PDFs. Online sync is intentionally a separate feature.
class PortableWorkspaceBackupService {
  static const int maxArchiveBytes = 25 * 1024 * 1024;
  static const int maxExpandedBytes = 100 * 1024 * 1024;
  static const int maxFiles = 2000;
  static const String _assetPrefix = 'offynex-asset://';

  static Future<Uint8List> exportArchive(
    Map<String, Object?> source, {
    required Directory writerImageDirectory,
    required Directory scanDirectory,
  }) async {
    await writerImageDirectory.create(recursive: true);
    await scanDirectory.create(recursive: true);
    final writerRoot = await writerImageDirectory.resolveSymbolicLinks();
    final scanRoot = await scanDirectory.resolveSymbolicLinks();
    final data = Map<String, Object?>.from(source);
    final archive = Archive();
    final packaged = <String, String>{};
    var expandedBytes = 0;
    var assetNumber = 0;

    Future<String> packageAsset(String rawPath, String kind) async {
      if (rawPath.startsWith('http://') || rawPath.startsWith('https://') ||
          rawPath.startsWith('data:') || rawPath.startsWith(_assetPrefix)) {
        return rawPath;
      }
      final file = File(rawPath);
      if (!file.isAbsolute) {
        throw StateError('A local OFFYNEXBD asset path is not absolute.');
      }
      final canonical = await file.resolveSymbolicLinks();
      final root = kind == 'writer-images' ? writerRoot : scanRoot;
      if (!canonical.startsWith('$root${Platform.pathSeparator}')) {
        throw StateError('A local OFFYNEXBD asset is outside its managed folder.');
      }
      if (packaged.containsKey(canonical)) return packaged[canonical]!;
      final bytes = await File(canonical).readAsBytes();
      if (bytes.isEmpty) throw StateError('An OFFYNEXBD asset is empty: $rawPath');
      expandedBytes += bytes.length;
      if (expandedBytes > maxExpandedBytes) {
        throw const FormatException('Portable backup expands beyond 100 MB.');
      }
      final extension = canonical.split('.').last.toLowerCase();
      final allowed = kind == 'writer-images'
          ? const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}
          : const {'pdf'};
      if (!allowed.contains(extension)) {
        throw FormatException('Unsupported $kind asset type: $extension');
      }
      final archivePath = '$kind/asset_${++assetNumber}.$extension';
      archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      final token = '$_assetPrefix$archivePath';
      packaged[canonical] = token;
      return token;
    }

    final writerRaw = data['offynex_writer_documents'];
    if (writerRaw is String) {
      final decoded = jsonDecode(writerRaw);
      if (decoded is! List) throw const FormatException('Writer library backup is invalid.');
      for (final rawDocument in decoded) {
        if (rawDocument is! Map) continue;
        final document = Map<String, dynamic>.from(rawDocument);
        final content = document['content'];
        if (content is List) {
          for (var index = 0; index < content.length; index++) {
            final operation = content[index];
            if (operation is! Map) continue;
            final insert = operation['insert'];
            if (insert is Map && insert['image'] is String) {
              final image = insert['image'] as String;
              final rewritten = await packageAsset(image, 'writer-images');
              if (rewritten != image) {
                final updatedOperation = Map<String, dynamic>.from(operation);
                updatedOperation['insert'] = {...Map<String, dynamic>.from(insert), 'image': rewritten};
                content[index] = updatedOperation;
              }
            }
          }
        }
        final scanPath = document['scanPdfPath'];
        if (scanPath is String) document['scanPdfPath'] = await packageAsset(scanPath, 'scan-pdfs');
      }
      data['offynex_writer_documents'] = jsonEncode(decoded);
    }

    final scanRaw = data['offynex_workspace_scan_v1'];
    if (scanRaw is String) {
      final decoded = jsonDecode(scanRaw);
      if (decoded is! List) throw const FormatException('Scan library backup is invalid.');
      for (final rawRecord in decoded) {
        if (rawRecord is! Map) continue;
        final record = Map<String, dynamic>.from(rawRecord);
        final scanPath = record['scanPdfPath'];
        if (scanPath is String) record['scanPdfPath'] = await packageAsset(scanPath, 'scan-pdfs');
      }
      data['offynex_workspace_scan_v1'] = jsonEncode(decoded);
    }

    final manifest = utf8.encode(WorkspaceBackupCodec.encode(data));
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    if (archive.files.length > maxFiles) {
      throw const FormatException('Portable backup contains too many files.');
    }
    final output = ZipEncoder().encodeBytes(archive);
    if (output.length > maxArchiveBytes) {
      throw const FormatException('Portable backup exceeds the 25 MB file limit.');
    }
    return Uint8List.fromList(output);
  }

  static Future<Map<String, Object?>> importArchive(
    Uint8List bytes, {
    required Directory writerImageDirectory,
    required Directory scanDirectory,
  }) async {
    if (bytes.isEmpty || bytes.length > maxArchiveBytes) {
      throw const FormatException('Portable backup must be between 1 byte and 25 MB.');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.length > maxFiles) {
      throw const FormatException('Portable backup contains too many files.');
    }
    final expanded = archive.files.fold<int>(0, (total, file) => total + file.size);
    if (expanded > maxExpandedBytes) {
      throw const FormatException('Portable backup expands beyond 100 MB.');
    }
    final manifest = archive.findFile('manifest.json');
    final manifestBytes = manifest?.readBytes();
    if (manifestBytes == null || manifestBytes.length > WorkspaceBackupCodec.maxBackupBytes) {
      throw const FormatException('Portable backup manifest is missing or invalid.');
    }
    final data = WorkspaceBackupCodec.decode(utf8.decode(manifestBytes, allowMalformed: false));
    await writerImageDirectory.create(recursive: true);
    await scanDirectory.create(recursive: true);
    final restored = <String, String>{};
    final createdFiles = <File>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;

    Future<String> restoreAsset(String token) async {
      if (!token.startsWith(_assetPrefix)) return token;
      final archivePath = token.substring(_assetPrefix.length);
      final isImage = archivePath.startsWith('writer-images/');
      final isPdf = archivePath.startsWith('scan-pdfs/');
      if (!isImage && !isPdf) throw const FormatException('Portable backup has an unknown asset path.');
      final name = archivePath.split('/').last;
      if (!RegExp(r'^asset_\d+\.(png|jpg|jpeg|webp|gif|bmp|pdf)$').hasMatch(name) ||
          archivePath.contains('..') || archivePath.startsWith('/')) {
        throw const FormatException('Portable backup has an unsafe asset path.');
      }
      if (restored.containsKey(archivePath)) return restored[archivePath]!;
      final entry = archive.findFile(archivePath);
      final content = entry?.readBytes();
      if (content == null || content.isEmpty) throw const FormatException('A backup asset is missing.');
      final directory = isImage ? writerImageDirectory : scanDirectory;
      final extension = name.split('.').last;
      final target = File('${directory.path}/offynex_restore_${stamp}_${restored.length}.$extension');
      await target.writeAsBytes(content, flush: true);
      createdFiles.add(target);
      restored[archivePath] = target.path;
      return target.path;
    }

    Future<void> rewriteWriter() async {
      final raw = data['offynex_writer_documents'];
      if (raw is! String) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Writer library in backup is invalid.');
      for (final rawDocument in decoded) {
        if (rawDocument is! Map) continue;
        final document = Map<String, dynamic>.from(rawDocument);
        final content = document['content'];
        if (content is List) {
          for (var index = 0; index < content.length; index++) {
            final operation = content[index];
            if (operation is! Map) continue;
            final insert = operation['insert'];
            if (insert is Map && insert['image'] is String) {
              final image = await restoreAsset(insert['image'] as String);
              final updated = Map<String, dynamic>.from(operation);
              updated['insert'] = {...Map<String, dynamic>.from(insert), 'image': image};
              content[index] = updated;
            }
          }
        }
        final scanPath = document['scanPdfPath'];
        if (scanPath is String) document['scanPdfPath'] = await restoreAsset(scanPath);
      }
      data['offynex_writer_documents'] = jsonEncode(decoded);
    }

    try {
      await rewriteWriter();
      final scanRaw = data['offynex_workspace_scan_v1'];
      if (scanRaw is String) {
        final decoded = jsonDecode(scanRaw);
        if (decoded is! List) throw const FormatException('Scan library in backup is invalid.');
        for (final rawRecord in decoded) {
          if (rawRecord is! Map) continue;
          final record = Map<String, dynamic>.from(rawRecord);
          final path = record['scanPdfPath'];
          if (path is String) record['scanPdfPath'] = await restoreAsset(path);
        }
        data['offynex_workspace_scan_v1'] = jsonEncode(decoded);
      }
      return data;
    } catch (_) {
      for (final file in createdFiles) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }
}
