import 'dart:convert';

/// Converts local OFFYNEXBD Forms responses into a spreadsheet-friendly CSV.
class FormsResponseCsvCodec {
  const FormsResponseCsvCodec._();

  static const int maxCsvBytes = 10 * 1024 * 1024;
  static const int maxResponses = 100000;
  static const int maxAnswerColumns = 512;
  static const int maxCsvCells = 100000;

  static List<Map<String, dynamic>> filter(
    List<Map<String, dynamic>> responses,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return List<Map<String, dynamic>>.of(responses);
    return responses.where((response) {
      final formTitle = response['formTitle']?.toString().toLowerCase() ?? '';
      final submittedAt = response['submittedAt']?.toString().toLowerCase() ?? '';
      if (formTitle.contains(normalized) || submittedAt.contains(normalized)) {
        return true;
      }
      final answers = response['answers'];
      if (answers is! List) return false;
      return answers.any((answer) {
        if (answer is! Map) return false;
        final question = answer['question']?.toString().toLowerCase() ?? '';
        final value = answer['answer']?.toString().toLowerCase() ?? '';
        return question.contains(normalized) || value.contains(normalized);
      });
    }).toList(growable: false);
  }

  static String encode(List<Map<String, dynamic>> responses) {
    if (responses.isEmpty) {
      throw const FormatException('There are no form responses to export.');
    }
    if (responses.length > maxResponses) {
      throw const FormatException('Forms CSV exceeds the 100,000-response limit.');
    }
    final columns = <String>[];
    final labels = <String, String>{};
    final normalized = <Map<String, dynamic>>[];
    for (final response in responses) {
      final formId = response['formId'];
      final formTitle = response['formTitle'];
      final submittedAt = response['submittedAt'];
      final answers = response['answers'];
      if (formId is! String ||
          formId.trim().isEmpty ||
          formTitle is! String ||
          formTitle.trim().isEmpty ||
          submittedAt is! String ||
          DateTime.tryParse(submittedAt) == null ||
          answers is! List) {
        throw const FormatException('A form response contains invalid metadata.');
      }
      final answerValues = <String, String>{};
      final questionOccurrences = <String, int>{};
      for (final answer in answers) {
        if (answer is! Map ||
            answer['question'] is! String ||
            answer['answer'] is! String) {
          throw const FormatException('A form response contains an invalid answer.');
        }
        final question = (answer['question'] as String).trim();
        if (question.isEmpty) {
          throw const FormatException('A form response contains an empty question.');
        }
        // Two fields may intentionally share the same visible question text.
        // Keep their ordinal position so CSV export never silently drops one.
        final occurrence = (questionOccurrences[question] ?? 0) + 1;
        questionOccurrences[question] = occurrence;
        final key = '$formId\u0000$question\u0000$occurrence';
        final suffix = occurrence == 1 ? '' : ' ($occurrence)';
        final label = '$formTitle — $question$suffix';
        if (!labels.containsKey(key)) {
          if (columns.length >= maxAnswerColumns) {
            throw const FormatException('Forms CSV exceeds the 512-answer-column limit.');
          }
          columns.add(key);
          labels[key] = label;
        }
        answerValues[key] = answer['answer'] as String;
      }
      if ((normalized.length + 1) * (columns.length + 2) > maxCsvCells) {
        throw const FormatException('Forms CSV exceeds the 100,000-cell export limit.');
      }
      normalized.add({
        'formTitle': formTitle,
        'submittedAt': submittedAt,
        'answers': answerValues,
      });
    }
    final rows = <List<String>>[
      <String>[
        'Form',
        'Submitted At',
        for (final key in columns) labels[key]!,
      ],
      for (final response in normalized)
        <String>[
          response['formTitle'] as String,
          response['submittedAt'] as String,
          for (final key in columns)
            (response['answers'] as Map<String, String>)[key] ?? '',
        ],
    ];
    String safeCell(String value) {
      final trimmed = value.trimLeft();
      if (trimmed.isNotEmpty && '=+-@'.contains(trimmed[0])) return "'$value";
      return value;
    }
    String quote(String value) {
      final safe = safeCell(value);
      final escaped = safe.replaceAll('"', '""');
      return '"$escaped"';
    }
    final csv = rows.map((row) => row.map(quote).join(',')).join('\r\n');
    // UTF-8 BOM helps spreadsheet applications detect Bengali text correctly.
    final result = '\uFEFF$csv\r\n';
    if (utf8.encode(result).length > maxCsvBytes) {
      throw const FormatException('Forms CSV exceeds the 10 MB export limit.');
    }
    return result;
  }
}
