import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/forms_answer_validator.dart';

void main() {
  group('FormsAnswerValidator', () {
    test('validates required and optional values', () {
      expect(
        FormsAnswerValidator.validate(type: 'text', value: '  ', isRequired: true),
        FormsAnswerValidator.requiredError,
      );
      expect(
        FormsAnswerValidator.validate(type: 'text', value: '  ', isRequired: false),
        isNull,
      );
    });

    test('rejects malformed email addresses', () {
      expect(
        FormsAnswerValidator.validate(type: 'email', value: 'person@localhost', isRequired: false),
        FormsAnswerValidator.emailError,
      );
      expect(
        FormsAnswerValidator.validate(type: 'email', value: 'person @example.com', isRequired: false),
        FormsAnswerValidator.emailError,
      );
      expect(
        FormsAnswerValidator.validate(type: 'email', value: 'person@example.com', isRequired: false),
        isNull,
      );
    });

    test('rejects non-finite and malformed numbers', () {
      for (final value in ['abc', 'NaN', 'Infinity', '-Infinity']) {
        expect(
          FormsAnswerValidator.validate(type: 'number', value: value, isRequired: false),
          FormsAnswerValidator.numberError,
        );
      }
      expect(
        FormsAnswerValidator.validate(type: 'number', value: '-12.5', isRequired: false),
        isNull,
      );
    });

    test('requires a real calendar date in ISO format', () {
      for (final value in ['2026-02-30', '2026-13-01', '26-01-01', '2026-1-01']) {
        expect(
          FormsAnswerValidator.validate(type: 'date', value: value, isRequired: false),
          FormsAnswerValidator.dateError,
        );
      }
      expect(
        FormsAnswerValidator.validate(type: 'date', value: '2024-02-29', isRequired: false),
        isNull,
      );
    });
  });
}
