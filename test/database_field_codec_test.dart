import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/database_field_codec.dart';

void main() {
  test('legacy comma-separated fields remain optional text fields', () {
    final fields = DatabaseFieldCodec.parse('Name, Phone, Address');
    expect(fields.map((field) => field.name), ['Name', 'Phone', 'Address']);
    expect(fields.every((field) => field.type == 'text' && !field.required), isTrue);
  });

  test('typed fields parse required markers, types and choice options', () {
    final fields = DatabaseFieldCodec.parse(
      'required Name:text, Age:number, Email:email, Joined:date, '
      'Department:choice|Sales|Support',
    );
    expect(fields.map((field) => field.type),
        ['text', 'number', 'email', 'date', 'choice']);
    expect(fields.first.required, isTrue);
    expect(fields[1].required, isFalse);
    expect(fields.last.options, ['Sales', 'Support']);
  });

  test('rejects duplicate names, unsupported types and malformed choices', () {
    expect(() => DatabaseFieldCodec.parse('Name, name'), throwsFormatException);
    expect(() => DatabaseFieldCodec.parse('Age:currency'), throwsFormatException);
    expect(() => DatabaseFieldCodec.parse('Team:choice|Sales'), throwsFormatException);
    expect(() => DatabaseFieldCodec.parse('Team:choice|Sales|Sales'), throwsFormatException);
  });

  test('rejects empty and excessive field definitions', () {
    expect(() => DatabaseFieldCodec.parse(' , '), throwsFormatException);
    expect(
      () => DatabaseFieldCodec.parse(List.generate(41, (i) => 'F$i').join(',')),
      throwsFormatException,
    );
  });
}
