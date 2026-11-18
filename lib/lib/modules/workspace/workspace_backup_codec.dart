import 'dart:convert';

/// Versioned, app-scoped backup format shared by every OFFYNEXBD module.
class WorkspaceBackupCodec {
  static const format = 'OFFYNEXBD_LOCAL_BACKUP';
  static const version = 1;

  static String encode(Map<String, Object?> data, {DateTime? createdAt}) {
    final safeData = <String, Object?>{};
    for (final entry in data.entries) {
      if (!entry.key.startsWith('offynex_')) continue;
      final value = entry.value;
      if (value is String || value is bool || value is int || value is double) {
        safeData[entry.key] = value;
      } else if (value is List<String>) {
        safeData[entry.key] = value;
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'data': safeData,
    });
  }

  static Map<String, Object?> decode(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map ||
        decoded['format'] != format ||
        decoded['version'] != version ||
        decoded['data'] is! Map) {
      throw const FormatException('Unsupported OFFYNEXBD backup.');
    }

    final data = <String, Object?>{};
    for (final entry in (decoded['data'] as Map).entries) {
      if (entry.key is! String ||
          !(entry.key as String).startsWith('offynex_')) {
        throw const FormatException('Backup contains an invalid app data key.');
      }
      final value = entry.value;
      if (value is String || value is bool || value is int || value is double) {
        data[entry.key as String] = value;
      } else if (value is List && value.every((item) => item is String)) {
        data[entry.key as String] = value.cast<String>();
      } else {
        throw const FormatException('Backup contains an unsupported data value.');
      }
    }
    return data;
  }
}
