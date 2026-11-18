import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/forms_response_csv_codec.dart';

void main() {
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
}
