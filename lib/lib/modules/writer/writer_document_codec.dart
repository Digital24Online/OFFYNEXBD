import 'dart:convert';

/// Validated interchange format for complete Writer document records.
class WriterDocumentCodec {
  static const format = 'OFFYNEXBD_WRITER_DOCUMENTS';
  static const version = 1;
  static const maxDocuments = 10000;
  static const int maxArchiveBytes = 25 * 1024 * 1024;

  static String encode(
    List<Map<String, dynamic>> documents, {
    DateTime? createdAt,
  }) {
    final safe = _validate(documents);
    final encoded = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'documents': safe,
    });
    if (utf8.encode(encoded).length > maxArchiveBytes) {
      throw const FormatException('Writer archive exceeds the 25 MB limit.');
    }
    return encoded;
  }

  static List<Map<String, dynamic>> decode(String source) {
    if (utf8.encode(source).length > maxArchiveBytes) {
      throw const FormatException('Writer archive exceeds the 25 MB limit.');
    }
    final dynamic decoded = jsonDecode(source);
    if (decoded is! Map ||
        decoded['format'] != format ||
        decoded['version'] != version ||
        decoded['documents'] is! List) {
      throw const FormatException('Unsupported Writer document file.');
    }
    final documents = (decoded['documents'] as List).map((item) {
      if (item is! Map) {
        throw const FormatException('Writer document must be an object.');
      }
      return Map<String, dynamic>.from(item);
    }).toList(growable: false);
    return _validate(documents);
  }

  static List<Map<String, dynamic>> validateLibraryRecords(
    List<Map<String, dynamic>> documents,
  ) => _validate(documents);

  static List<Map<String, dynamic>> _validate(
    List<Map<String, dynamic>> documents,
  ) {
    if (documents.length > maxDocuments) {
      throw const FormatException('Too many Writer documents.');
    }
    final ids = <String>{};
    for (final document in documents) {
      final id = document['id'];
      final title = document['title'];
      final content = document['content'];
      if (id is! String ||
          id.trim().isEmpty ||
          !ids.add(id) ||
          title is! String ||
          title.trim().isEmpty ||
          (content is! String && content is! List)) {
        throw const FormatException('Invalid Writer document record.');
      }
      if (content is List) {
        for (final operation in content) {
          if (operation is! Map || !operation.containsKey('insert')) {
            throw const FormatException('Writer document contains an invalid text operation.');
          }
          final insert = operation['insert'];
          if (insert is! String && insert is! Map) {
            throw const FormatException('Writer document contains an unsupported insert operation.');
          }
          final attributes = operation['attributes'];
          if (attributes != null && attributes is! Map) {
            throw const FormatException('Writer text attributes must be an object.');
          }
          if (insert is Map) {
            final isImage = insert.length == 1 && insert['image'] is String;
            final isTable = insert.length == 1 && insert['offynexbd-writer-table'] is String;
            if (!isImage && !isTable) {
              throw const FormatException('Writer document contains an unsupported embedded object.');
            }
          }
        }
      }
      try {
        jsonEncode(document);
      } on JsonUnsupportedObjectError {
        throw const FormatException('Writer document contains unsupported data.');
      }
    }
    return documents;
  }
}
