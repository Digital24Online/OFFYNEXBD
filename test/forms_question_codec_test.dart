import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/forms_question_codec.dart';

void main() {
  group('FormsQuestionCodec', () {
    test('keeps legacy one-line questions as optional short text', () {
      expect(
        FormsQuestionCodec.parse('Name\nEmail address'),
        [
          {'type': 'text', 'label': 'Name', 'required': false, 'options': <String>[]},
          {'type': 'text', 'label': 'Email address', 'required': false, 'options': <String>[]},
        ],
      );
    });

    test('parses typed, required and choice questions', () {
      expect(
        FormsQuestionCodec.parse(
          'required text: Full name\nemail: Work email\nnumber: Attendees\ndate: Visit date\nchoice: Department | Sales | Support',
        ),
        [
          {'type': 'text', 'label': 'Full name', 'required': true, 'options': <String>[]},
          {'type': 'email', 'label': 'Work email', 'required': false, 'options': <String>[]},
          {'type': 'number', 'label': 'Attendees', 'required': false, 'options': <String>[]},
          {'type': 'date', 'label': 'Visit date', 'required': false, 'options': <String>[]},
          {'type': 'choice', 'label': 'Department', 'required': false, 'options': ['Sales', 'Support']},
        ],
      );
    });

    test('rejects choice questions with fewer than two unique options', () {
      expect(
        () => FormsQuestionCodec.parse('choice: Department | Sales | Sales'),
        throwsFormatException,
      );
      expect(
        () => FormsQuestionCodec.parse('choice: Department | Sales'),
        throwsFormatException,
      );
    });

    test('rejects duplicate options ignoring letter case and oversized choices', () {
      expect(
        () => FormsQuestionCodec.parse('choice: Department | Sales | sales'),
        throwsFormatException,
      );
      final tooMany = ['Department', ...List.generate(51, (index) => 'Option $index')].join(' | ');
      expect(() => FormsQuestionCodec.parse('choice: $tooMany'), throwsFormatException);
      final tooLong = List.filled(101, 'x').join();
      expect(
        () => FormsQuestionCodec.parse('choice: Department | $tooLong | Support'),
        throwsFormatException,
      );
    });

    test('limits forms to 100 questions', () {
      expect(
        () => FormsQuestionCodec.parse(List.filled(101, 'Question').join('\n')),
        throwsFormatException,
      );
    });
  });
}
