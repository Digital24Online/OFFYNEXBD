import 'dart:convert';

/// Reads legacy one-line-per-slide records and the structured v1 slide format.
class SlidesContentCodec {
  static const String marker = 'OFFYNEXBD_SLIDES_V1\n';
  static const int maxSlides = 200;
  static const int maxTextBytes = 5 * 1024 * 1024;

  static List<String> decode(String? source) {
    final value = source ?? '';
    if (value.startsWith(marker)) {
      final decoded = jsonDecode(value.substring(marker.length));
      if (decoded is! List ||
          decoded.length > maxSlides ||
          decoded.any((item) => item is! String)) {
        throw const FormatException('Invalid OFFYNEXBD slide document.');
      }
      final slides = decoded.cast<String>();
      if (utf8.encode(slides.join('\n')).length > maxTextBytes) {
        throw const FormatException('Slide text exceeds the 5 MB limit.');
      }
      return slides;
    }
    if (utf8.encode(value).length > maxTextBytes) {
      throw const FormatException('Legacy slide content exceeds supported limits.');
    }
    final slides = value
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (slides.length > maxSlides) {
      throw const FormatException('Legacy slide content exceeds supported limits.');
    }
    return slides;
  }

  static String encode(List<String> slides) {
    if (slides.isEmpty ||
        slides.length > maxSlides ||
        slides.any((item) => item.trim().isEmpty) ||
        utf8.encode(slides.join('\n')).length > maxTextBytes) {
      throw const FormatException('Slide content exceeds supported limits.');
    }
    return marker + jsonEncode(slides);
  }
}
