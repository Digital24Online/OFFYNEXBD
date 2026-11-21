/// Backward-compatible parser for Forms questions.
///
/// Legacy lines remain optional short-text questions. New forms may use:
///   required text: Full name
///   email: Work email
///   number: Number of attendees
///   date: Preferred date
///   choice: Department | Sales | Support | Accounts
class FormsQuestionCodec {
  const FormsQuestionCodec._();

  static const _types = {'text', 'email', 'number', 'date', 'choice'};
  static const maxQuestions = 100;
  static const maxChoiceOptions = 50;
  static const maxLabelLength = 200;
  static const maxOptionLength = 100;

  static List<Map<String, dynamic>> parse(String source) {
    final questions = <Map<String, dynamic>>[];
    for (final rawLine in source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = RegExp(
        r'^(required\s+)?(text|email|number|date|choice)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) {
        questions.add({
          'type': 'text',
          'label': line,
          'required': false,
          'options': <String>[],
        });
        continue;
      }
      final type = match.group(2)!.toLowerCase();
      final rawLabel = match.group(3)!.trim();
      if (!_types.contains(type) || rawLabel.isEmpty) {
        throw const FormatException('A Forms question has an invalid type or empty label.');
      }
      final parts = type == 'choice'
          ? rawLabel.split('|').map((value) => value.trim()).toList(growable: false)
          : <String>[rawLabel];
      final label = parts.first;
      final options = type == 'choice' ? parts.skip(1).toList(growable: false) : const <String>[];
      final normalizedOptions = options.map((value) => value.toLowerCase()).toSet();
      if (label.isEmpty || label.length > maxLabelLength) {
        throw const FormatException('A question label must contain 1–200 characters.');
      }
      if (type == 'choice' &&
          (options.length < 2 ||
              options.length > maxChoiceOptions ||
              options.any((value) => value.isEmpty || value.length > maxOptionLength) ||
              normalizedOptions.length != options.length)) {
        throw const FormatException('A choice question needs 2–50 unique options of up to 100 characters each.');
      }
      questions.add({
        'type': type,
        'label': label,
        'required': match.group(1) != null,
        'options': options,
      });
    }
    if (questions.length > maxQuestions) {
      throw const FormatException('A form can contain up to 100 questions.');
    }
    return questions;
  }
}
