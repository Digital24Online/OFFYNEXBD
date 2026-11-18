/// Builds a display-only row order for sorting and filtering.
/// Worksheet cells and formula references are never moved.
class SheetsRowView {
  const SheetsRowView._();

  static List<int> buildOrder({
    required int rowCount,
    required String Function(int row) valueForRow,
    String? filter,
    bool? sortAscending,
  }) {
    final rows = List<int>.generate(rowCount, (index) => index);
    final query = filter?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      rows.removeWhere((row) => !valueForRow(row).toLowerCase().contains(query));
    }
    if (sortAscending != null) {
      rows.sort((a, b) {
        final left = valueForRow(a).trim();
        final right = valueForRow(b).trim();
        if (left.isEmpty && right.isNotEmpty) return 1;
        if (right.isEmpty && left.isNotEmpty) return -1;
        final leftNumber = double.tryParse(left);
        final rightNumber = double.tryParse(right);
        int comparison;
        if (leftNumber != null && rightNumber != null) {
          comparison = leftNumber.compareTo(rightNumber);
        } else if (leftNumber != null) {
          comparison = -1;
        } else if (rightNumber != null) {
          comparison = 1;
        } else {
          comparison = left.toLowerCase().compareTo(right.toLowerCase());
        }
        if (comparison == 0) return a.compareTo(b);
        return sortAscending ? comparison : -comparison;
      });
    }
    return rows;
  }
}
