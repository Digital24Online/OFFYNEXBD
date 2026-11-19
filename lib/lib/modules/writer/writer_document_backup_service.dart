import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'writer_document_codec.dart';

/// Portable Writer backup: document records plus every referenced local image.
class WriterDocumentBackupService {
  static const int maxArchiveBytes = 25 * 1024 * 1024;
  static const int maxImageBytes = 15 * 1024 * 1024;
  static const int maxExpandedBytes = 60 * 1024 * 1024;
  static const String _assetPrefix = 'offynexbd-asset://';

  static Future<Uint8List> exportArchive(
    List<Map<String, dynamic>> documents, {
    required Directory imageDirectory,
  }) async {
    final portable = jsonDecode(jsonEncode(documents)) as List;
    final archive = Archive();
    final seen = <String, String>{};
    var assetIndex = 0;
    var expandedBytes = 0;
    for (final rawDocument in portable) {
      final document = Map<String, dynamic>.from(rawDocument as Map);
      final content = document['content'];
      if (content is List) {
        for (final rawOperation in content) {
          if (rawOperation is! Map) continue;
          final operation = Map<String, dynamic>.from(rawOperation);
          final insert = operation['insert'];
          if (insert is Map && insert['image'] is String) {
            final path = insert['image'] as String;
            if (!seen.containsKey(path)) {
              final image = File(path);
              await imageDirectory.create(recursive: true);
              final allowedRoot = await imageDirectory.resolveSymbolicLinks();
              if (!await image.exists()) {
                throw StateError('Writer image is missing; backup was not created: $path');
              }
              final resolvedImage = await image.resolveSymbolicLinks();
              final allowedPrefix = '$allowedRoot${Platform.pathSeparator}';
              if (!resolvedImage.startsWith(allowedPrefix)) {
                throw StateError('Writer image resolves outside the app image folder; backup was blocked.');
              }
              final bytes = await image.readAsBytes();
              if (bytes.isEmpty || bytes.length > maxImageBytes) {
                throw const FormatException('Writer image is empty or exceeds the 15 MB limit.');
              }
              expandedBytes += bytes.length;
              if (expandedBytes > maxExpandedBytes) {
                throw const FormatException('Writer backup expands beyond the 60 MB safety limit.');
              }
              final extension = _safeExtension(path);
              final archivePath = 'images/image_${++assetIndex}.$extension';
              archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
              seen[path] = archivePath;
            }
            operation['insert'] = {'image': '$_assetPrefix${seen[path]}'};
            content[content.indexOf(rawOperation)] = operation;
          }
        }
      }
      final index = portable.indexOf(rawDocument);
      portable[index] = document;
    }
    final normalized = portable.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final manifest = utf8.encode(WriterDocumentCodec.encode(normalized));
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    final output = ZipEncoder().encodeBytes(archive);
    if (output.length > maxArchiveBytes) {
      throw const FormatException('Writer backup exceeds the 25 MB limit.');
    }
    return Uint8List.fromList(output);
  }

  static Future<List<Map<String, dynamic>>> importArchive(
    Uint8List bytes, {
    required Directory imageDirectory,
  }) async {
    if (bytes.isEmpty || bytes.length > maxArchiveBytes) {
      throw const FormatException('Writer backup is empty or exceeds the 25 MB limit.');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.length > 2000) {
      throw const FormatException('Writer backup contains too many files.');
    }
    final expandedBytes = archive.files.fold<int>(0, (total, file) => total + file.size);
    if (expandedBytes > maxExpandedBytes) {
      throw const FormatException('Writer backup expands beyond the 60 MB safety limit.');
    }
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('Writer backup manifest is missing.');
    }
    final manifestBytes = manifestFile.readBytes();
    if (manifestBytes == null || manifestBytes.length > maxArchiveBytes) {
      throw const FormatException('Writer backup manifest is invalid.');
    }
    final documents = WriterDocumentCodec.decode(utf8.decode(manifestBytes, allowMalformed: false));
    await imageDirectory.create(recursive: true);
    final extracted = <String, String>{};
    final createdFiles = <File>[];
    try {
      for (final document in documents) {
      final content = document['content'];
      if (content is! List) continue;
      for (final rawOperation in content) {
        if (rawOperation is! Map) continue;
        final insert = rawOperation['insert'];
        if (insert is! Map || insert['image'] is! String) continue;
        final source = insert['image'] as String;
        if (!source.startsWith(_assetPrefix)) continue;
        final archivePath = source.substring(_assetPrefix.length);
        if (archivePath.startsWith('/') || archivePath.contains('..') || !archivePath.startsWith('images/')) {
          throw const FormatException('Writer backup contains an unsafe image path.');
        }
          if (!extracted.containsKey(archivePath)) {
            final file = archive.findFile(archivePath);
            final data = file?.readBytes();
            if (data == null || data.isEmpty || data.length > maxImageBytes) {
              throw const FormatException('Writer backup image is missing or invalid.');
            }
            final extension = _safeExtension(archivePath);
            final target = File('${imageDirectory.path}/backup_${DateTime.now().microsecondsSinceEpoch}_${extracted.length}.$extension');
            await target.writeAsBytes(data, flush: true);
            createdFiles.add(target);
            extracted[archivePath] = target.path;
          }
          insert['image'] = extracted[archivePath]!;
        }
      }
      return documents;
    } catch (_) {
      for (final file in createdFiles.reversed) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Preserve the original import error; cleanup is best-effort.
        }
      }
      rethrow;
    }
  }

  static String _safeExtension(String path) {
    final raw = path.split('.').last.toLowerCase();
    return const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}.contains(raw) ? raw : 'png';
  }
}

// Archive assets are constrained to the app-owned Writer image directory.
