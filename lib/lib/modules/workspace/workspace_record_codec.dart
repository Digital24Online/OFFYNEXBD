import 'dart:convert';

/// Portable, module-scoped record interchange format.
class WorkspaceRecordCodec {
  static const format = 'OFFYNEXBD_WORKSPACE_RECORDS';
  static const version = 1;
  static const int maxFileBytes = 10 * 1024 * 1024;
  static const supportedModules = <String>{
    'Slides',
    'Fonts',
    'AI Assistant',
    'Forms',
    'Database',
    'Cloud',
    'Scan',
  };

  static String encode(
    String module,
    List<Map<String, dynamic>> records, {
    DateTime? createdAt,
  }) {
    if (!supportedModules.contains(module)) {
      throw ArgumentError.value(module, 'module', 'Unsupported workspace module');
    }
    final encoded = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'module': module,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'records': _validateRecords(records),
    });
    if (utf8.encode(encoded).length > maxFileBytes) {
      throw const FormatException('Workspace export exceeds the 10 MB limit.');
    }
    return encoded;
  }

  static List<Map<String, dynamic>> decode(
    String source, {
    required String expectedModule,
  }) {
    if (utf8.encode(source).length > maxFileBytes) {
      throw const FormatException('Workspace import exceeds the 10 MB limit.');
    }
    if (!supportedModules.contains(expectedModule)) {
      throw ArgumentError.value(expectedModule, 'expectedModule');
    }
    final dynamic decoded = jsonDecode(source);
    if (decoded is! Map ||
        decoded['format'] != format ||
        decoded['version'] != version ||
        decoded['module'] != expectedModule ||
        decoded['records'] is! List) {
      throw const FormatException('Unsupported or mismatched workspace file.');
    }
    final records = (decoded['records'] as List).map((item) {
      if (item is! Map) {
        throw const FormatException('Workspace record must be an object.');
      }
      return Map<String, dynamic>.from(item);
    }).toList(growable: false);
    return _validateRecords(records);
  }

  static List<Map<String, dynamic>> _validateRecords(
    List<Map<String, dynamic>> records,
  ) {
    if (records.length > 10000) {
      throw const FormatException('Workspace file contains too many records.');
    }
    final ids = <String>{};
    return records.map((record) {
      final id = record['id'];
      final title = record['title'];
      final content = record['content'];
      final updatedAt = record['updatedAt'];
      if (id is! String ||
          id.trim().isEmpty ||
          !ids.add(id) ||
          title is! String ||
          title.trim().isEmpty ||
          content is! String ||
          updatedAt is! String ||
          DateTime.tryParse(updatedAt) == null) {
        throw const FormatException('Workspace file contains an invalid record.');
      }
      // Keep module-specific fields (for example scanPdfPath, pageCount,
      // OCR metadata and future record extensions) intact during export/import.
      // Rebuilding only the four core fields silently discarded user data.
      return Map<String, dynamic>.from(record);
    }).toList(growable: false);
  }
}
