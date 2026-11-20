import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/forms_response_csv_codec.dart';

void main() {
  test('filters form responses by title, question, answer and date', () {
    final responses = <Map<String, dynamic>>[
      {
        'formId': 'f1',
        'formTitle': 'গ্রাহক নিবন্ধন',
        'submittedAt': '2026-11-18T10:00:00.000Z',
        'answers': [
          {'question': 'নাম', 'answer': 'রহিম'},
          {'question': 'এলাকা', 'answer': 'গাজীপুর'},
        ],
      },
      {
        'formId': 'f2',
        'formTitle': 'সেবা মতামত',
        'submittedAt': '2026-11-17T10:00:00.000Z',
        'answers': [
          {'question': 'মতামত', 'answer': 'ভালো'},
        ],
      },
    ];

    expect(FormsResponseCsvCodec.filter(responses, 'নিবন্ধন'), [responses[0]]);
    expect(FormsResponseCsvCodec.filter(responses, 'এলাকা'), [responses[0]]);
    expect(FormsResponseCsvCodec.filter(responses, 'গাজীপুর'), [responses[0]]);
    expect(FormsResponseCsvCodec.filter(responses, '2026-11-17'), [responses[1]]);
    expect(FormsResponseCsvCodec.filter(responses, 'missing'), isEmpty);
    expect(FormsResponseCsvCodec.filter(responses, '  '), responses);
  });


  test('exports Bengali answers and escapes CSV delimiters and quotes', () {
    final csv = FormsResponseCsvCodec.encode([
      {
        'id': 'r1',
        'formId': 'f1',
        'formTitle': 'গ্রাহক ফর্ম',
        'submittedAt': '2026-11-18T10:00:00.000Z',
        'answers': [
          {'question': 'নাম', 'answer': 'রহিম, "মিয়া"'},
          {'question': 'মতামত', 'answer': 'ভালো\nখুব ভালো'},
        ],
      },
    ]);
    expect(csv, startsWith('\uFEFF'));
    expect(csv, contains('"গ্রাহক ফর্ম — নাম"'));
    expect(csv, contains('"রহিম, ""মিয়া"""'));
    expect(csv, contains('"ভালো\nখুব ভালো"'));
    expect(csv, endsWith('\r\n'));
  });

  test('keeps different forms separate when question labels match', () {
    final csv = FormsResponseCsvCodec.encode([
      {
        'id': 'r1',
        'formId': 'f1',
        'formTitle': 'প্রথম ফর্ম',
        'submittedAt': '2026-11-18T10:00:00.000Z',
        'answers': [{'question': 'নাম', 'answer': 'রহিম'}],
      },
      {
        'id': 'r2',
        'formId': 'f2',
        'formTitle': 'দ্বিতীয় ফর্ম',
        'submittedAt': '2026-11-18T11:00:00.000Z',
        'answers': [{'question': 'নাম', 'answer': 'করিম'}],
      },
    ]);
    expect(csv, contains('"প্রথম ফর্ম — নাম","দ্বিতীয় ফর্ম — নাম"'));
    expect(csv, contains('"রহিম",""'));
    expect(csv, contains('"করিম"'));
  });

  test('rejects empty or malformed response archives', () {
    expect(() => FormsResponseCsvCodec.encode([]), throwsFormatException);
    expect(
      () => FormsResponseCsvCodec.encode([
        {
          'formId': 'f1',
          'formTitle': 'Form',
          'submittedAt': 'not-a-date',
          'answers': [],
        },
      ]),
      throwsFormatException,
    );
    expect(
      () => FormsResponseCsvCodec.encode([
        {
          'formId': 'f1',
          'formTitle': 'Form',
          'submittedAt': '2026-11-18T10:00:00.000Z',
          'answers': [{'question': '', 'answer': 'value'}],
        },
      ]),
      throwsFormatException,
    );
  });
  test('rejects oversized response counts, answer columns and CSV output', () {
    final tooManyResponses = List<Map<String, dynamic>>.generate(
      FormsResponseCsvCodec.maxResponses + 1,
      (index) => {
        'formId': 'f$index',
        'formTitle': 'Form $index',
        'submittedAt': '2026-11-18T10:00:00.000Z',
        'answers': <Map<String, String>>[],
      },
      growable: false,
    );
    expect(
      () => FormsResponseCsvCodec.encode(tooManyResponses),
      throwsFormatException,
    );

    final tooManyColumns = <Map<String, dynamic>>[
      {
        'formId': 'f1',
        'formTitle': 'Form',
        'submittedAt': '2026-11-18T10:00:00.000Z',
        'answers': [
          for (var index = 0;
              index <= FormsResponseCsvCodec.maxAnswerColumns;
              index++)
            {'question': 'Q$index', 'answer': 'A'},
        ],
      },
    ];
    expect(
      () => FormsResponseCsvCodec.encode(tooManyColumns),
      throwsFormatException,
    );

    expect(
      () => FormsResponseCsvCodec.encode([
        {
          'formId': 'f1',
          'formTitle': 'Form',
          'submittedAt': '2026-11-18T10:00:00.000Z',
          'answers': [
            {'question': 'Large answer', 'answer': 'x' * FormsResponseCsvCodec.maxCsvBytes},
          ],
        },
      ]),
      throwsFormatException,
    );
  });

  test('neutralizes spreadsheet formulas in response values and headers', () {
    final csv = FormsResponseCsvCodec.encode([
      {
        'formId': 'f1',
        'formTitle': '=HYPERLINK("https://bad.example")',
        'submittedAt': '2026-11-18T10:00:00.000Z',
        'answers': [
          {'question': 'Command', 'answer': '+cmd'},
          {'question': 'Formula', 'answer': '=1+1'},
          {'question': 'Name', 'answer': '  @SUM(A1:A2)'},
        ],
      },
    ]);
    expect(csv, contains("'=HYPERLINK"));
    expect(csv, contains("'+cmd"));
    expect(csv, contains("'=1+1"));
    expect(csv, contains("'  @SUM"));
  });

}
