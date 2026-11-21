/// Shared validation for Forms response fields.
/// Date values are intentionally strict YYYY-MM-DD calendar dates; Dart's
/// DateTime parser otherwise accepts some normalized/overflowing date input.
class FormsAnswerValidator {
  const FormsAnswerValidator._();

  static const requiredError = 'required';
  static const emailError = 'email';
  static const numberError = 'number';
  static const dateError = 'date';
  static const choiceError = 'choice';
  static const typeError = 'type';

  static String? validate({
    required String type,
    required String value,
    required bool required,
    List<String>? allowedValues,
  }) {
    final normalized = value.trim();
    if (required && normalized.isEmpty) return requiredError;
    if (normalized.isEmpty) return null;

    switch (type) {
      case 'email':
        final emailPattern = RegExp(
          r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$",
          caseSensitive: false,
        );
        if (!emailPattern.hasMatch(normalized)) return emailError;
        break;
      case 'number':
        final number = num.tryParse(normalized);
        if (number == null || !number.isFinite) return numberError;
        break;
      case 'choice':
        if (allowedValues == null || !allowedValues.contains(normalized)) {
          return choiceError;
        }
        break;
      case 'text':
        break;
      case 'date':
        final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(normalized);
        if (match == null) return dateError;
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        final date = DateTime(year, month, day);
        if (date.year != year || date.month != month || date.day != day) {
          return dateError;
        }
        break;
      default:
        return typeError;
    }
    return null;
  }
}
