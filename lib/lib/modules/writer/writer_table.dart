import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Custom Quill block for Writer tables.
/// Keep this type unchanged so previously saved table blocks remain readable.
class WriterTableBlockEmbed extends CustomBlockEmbed {
  static const String embedType = 'offynexbd-writer-table';

  const WriterTableBlockEmbed(String value) : super(embedType, value);

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

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
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

  void saveTable() {
    final rows = cells
        .map((row) => row.map((controller) => controller.text).toList())
        .toList();

    Navigator.of(context).pop(<String, dynamic>{
      'rows': rows,
      'headerRow': true,
      'version': 1,
      'borderColor': borderColor,
      'backgroundColor': backgroundColor,
      'rowHeights': rowHeights,
      'columnWidths': columnWidths,
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initialData == null
          ? _t('টেবিল তৈরি করুন', 'Create Table')
          : _t('টেবিল সম্পাদনা', 'Edit Table')),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.88).clamp(280.0, 720.0),
        height: (screenHeight * 0.54).clamp(240.0, 420.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.24).clamp(96.0, 190.0),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                OutlinedButton.icon(
                  onPressed: addRow,
                  icon: const Icon(Icons.add),
                  label: Text(_t('সারি যোগ', 'Add Row')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-insert-row-before'),
                  onPressed: insertRowBefore,
                  icon: const Icon(Icons.arrow_upward),
                  label: Text(_t('উপরে সারি', 'Insert Above')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-insert-row-after'),
                  onPressed: insertRowAfter,
                  icon: const Icon(Icons.arrow_downward),
                  label: Text(_t('নিচে সারি', 'Insert Below')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-delete-selected-row'),
                  onPressed: cells.length <= 1 ? null : removeRow,
                  icon: const Icon(Icons.remove),
                  label: Text(_t('নির্বাচিত সারি মুছুন', 'Delete Selected Row')),
                ),
                OutlinedButton.icon(
                  onPressed: addColumn,
                  icon: const Icon(Icons.add),
                  label: Text(_t('কলাম যোগ', 'Add Column')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-insert-column-before'),
                  onPressed: insertColumnBefore,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_t('বামে কলাম', 'Insert Left')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-insert-column-after'),
                  onPressed: insertColumnAfter,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_t('ডানে কলাম', 'Insert Right')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-delete-selected-column'),
                  onPressed: columnCount <= 1 ? null : removeColumn,
                  icon: const Icon(Icons.remove),
                  label: Text(_t('নির্বাচিত কলাম মুছুন', 'Delete Selected Column')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-row-height-decrease'),
                  onPressed: () => resizeSelectedRow(-8),
                  icon: const Icon(Icons.height),
                  label: Text(_t('সারি ছোট', 'Shorter Row')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-row-height-increase'),
                  onPressed: () => resizeSelectedRow(8),
                  icon: const Icon(Icons.height),
                  label: Text(_t('সারি বড়', 'Taller Row')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-column-width-decrease'),
                  onPressed: () => resizeSelectedColumn(-12),
                  icon: const Icon(Icons.width_normal),
                  label: Text(_t('কলাম সরু', 'Narrower Column')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('writer-table-column-width-increase'),
                  onPressed: () => resizeSelectedColumn(12),
                  icon: const Icon(Icons.width_full),
                  label: Text(_t('কলাম চওড়া', 'Wider Column')),
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
            const SizedBox(height: 8),
            SizedBox(
              height: (screenHeight * 0.18).clamp(90.0, 150.0),
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
      actions: [
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
                    decoration: rowIndex == 0
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
                            fontWeight: rowIndex == 0
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
