/// Backward-compatible typed field definitions for the offline Database module.
///
/// Legacy comma-separated field names remain optional text fields.
/// Typed syntax: `required Name:text, Age:number, Email:email,
/// Joined:date, Department:choice|Sales|Support`.
class DatabaseField {
  const DatabaseField({
    required this.name,
    required this.type,
    required this.required,
    this.options = const <String>[],
  });

  final String name;
  final String type;
  final bool required;
  final List<String> options;
}

class DatabaseFieldCodec {
  const DatabaseFieldCodec._();

  static const supportedTypes = <String>{
    'text', 'number', 'email', 'date', 'choice',
  };
  static const maxFields = 40;
  static const maxChoiceOptions = 20;

  static List<DatabaseField> parse(String source) {
    final definitions = source
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (definitions.isEmpty || definitions.length > maxFields) {
      throw const FormatException('Define between 1 and 40 database fields.');
    }

    final fields = <DatabaseField>[];
    final names = <String>{};
    for (final definition in definitions) {
      final colon = definition.indexOf(':');
      final rawName = (colon < 0 ? definition : definition.substring(0, colon)).trim();
      final isRequired = rawName.toLowerCase().startsWith('required ');
      final name = (isRequired ? rawName.substring(9) : rawName).trim();
      if (name.isEmpty || name.length > 120 || !names.add(name.toLowerCase())) {
        throw const FormatException('Database field names must be unique and contain 1–120 characters.');
      }

      if (colon < 0) {
        fields.add(DatabaseField(name: name, type: 'text', required: false));
        continue;
      }

      final rawType = definition.substring(colon + 1).trim();
      final parts = rawType.split('|').map((part) => part.trim()).toList();
      final type = parts.first.toLowerCase();
      if (!supportedTypes.contains(type)) {
        throw FormatException('Unsupported database field type: $type.');
      }
      final options = type == 'choice'
          ? parts.skip(1).where((value) => value.isNotEmpty).toList(growable: false)
          : const <String>[];
      if (type == 'choice' &&
          (options.length < 2 ||
              options.length > maxChoiceOptions ||
              options.toSet().length != options.length)) {
        throw const FormatException('Choice fields need 2–20 unique options.');
      }
      if (type != 'choice' && parts.length != 1) {
        throw const FormatException('Only choice fields may define pipe-separated options.');
      }
      fields.add(DatabaseField(
        name: name,
        type: type,
        required: isRequired,
        options: options,
      ));
    }
    return List<DatabaseField>.unmodifiable(fields);
  }
}
