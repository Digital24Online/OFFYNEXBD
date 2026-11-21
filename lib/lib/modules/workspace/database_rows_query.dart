/// Search and stable sorting for local Database rows.
///
/// This is a view operation: it never mutates the stored row list or row values.
class DatabaseRowsQuery {
  const DatabaseRowsQuery._();

  static List<Map<String, dynamic>> apply({
    required List<Map<String, dynamic>> rows,
    required List<String> fields,
    String query = '',
    String? sortField,
    bool ascending = true,
  }) {
    final needle = query.trim().toLowerCase();
    final matches = <({Map<String, dynamic> row, int index})>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final rawValues = row['values'];
      final values = rawValues is Map ? rawValues : const <Object?, Object?>{};
      if (needle.isNotEmpty && !fields.any((field) =>
          (values[field]?.toString() ?? '').toLowerCase().contains(needle))) {
        continue;
      }
      matches.add((row: row, index: index));
    }

    if (sortField != null && fields.contains(sortField)) {
      int compare(String left, String right) {
        final leftNumber = num.tryParse(left.trim());
        final rightNumber = num.tryParse(right.trim());
        if (leftNumber != null && rightNumber != null) {
          return leftNumber.compareTo(rightNumber);
        }
        final leftDate = DateTime.tryParse(left.trim());
        final rightDate = DateTime.tryParse(right.trim());
        if (leftDate != null && rightDate != null) {
          return leftDate.compareTo(rightDate);
        }
        return left.toLowerCase().compareTo(right.toLowerCase());
      }

      matches.sort((a, b) {
        final aValues = a.row['values'];
        final bValues = b.row['values'];
        final av = aValues is Map ? aValues[sortField]?.toString() ?? '' : '';
        final bv = bValues is Map ? bValues[sortField]?.toString() ?? '' : '';
        final result = compare(av, bv);
        if (result == 0) return a.index.compareTo(b.index);
        return ascending ? result : -result;
      });
    }
    return List<Map<String, dynamic>>.unmodifiable(
      matches.map((entry) => entry.row),
    );
  }
}
