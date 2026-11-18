import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

 
/// Applies a backup as one recoverable operation. If any preference write
/// fails, all touched keys are returned to their pre-restore values.
class WorkspaceBackupRestore {
  static Future<void> restore(
    SharedPreferences prefs,
    Map<String, Object?> data,
  ) async {
    final before = <String, Object?>{
      for (final key in data.keys)
        if (prefs.containsKey(key)) key: prefs.get(key),
    };
    try {
      for (final entry in data.entries) {
        final value = entry.value;
        final bool saved;
        if (value is String) {
          saved = await prefs.setString(entry.key, value);
        } else if (value is bool) {
          saved = await prefs.setBool(entry.key, value);
        } else if (value is int) {
          saved = await prefs.setInt(entry.key, value);
        } else if (value is double) {
          saved = await prefs.setDouble(entry.key, value);
        } else if (value is List<String>) {
          saved = await prefs.setStringList(entry.key, value);
        } else {
          throw FormatException('Unsupported backup value for ${entry.key}.');
        }
        if (!saved) throw StateError('Could not restore ${entry.key}.');
      }
    } catch (error) {
      Object? rollbackError;
      for (final key in data.keys.toList().reversed) {
        try {
          if (!before.containsKey(key)) {
            final removed = await prefs.remove(key);
            if (!removed && prefs.containsKey(key)) {
              throw StateError('Could not remove partially restored $key.');
            }
            continue;
          }
          final value = before[key];
          final bool restored;
          if (value is String) {
            restored = await prefs.setString(key, value);
          } else if (value is bool) {
            restored = await prefs.setBool(key, value);
          } else if (value is int) {
            restored = await prefs.setInt(key, value);
          } else if (value is double) {
            restored = await prefs.setDouble(key, value);
          } else if (value is List<String>) {
            restored = await prefs.setStringList(key, value);
          } else {
            throw StateError('Unsupported existing preference type for $key.');
          }
          if (!restored) throw StateError('Could not roll back $key.');
        } catch (rollback) {
          rollbackError ??= rollback;
        }
      }
      if (rollbackError != null) {
        throw StateError('Restore failed ($error); rollback also failed ($rollbackError).');
      }
      rethrow;
    }
  }
}
