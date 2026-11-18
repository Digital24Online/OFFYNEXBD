import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_data_validation.dart';

void main() {
  group('SheetsDataValidation', () {
    test('parses trimmed options and removes blank lines', () {
      expect(
        SheetsDataValidation.parseOptions(' Pending \\n\\nPaid\\nDue '),
        ['Pending', 'Paid', 'Due'],
      );
    });

    test('rejects empty, duplicate, excessive and oversized options', () {
      expect(() => SheetsDataValidation.parseOptions('\\n  '), throwsFormatException);
      expect(() => SheetsDataValidation.parseOptions('A\\nA'), throwsFormatException);
      expect(
        () => SheetsDataValidation.parseOptions(
          List.generate(101, (index) => 'Option $index').join('\\n'),
        ),
        throwsFormatException,
      );
      expect(
        () => SheetsDataValidation.parseOptions('X' * 201),
        throwsFormatException,
      );
    });

    test('allows empty values and otherwise enforces exact dropdown values', () {
      const options = ['Pending', 'Paid'];
      expect(SheetsDataValidation.accepts('', options), isTrue);
      expect(SheetsDataValidation.accepts('Paid', options), isTrue);
      expect(SheetsDataValidation.accepts('paid', options), isFalse);
      expect(SheetsDataValidation.accepts('Due', options), isFalse);
      expect(SheetsDataValidation.accepts('anything', null), isTrue);
    });
  });
}
