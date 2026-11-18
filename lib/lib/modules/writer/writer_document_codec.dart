import 'dart:convert';

/// Validated interchange format for complete Writer document records.
class WriterDocumentCodec {
  static const format = 'OFFYNEXBD_WRITER_DOCUMENTS';
  static const version = 1;
  static const maxDocuments = 10000;

  static String encode(
    List<Map<String, dynamic>> documents, {
    DateTime? createdAt,
  }) {
    final safe = _validate(documents);
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'documents': safe,
    });
  }

  static List<Map<String, dynamic>> decode(String source) {
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
      if (id is! String ||
          id.trim().isEmpty ||
          !ids.add(id) ||
          title is! String ||
          title.trim().isEmpty ||
          !document.containsKey('content')) {
        throw const FormatException('Invalid Writer document record.');
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
