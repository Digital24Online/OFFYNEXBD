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
      if (label.isEmpty ||
          (type == 'choice' &&
              (parts.length < 3 ||
                  parts.skip(1).any((value) => value.isEmpty) ||
                  parts.skip(1).toSet().length != parts.length - 1))) {
        throw const FormatException('A choice question needs a label and at least two unique options.');
      }
      questions.add({
        'type': type,
        'label': label,
        'required': match.group(1) != null,
        'options': type == 'choice' ? parts.skip(1).toList(growable: false) : <String>[],
      });
    }
    if (questions.length > 100) {
      throw const FormatException('A form can contain up to 100 questions.');
    }
    return questions;
  }
}
