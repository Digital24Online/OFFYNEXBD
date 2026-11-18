/// Safe list-based data validation rules for spreadsheet cells.
class SheetsDataValidation {
  const SheetsDataValidation._();

  static const int maxOptions = 100;
  static const int maxOptionLength = 200;

  static List<String> parseOptions(String source) {
    final options = source
        .split(RegExp(r'\\r?\\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (options.isEmpty || options.length > maxOptions ||
        options.any((value) => value.length > maxOptionLength)) {
      throw const FormatException(
        'Enter between 1 and 100 options; each option must be 200 characters or less.',
      );
    }
    if (options.toSet().length != options.length) {
      throw const FormatException('Dropdown options must be unique.');
    }
    return options;
  }

  static bool accepts(String value, List<String>? options) =>
      value.isEmpty || options == null || options.contains(value);
}
