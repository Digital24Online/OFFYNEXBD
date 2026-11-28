import 'dart:convert';

/// Versioned slide-text document codec with backward-compatible legacy parsing.
class SlidesDocumentCodec {
  const SlidesDocumentCodec._();

  static const String format = 'OFFYNEXBD_SLIDES';
  static const int version = 1;
  static const int maxSlides = 200;
  static const int maxTextBytes = 5 * 1024 * 1024;

  /// Reads the current structured representation or legacy one-line-per-slide text.
  static List<String> decode(String source) {
    if (utf8.encode(source).length > maxTextBytes) {
      throw const FormatException('Presentation content exceeds the 5 MB limit.');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return _decodeLegacy(source);
    }
    if (decoded is Map && decoded['format'] == format) {
      if (decoded['version'] != version || decoded['slides'] is! List) {
        throw const FormatException('Unsupported or invalid OFFYNEXBD Slides document.');
      }
      final rawSlides = decoded['slides'] as List;
      if (rawSlides.isEmpty || rawSlides.length > maxSlides) {
        throw const FormatException('A presentation must contain 1–200 slides.');
      }
      if (rawSlides.any((value) => value is! String)) {
        throw const FormatException('Every slide must contain text.');
      }
      return List<String>.unmodifiable(rawSlides.cast<String>());
    }
    return _decodeLegacy(source);
  }

  static String encode(List<String> slides) {
    if (slides.isEmpty || slides.length > maxSlides) {
      throw const FormatException('A presentation must contain 1–200 slides.');
    }
    final normalized = slides.map((value) => value.replaceAll('\r\n', '\n').replaceAll('\r', '\n')).toList(growable: false);
    final result = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'slides': normalized,
    });
    if (utf8.encode(result).length > maxTextBytes) {
      throw const FormatException('Presentation content exceeds the 5 MB limit.');
    }
    return result;
  }

  static List<String> _decodeLegacy(String source) {
    final slides = source
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (slides.length > maxSlides) {
      throw const FormatException('A presentation can contain up to 200 slides.');
    }
    return slides;
  }
}
