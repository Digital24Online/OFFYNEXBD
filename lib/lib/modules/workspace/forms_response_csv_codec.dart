/// Converts local OFFYNEXBD Forms responses into a spreadsheet-friendly CSV.
class FormsResponseCsvCodec {
  const FormsResponseCsvCodec._();

  static String encode(List<Map<String, dynamic>> responses) {
    if (responses.isEmpty) {
      throw const FormatException('There are no form responses to export.');
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
          submittedAt is! String ||
          DateTime.tryParse(submittedAt) == null ||
          answers is! List) {
        throw const FormatException('A form response contains invalid metadata.');
      }
      final answerValues = <String, String>{};
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
        final key = '$formId\u0000$question';
        final label = '$formTitle — $question';
        if (!labels.containsKey(key)) {
          columns.add(key);
          labels[key] = label;
        }
        answerValues.putIfAbsent(key, () => answer['answer'] as String);
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
    String quote(String value) => '"\${value.replaceAll('"', '""')}"';
    final csv = rows.map((row) => row.map(quote).join(',')).join('\r\n');
    // UTF-8 BOM helps spreadsheet applications detect Bengali text correctly.
    return '\uFEFF$csv\r\n';
  }
}
