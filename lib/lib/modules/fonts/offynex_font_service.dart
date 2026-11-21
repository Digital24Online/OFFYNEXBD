import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Validates, stores and loads app-scoped TrueType/OpenType fonts.
/// Fonts are never installed into the Android operating system.
class OffynexFontService {
  OffynexFontService._();

  static const int maxFontBytes = 25 * 1024 * 1024;
  static const int maxTables = 256;

  static String validateAndReadFamily(Uint8List bytes) {
    if (bytes.length < 12 || bytes.length > maxFontBytes) {
      throw const FormatException('Font must be between 12 bytes and 25 MB.');
    }
    final data = ByteData.sublistView(bytes);
    final signature = data.getUint32(0, Endian.big);
    const supported = {0x00010000, 0x4F54544F, 0x74727565, 0x74797031};
    if (!supported.contains(signature)) {
      throw const FormatException('Only valid TTF and OTF font files are supported.');
    }
    final tableCount = data.getUint16(4, Endian.big);
    if (tableCount == 0 || tableCount > maxTables ||
        12 + tableCount * 16 > bytes.length) {
      throw const FormatException('Font table directory is invalid.');
    }

    int? nameOffset;
    int? nameLength;
    int? maxpOffset;
    int? maxpLength;
    for (var i = 0; i < tableCount; i++) {
      final entry = 12 + i * 16;
      final tag = String.fromCharCodes(bytes.sublist(entry, entry + 4));
      final offset = data.getUint32(entry + 8, Endian.big);
      final length = data.getUint32(entry + 12, Endian.big);
      if (offset > bytes.length || length > bytes.length - offset) {
        throw const FormatException('Font contains an out-of-bounds table.');
      }
      if (tag == 'name') {
        nameOffset = offset;
        nameLength = length;
      } else if (tag == 'maxp') {
        maxpOffset = offset;
        maxpLength = length;
      }
    }
    if (nameOffset == null || nameLength == null || nameLength < 6 ||
        maxpOffset == null || maxpLength == null || maxpLength < 6) {
      throw const FormatException('Font is missing required name or glyph tables.');
    }
    final glyphCount = data.getUint16(maxpOffset + 4, Endian.big);
    if (glyphCount == 0 || glyphCount > 65535) {
      throw const FormatException('Font glyph table is invalid.');
    }

    final nameData = ByteData.sublistView(bytes, nameOffset, nameOffset + nameLength);
    final count = nameData.getUint16(2, Endian.big);
    final stringOffset = nameData.getUint16(4, Endian.big);
    if (count == 0 || 6 + count * 12 > nameLength || stringOffset > nameLength) {
      throw const FormatException('Font family metadata is invalid.');
    }
    String? family;
    for (var i = 0; i < count; i++) {
      final record = 6 + i * 12;
      final platform = nameData.getUint16(record, Endian.big);
      final nameId = nameData.getUint16(record + 6, Endian.big);
      final length = nameData.getUint16(record + 8, Endian.big);
      final offset = nameData.getUint16(record + 10, Endian.big);
      if (nameId != 1 && nameId != 16) continue;
      final start = stringOffset + offset;
      if (start > nameLength || length > nameLength - start) continue;
      final raw = bytes.sublist(nameOffset + start, nameOffset + start + length);
      String candidate;
      if (platform == 0 || platform == 3) {
        if (raw.length.isOdd) continue;
        final units = <int>[];
        for (var j = 0; j < raw.length; j += 2) {
          units.add((raw[j] << 8) | raw[j + 1]);
        }
        candidate = String.fromCharCodes(units);
      } else {
        candidate = String.fromCharCodes(raw.where((value) => value >= 32));
      }
      candidate = candidate.trim();
      if (candidate.isNotEmpty) {
        family = candidate;
        if (platform == 3 || platform == 0) break;
      }
    }
    if (family == null) {
      throw const FormatException('Font family name could not be read.');
    }
    return family;
  }

  static Future<({File file, String family})> importFont(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    final family = validateAndReadFamily(bytes);
    final extension = sourceName.split('.').last.toLowerCase();
    if (extension != 'ttf' && extension != 'otf') {
      throw const FormatException('Choose a .ttf or .otf font file.');
    }
    final directory = await getApplicationSupportDirectory();
    final fonts = Directory('${directory.path}/OFFYNEXBD/Fonts');
    await fonts.create(recursive: true);
    final safeFamily = family.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final target = File('${fonts.path}/${safeFamily}_${bytes.length}.$extension');
    final pending = File('${target.path}.pending');
    try {
      await pending.writeAsBytes(bytes, flush: true);
      if (await pending.length() != bytes.length) {
        throw const FileSystemException('Font file was not completely written.');
      }
      final saved = await pending.rename(target.path);
      return (file: saved, family: family);
    } catch (_) {
      if (await pending.exists()) await pending.delete();
      rethrow;
    }
  }

  static Future<void> activate(Uint8List bytes, String family) async {
    final validatedFamily = validateAndReadFamily(bytes);
    if (validatedFamily != family) {
      throw const FormatException('Font family metadata changed after validation.');
    }
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
