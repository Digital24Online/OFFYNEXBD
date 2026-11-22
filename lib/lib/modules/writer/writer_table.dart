import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Custom Quill block for Writer tables.
/// Keep this type unchanged so previously saved table blocks remain readable.
class WriterTableBlockEmbed extends CustomBlockEmbed {
  static const String embedType = 'offynexbd-writer-table';

  const WriterTableBlockEmbed(String value) : super(embedType, value);

  /// Existing tables default to a header row for backward compatibility,
  /// while an explicit false value must survive editing and round-trips.
  static bool hasHeaderRow(Map<String, dynamic> data) {
    final value = data['headerRow'];
    return value is bool ? value : true;
  }

  /// Reads merged-cell rectangles without changing the legacy rows matrix.
  /// Each entry is {row, column, rowSpan, columnSpan}; invalid/overlapping
  /// entries are discarded so old or malformed documents remain editable.
  static List<Map<String, int>> normalizedMerges(
    Map<String, dynamic> data, {
    required int rowCount,
    required int columnCount,
  }) {
    final raw = data['merges'];
    if (raw is! List || rowCount < 1 || columnCount < 1) {
      return <Map<String, int>>[];
    }
    final result = <Map<String, int>>[];
    final occupied = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final row = item['row'];
      final column = item['column'];
      final rowSpan = item['rowSpan'];
      final columnSpan = item['columnSpan'];
      if (row is! int || column is! int ||
          rowSpan is! int || columnSpan is! int ||
          row < 0 || column < 0 || rowSpan < 1 || columnSpan < 1 ||
          row + rowSpan > rowCount || column + columnSpan > columnCount ||
          (rowSpan == 1 && columnSpan == 1)) {
        continue;
      }
      final keys = <String>[
        for (var r = row; r < row + rowSpan; r++)
          for (var c = column; c < column + columnSpan; c++) '$r:$c',
      ];
      if (keys.any(occupied.contains)) continue;
      occupied.addAll(keys);
      result.add(<String, int>{
        'row': row,
        'column': column,
        'rowSpan': rowSpan,
        'columnSpan': columnSpan,
      });
    }
    return result;
  }

  /// Merges a rectangular selection into its top-left cell. Text from other
  /// cells is retained in order, separated by newlines, rather than discarded.
  static Map<String, dynamic> mergeCells(
    Map<String, dynamic> data, {
    required int firstRow,
    required int firstColumn,
    required int lastRow,
    required int lastColumn,
  }) {
    final rawRows = data['rows'];
    if (rawRows is! List || rawRows.isEmpty) {
      throw ArgumentError('Cannot merge an empty Writer table.');
    }
    final rows = rawRows.map<List<String>>((row) =>
      row is List ? row.map((v) => v?.toString() ?? '').toList()
                  : <String>[row?.toString() ?? '']
    ).toList();
    final rowCount = rows.length;
    final columnCount = rows.fold<int>(1,
      (max, row) => row.length > max ? row.length : max);
    for (final row in rows) {
      while (row.length < columnCount) { row.add(''); }
    }
    final top = firstRow < lastRow ? firstRow : lastRow;
    final bottom = firstRow > lastRow ? firstRow : lastRow;
    final left = firstColumn < lastColumn ? firstColumn : lastColumn;
    final right = firstColumn > lastColumn ? firstColumn : lastColumn;
    if (top < 0 || left < 0 || bottom >= rowCount || right >= columnCount ||
        (top == bottom && left == right)) {
      throw ArgumentError('Select at least two valid Writer table cells.');
    }
    final merges = normalizedMerges(data,
      rowCount: rowCount, columnCount: columnCount);
    for (final merge in merges) {
      final r0 = merge['row']!;
      final c0 = merge['column']!;
      final r1 = r0 + merge['rowSpan']! - 1;
      final c1 = c0 + merge['columnSpan']! - 1;
      final intersects = top <= r1 && bottom >= r0 &&
          left <= c1 && right >= c0;
      final contained = top <= r0 && bottom >= r1 &&
          left <= c0 && right >= c1;
      if (intersects && !contained) {
        throw ArgumentError('Selection cuts through an existing merged cell.');
      }
    }
    final values = <String>[];
    for (var r = top; r <= bottom; r++) {
      for (var c = left; c <= right; c++) {
        final value = rows[r][c];
        if (value.isNotEmpty) values.add(value);
      }
    }
    rows[top][left] = values.join('\n');
    for (var r = top; r <= bottom; r++) {
      for (var c = left; c <= right; c++) {
        if (r != top || c != left) rows[r][c] = '';
      }
    }
    final kept = merges.where((merge) {
      final r = merge['row']!, c = merge['column']!;
      return !(r >= top && r + merge['rowSpan']! - 1 <= bottom &&
          c >= left && c + merge['columnSpan']! - 1 <= right);
    }).toList();
    kept.add(<String, int>{
      'row': top, 'column': left,
      'rowSpan': bottom - top + 1,
      'columnSpan': right - left + 1,
    });
    return <String, dynamic>{...data, 'rows': rows, 'merges': kept};
  }

  /// Splits a merged rectangle at its top-left anchor. Covered cells become
  /// empty cells; the anchor's text is preserved.
  static Map<String, dynamic> splitCell(
    Map<String, dynamic> data, {
    required int row,
    required int column,
  }) {
    final rawRows = data['rows'];
    final rows = rawRows is List ? rawRows : const <dynamic>[];
    final columns = rows.fold<int>(1, (max, item) =>
      item is List && item.length > max ? item.length : max);
    final merges = normalizedMerges(data,
      rowCount: rows.length, columnCount: columns);
    final remaining = merges.where((merge) =>
      merge['row'] != row || merge['column'] != column).toList();
    if (remaining.length == merges.length) return Map<String, dynamic>.from(data);
    return <String, dynamic>{...data, 'merges': remaining};
  }

  factory WriterTableBlockEmbed.fromData(Map<String, dynamic> data) {
    return WriterTableBlockEmbed(jsonEncode(data));
  }

  Map<String, dynamic> get tableData {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Keep malformed/older table data from crashing the editor.
    }
    return <String, dynamic>{'rows': <List<String>>[]};
  }
}

typedef WriterTableEditCallback = Future<void> Function(
  BuildContext context,
  Map<String, dynamic> data,
  int offset,
);

/// Opens the table creator/editor. Returns null when cancelled.
Future<Map<String, dynamic>?> showWriterTableEditor(
  BuildContext context, {
  Map<String, dynamic>? initialData,
  bool isBangla = false,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WriterTableDialog(
      initialData: initialData,
      isBangla: isBangla,
    ),
  );
}

class _WriterTableDialog extends StatefulWidget {
  const _WriterTableDialog({this.initialData, required this.isBangla});

  final Map<String, dynamic>? initialData;
  final bool isBangla;

  @override
  State<_WriterTableDialog> createState() => _WriterTableDialogState();
}

class _WriterTableDialogState extends State<_WriterTableDialog> {
  late List<List<TextEditingController>> cells;
  late List<double> rowHeights;
  late List<double> columnWidths;
  String _t(String bn, String en) => widget.isBangla ? bn : en;
  int borderColor = 0xFF333333;
  int backgroundColor = 0xFFFFFFFF;
  int selectedRow = 0;
  int selectedColumn = 0;
  bool headerRow = true;
  List<Map<String, int>> merges = <Map<String, int>>[];
  bool _captureMergeStart = true;
  int? _mergeStartRow;
  int? _mergeStartColumn;
  int? _mergeEndRow;
  int? _mergeEndColumn;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    headerRow = WriterTableBlockEmbed.hasHeaderRow(data ?? const <String, dynamic>{});
    borderColor = data?['borderColor'] is int
        ? data!['borderColor'] as int
        : 0xFF333333;
    backgroundColor = data?['backgroundColor'] is int
        ? data!['backgroundColor'] as int
        : 0xFFFFFFFF;

    final rawRows = data?['rows'];
    if (rawRows is List && rawRows.isNotEmpty) {
      final values = rawRows.map<List<String>>((row) {
        if (row is List) {
          return row.map((value) => value?.toString() ?? '').toList();
        }
        return <String>[row?.toString() ?? ''];
      }).toList();

      final columnCount = values.fold<int>(
        1,
        (count, row) => row.length > count ? row.length : count,
      ).toInt();

      cells = values.map<List<TextEditingController>>((row) {
        return List.generate(
          columnCount,
          (index) => TextEditingController(
            text: index < row.length ? row[index] : '',
          ),
        );
      }).toList();
      if (cells.isEmpty) cells = _createEmptyCells();
    } else {
      cells = _createEmptyCells();
    }

    final rawHeights = data?['rowHeights'];
    rowHeights = List<double>.generate(
      cells.length,
      (index) => rawHeights is List && index < rawHeights.length
          ? (rawHeights[index] as num?)?.toDouble().clamp(36.0, 240.0).toDouble() ?? 56.0
          : 56.0,
    );
    final rawWidths = data?['columnWidths'];
    columnWidths = List<double>.generate(
      columnCount,
      (index) => rawWidths is List && index < rawWidths.length
          ? (rawWidths[index] as num?)?.toDouble().clamp(70.0, 480.0).toDouble() ?? 150.0
          : 150.0,
    );
    merges = WriterTableBlockEmbed.normalizedMerges(
      data ?? const <String, dynamic>{},
      rowCount: cells.length,
      columnCount: columnCount,
    );
  }

  List<List<TextEditingController>> _createEmptyCells() {
    return List.generate(
      1,
      (_) => List.generate(1, (_) => TextEditingController()),
    );
  }

  int get columnCount => cells.isEmpty ? 1 : cells.first.length;

  void addRow() {
    setState(() {
      cells.add(List.generate(columnCount, (_) => TextEditingController()));
      rowHeights.add(56.0);
    });
  }

  void insertRowBefore() {
    setState(() {
      final index = selectedRow.clamp(0, cells.length).toInt();
      cells.insert(index, List.generate(columnCount, (_) => TextEditingController()));
      rowHeights.insert(index, 56.0);
    });
  }

  void insertRowAfter() {
    setState(() {
      final index = (selectedRow + 1).clamp(0, cells.length).toInt();
      cells.insert(index, List.generate(columnCount, (_) => TextEditingController()));
      rowHeights.insert(index, 56.0);
      selectedRow = index;
    });
  }

  void removeRow() {
    if (cells.length <= 1) return;
    setState(() {
      final index = selectedRow.clamp(0, cells.length - 1).toInt();
      for (final controller in cells.removeAt(index)) {
        controller.dispose();
      }
      rowHeights.removeAt(index);
      selectedRow = index.clamp(0, cells.length - 1).toInt();
    });
  }

  void addColumn() {
    setState(() {
      for (final row in cells) {
        row.add(TextEditingController());
      }
      columnWidths.add(150.0);
    });
  }

  void insertColumnBefore() {
    setState(() {
      final index = selectedColumn.clamp(0, columnCount).toInt();
      for (final row in cells) {
        row.insert(index, TextEditingController());
      }
      columnWidths.insert(index, 150.0);
    });
  }

  void insertColumnAfter() {
    setState(() {
      final index = (selectedColumn + 1).clamp(0, columnCount).toInt();
      for (final row in cells) {
        row.insert(index, TextEditingController());
      }
      columnWidths.insert(index, 150.0);
      selectedColumn = index;
    });
  }

  void removeColumn() {
    if (columnCount <= 1) return;
    setState(() {
      final index = selectedColumn.clamp(0, columnCount - 1).toInt();
      for (final row in cells) {
        row.removeAt(index).dispose();
      }
      columnWidths.removeAt(index);
      selectedColumn = index.clamp(0, columnCount - 1).toInt();
    });
  }

  void resizeSelectedRow(double delta) {
    setState(() {
      final index = selectedRow.clamp(0, rowHeights.length - 1).toInt();
      rowHeights[index] = (rowHeights[index] + delta).clamp(36.0, 240.0).toDouble();
    });
  }

  void resizeSelectedColumn(double delta) {
    setState(() {
      final index = selectedColumn.clamp(0, columnWidths.length - 1).toInt();
      columnWidths[index] = (columnWidths[index] + delta).clamp(70.0, 480.0).toDouble();
    });
  }

  Future<void> chooseColor({required bool chooseBorder}) async {
    const colors = <int>[
      0xFF000000,
      0xFF333333,
      0xFF1565C0,
      0xFF008577,
      0xFFB71C1C,
      0xFFFFC107,
      0xFFFFFFFF,
      0xFFE3F2FD,
      0xFFFFF3E0,
      0xFFE8F5E9,
      0xFFFCE4EC,
    ];

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(chooseBorder
            ? _t('বর্ডারের রং', 'Border Color')
            : _t('পটভূমির রং', 'Background Color')),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            return InkWell(
              onTap: () => Navigator.pop(dialogContext, color),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Color(color),
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      if (chooseBorder) {
        borderColor = selected;
      } else {
        backgroundColor = selected;
      }
    });
  }

  void mergeSelectedRange() {
    if (_mergeStartRow == null || _mergeStartColumn == null ||
        _mergeEndRow == null || _mergeEndColumn == null) return;
    try {
      final data = WriterTableBlockEmbed.mergeCells(
        <String, dynamic>{
          'rows': cells.map((row) => row.map((cell) => cell.text).toList()).toList(),
          'merges': merges,
        },
        firstRow: _mergeStartRow!,
        firstColumn: _mergeStartColumn!,
        lastRow: _mergeEndRow!,
        lastColumn: _mergeEndColumn!,
      );
      final rows = data['rows'] as List;
      setState(() {
        for (var r = 0; r < cells.length; r++) {
          for (var c = 0; c < columnCount; c++) {
            cells[r][c].text = rows[r][c].toString();
          }
        }
        merges = WriterTableBlockEmbed.normalizedMerges(
          data, rowCount: cells.length, columnCount: columnCount);
        selectedRow = _mergeStartRow!;
        selectedColumn = _mergeStartColumn!;
      });
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Invalid cell selection')),
      );
    }
  }

  void splitSelectedCell() {
    final data = WriterTableBlockEmbed.splitCell(
      <String, dynamic>{'rows': cells.map((row) =>
        row.map((cell) => cell.text).toList()).toList(), 'merges': merges},
      row: selectedRow,
      column: selectedColumn,
    );
    setState(() {
      merges = WriterTableBlockEmbed.normalizedMerges(
        data, rowCount: cells.length, columnCount: columnCount);
    });
  }

  void saveTable() {
    final rows = cells
        .map((row) => row.map((controller) => controller.text).toList())
        .toList();

    Navigator.of(context).pop(<String, dynamic>{
      'rows': rows,
      'headerRow': headerRow,
      'version': 1,
      'borderColor': borderColor,
      'backgroundColor': backgroundColor,
      'rowHeights': rowHeights,
      'columnWidths': columnWidths,
      'merges': merges,
    });
  }

  @override
  void dispose() {
    for (final row in cells) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  /// Keeps icon-and-label actions inside the available phone width.
  /// A Flexible label wraps long translations instead of overflowing its Row.
  Widget _actionButton({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenHeight = screenSize.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
        child: SizedBox(
          width: (screenSize.width * 0.88).clamp(280.0, 720.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.initialData == null
                        ? _t('টেবিল তৈরি করুন', 'Create Table')
                        : _t('টেবিল সম্পাদনা', 'Edit Table'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.18).clamp(88.0, 140.0),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                _actionButton(
                  onPressed: merges.isEmpty ? addRow : null,
                  icon: const Icon(Icons.add),
                  label: Text(_t('সারি যোগ', 'Add Row')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-insert-row-before'),
                  onPressed: merges.isEmpty ? insertRowBefore : null,
                  icon: const Icon(Icons.arrow_upward),
                  label: Text(_t('উপরে সারি', 'Insert Above')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-insert-row-after'),
                  onPressed: merges.isEmpty ? insertRowAfter : null,
                  icon: const Icon(Icons.arrow_downward),
                  label: Text(_t('নিচে সারি', 'Insert Below')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-delete-selected-row'),
                  onPressed: cells.length <= 1 || merges.isNotEmpty ? null : removeRow,
                  icon: const Icon(Icons.remove),
                  label: Text(_t('নির্বাচিত সারি মুছুন', 'Delete Selected Row')),
                ),
                _actionButton(
                  onPressed: merges.isEmpty ? addColumn : null,
                  icon: const Icon(Icons.add),
                  label: Text(_t('কলাম যোগ', 'Add Column')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-insert-column-before'),
                  onPressed: merges.isEmpty ? insertColumnBefore : null,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_t('বামে কলাম', 'Insert Left')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-insert-column-after'),
                  onPressed: merges.isEmpty ? insertColumnAfter : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_t('ডানে কলাম', 'Insert Right')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-delete-selected-column'),
                  onPressed: columnCount <= 1 || merges.isNotEmpty ? null : removeColumn,
                  icon: const Icon(Icons.remove),
                  label: Text(_t('নির্বাচিত কলাম মুছুন', 'Delete Selected Column')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-row-height-decrease'),
                  onPressed: () => resizeSelectedRow(-8),
                  icon: const Icon(Icons.height),
                  label: Text(_t('সারি ছোট', 'Shorter Row')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-row-height-increase'),
                  onPressed: () => resizeSelectedRow(8),
                  icon: const Icon(Icons.height),
                  label: Text(_t('সারি বড়', 'Taller Row')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-column-width-decrease'),
                  onPressed: () => resizeSelectedColumn(-12),
                  icon: const Icon(Icons.width_normal),
                  label: Text(_t('কলাম সরু', 'Narrower Column')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-column-width-increase'),
                  onPressed: () => resizeSelectedColumn(12),
                  icon: const Icon(Icons.width_full),
                  label: Text(_t('কলাম চওড়া', 'Wider Column')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-merge-range-start'),
                  onPressed: () => setState(() => _captureMergeStart = true),
                  icon: const Icon(Icons.first_page),
                  label: Text(_t('মার্জের শুরু', 'Set Merge Start')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-merge-range-end'),
                  onPressed: () => setState(() => _captureMergeStart = false),
                  icon: const Icon(Icons.last_page),
                  label: Text(_t('মার্জের শেষ', 'Set Merge End')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-merge-selected-range'),
                  onPressed: _mergeStartRow != null && _mergeEndRow != null
                      ? mergeSelectedRange : null,
                  icon: const Icon(Icons.call_merge),
                  label: Text(_t('ঘর মার্জ', 'Merge Cells')),
                ),
                _actionButton(
                  key: const ValueKey('writer-table-split-selected-cell'),
                  onPressed: merges.any((merge) =>
                    merge['row'] == selectedRow &&
                    merge['column'] == selectedColumn) ? splitSelectedCell : null,
                  icon: const Icon(Icons.call_split),
                  label: Text(_t('ঘর আলাদা', 'Split Cell')),
                ),
                OutlinedButton(
                  onPressed: () => chooseColor(chooseBorder: true),
                  child: Text(_t('বর্ডারের রং', 'Border Color')),
                ),
                OutlinedButton(
                  onPressed: () => chooseColor(chooseBorder: false),
                  child: Text(_t('ঘরের রং', 'Cell Fill')),
                  ),
                ],
              ),
            ),
            ),
            const SizedBox(height: 10),
            Text(_t('${cells.length} সারি  ·  $columnCount কলাম', '${cells.length} rows  ·  $columnCount columns')),
            const SizedBox(height: 8),
            Text(_t('নির্বাচিত ঘর: ${selectedRow + 1}, ${selectedColumn + 1}', 'Selected cell: ${selectedRow + 1}, ${selectedColumn + 1}')),
            Text(_t('মার্জ নির্বাচন: শুরু ${_mergeStartRow == null ? '-' : '${_mergeStartRow! + 1},${_mergeStartColumn! + 1}'} → ${_mergeEndRow == null ? '-' : '${_mergeEndRow! + 1},${_mergeEndColumn! + 1}'}', 'Merge selection: ${_mergeStartRow == null ? '-' : '${_mergeStartRow! + 1},${_mergeStartColumn! + 1}'} → ${_mergeEndRow == null ? '-' : '${_mergeEndRow! + 1},${_mergeEndColumn! + 1}'}')),
            CheckboxListTile(
              key: const ValueKey('writer-table-header-row-toggle'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: headerRow,
              title: Text(_t('প্রথম সারি হেডার', 'First row is a header')),
              onChanged: (value) => setState(() => headerRow = value ?? false),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: (screenHeight * 0.14).clamp(72.0, 112.0),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(150),
                    border: TableBorder.all(color: Color(borderColor)),
                    children: List.generate(cells.length, (rowIndex) {
                      return TableRow(
                        children: List.generate(columnCount, (columnIndex) {
                          return Container(
                            constraints: BoxConstraints(minHeight: rowHeights[rowIndex]),
                            color: Color(backgroundColor),
                            padding: const EdgeInsets.all(5),
                            child: TextField(
                              onTap: () {
                                setState(() {
                                  selectedRow = rowIndex;
                                  selectedColumn = columnIndex;
                                  if (_captureMergeStart) {
                                    _mergeStartRow = rowIndex;
                                    _mergeStartColumn = columnIndex;
                                  } else {
                                    _mergeEndRow = rowIndex;
                                    _mergeEndColumn = columnIndex;
                                    _captureMergeStart = true;
                                  }
                                });
                              },
                              controller: cells[rowIndex][columnIndex],
                              maxLines: 3,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: '${rowIndex + 1}.${columnIndex + 1}',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(8),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ),

                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_t('বাতিল', 'Cancel')),
                    ),
                    FilledButton.icon(
                      onPressed: saveTable,
                      icon: const Icon(Icons.check),
                      label: Text(_t('টেবিল প্রয়োগ', 'Apply Table')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders and edits a table block in the Quill document.
class WriterTableEmbedBuilder extends EmbedBuilder {
  WriterTableEmbedBuilder({required this.onEdit, this.isBangla = false});

  final WriterTableEditCallback onEdit;
  final bool isBangla;

  String _t(String bn, String en) => isBangla ? bn : en;

  @override
  String get key => WriterTableBlockEmbed.embedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = embedContext.node.value;
    final rawData = embed.data;
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(rawData);
      data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }

    final rawRows = data['rows'];
    final rows = rawRows is List
        ? rawRows.map<List<String>>((row) {
            if (row is List) {
              return row.map((value) => value?.toString() ?? '').toList();
            }
            return <String>[row?.toString() ?? ''];
          }).toList()
        : <List<String>>[];
    final columnCount = rows.fold<int>(
      1,
      (count, row) => row.length > count ? row.length : count,
    );

    final border = data['borderColor'] is int
        ? data['borderColor'] as int
        : 0xFF333333;
    final background = data['backgroundColor'] is int
        ? data['backgroundColor'] as int
        : 0xFFFFFFFF;
    final hasHeaderRow = WriterTableBlockEmbed.hasHeaderRow(data);
    final rawWidths = data['columnWidths'];
    final widths = List<double>.generate(
      columnCount,
      (index) => rawWidths is List && index < rawWidths.length
          ? (rawWidths[index] as num?)?.toDouble().clamp(70.0, 480.0) ?? 150.0
          : 150.0,
    );
    final rawHeights = data['rowHeights'];
    final heights = List<double>.generate(
      rows.length,
      (index) => rawHeights is List && index < rawHeights.length
          ? (rawHeights[index] as num?)?.toDouble().clamp(36.0, 240.0) ?? 56.0
          : 56.0,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: embedContext.readOnly
                  ? null
                  : () => onEdit(
                        context,
                        data,
                        embedContext.node.documentOffset,
                      ),
              icon: const Icon(Icons.edit, size: 16),
              label: Text(_t('টেবিল সম্পাদনা', 'Edit Table')),
            ),
          ),
          if (rows.isEmpty)
            Text(_t('টেবিল খালি', 'Empty table'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                columnWidths: {
                  for (var index = 0; index < columnCount; index++)
                    index: FixedColumnWidth(widths[index]),
                },
                border: TableBorder.all(color: Color(border)),
                children: List.generate(rows.length, (rowIndex) {
                  final row = rows[rowIndex];
                  return TableRow(
                    decoration: rowIndex == 0 && hasHeaderRow
                        ? BoxDecoration(
                            color: Color(background).withValues(alpha: 0.85),
                          )
                        : null,
                    children: List.generate(columnCount, (columnIndex) {
                      final value = columnIndex < row.length
                          ? row[columnIndex]
                          : '';
                      return Container(
                        constraints: BoxConstraints(minHeight: heights[rowIndex]),
                        color: Color(background),
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontWeight: rowIndex == 0 && hasHeaderRow
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
