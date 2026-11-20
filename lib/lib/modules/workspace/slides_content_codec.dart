import 'dart:convert';

/// Reads legacy one-line-per-slide records and the structured v1 slide format.
class SlidesContentCodec {
  static const String marker = 'OFFYNEXBD_SLIDES_V1\n';

  static List<String> decode(String? source) {
    final value = source ?? '';
    if (value.startsWith(marker)) {
      final decoded = jsonDecode(value.substring(marker.length));
      if (decoded is! List || decoded.any((item) => item is! String)) {
        throw const FormatException('Invalid OFFYNEXBD slide document.');
      }
      return decoded.cast<String>();
    }
    return value
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String encode(List<String> slides) {
    return '$marker${jsonEncode(slides)}';
  }
}
