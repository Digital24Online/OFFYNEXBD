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
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WriterTableDialog(initialData: initialData),
  );
}

class _WriterTableDialog extends StatefulWidget {
  const _WriterTableDialog({this.initialData});

  final Map<String, dynamic>? initialData;

  @override
  State<_WriterTableDialog> createState() => _WriterTableDialogState();
}

class _WriterTableDialogState extends State<_WriterTableDialog> {
  late List<List<TextEditingController>> cells;
  int borderColor = 0xFF333333;
  int backgroundColor = 0xFFFFFFFF;

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
      ).clamp(1, 10).toInt();

      cells = values.take(20).map<List<TextEditingController>>((row) {
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
  }

  List<List<TextEditingController>> _createEmptyCells() {
    return List.generate(
      3,
      (_) => List.generate(3, (_) => TextEditingController()),
    );
  }

  int get columnCount => cells.isEmpty ? 1 : cells.first.length;

  void addRow() {
    if (cells.length >= 20) return;
    setState(() {
      cells.add(List.generate(columnCount, (_) => TextEditingController()));
    });
  }

  void removeRow() {
    if (cells.length <= 1) return;
    setState(() {
      for (final controller in cells.removeLast()) {
        controller.dispose();
      }
    });
  }

  void addColumn() {
    if (columnCount >= 10) return;
    setState(() {
      for (final row in cells) {
        row.add(TextEditingController());
      }
    });
  }

  void removeColumn() {
    if (columnCount <= 1) return;
    setState(() {
      for (final row in cells) {
        row.removeLast().dispose();
      }
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
        title: Text(chooseBorder ? 'Border Color' : 'Background Color'),
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
    return AlertDialog(
      title: Text(widget.initialData == null ? 'টেবিল তৈরি করুন' : 'টেবিল সম্পাদনা'),
      content: SizedBox(
        width: 560,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: cells.length >= 20 ? null : addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('সারি যোগ'),
                ),
                OutlinedButton.icon(
                  onPressed: cells.length <= 1 ? null : removeRow,
                  icon: const Icon(Icons.remove),
                  label: const Text('সারি কমান'),
                ),
                OutlinedButton.icon(
                  onPressed: columnCount >= 10 ? null : addColumn,
                  icon: const Icon(Icons.add),
                  label: const Text('কলাম যোগ'),
                ),
                OutlinedButton.icon(
                  onPressed: columnCount <= 1 ? null : removeColumn,
                  icon: const Icon(Icons.remove),
                  label: const Text('কলাম কমান'),
                ),
                OutlinedButton(
                  onPressed: () => chooseColor(chooseBorder: true),
                  child: const Text('Border Color'),
                ),
                OutlinedButton(
                  onPressed: () => chooseColor(chooseBorder: false),
                  child: const Text('Background'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('সারি: ${cells.length}  |  কলাম: $columnCount'),
            const SizedBox(height: 8),
            Expanded(
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
                            color: Color(backgroundColor),
                            padding: const EdgeInsets.all(5),
                            child: TextField(
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
          child: const Text('বাতিল'),
        ),
        FilledButton.icon(
          onPressed: saveTable,
          icon: const Icon(Icons.check),
          label: const Text('সংরক্ষণ'),
        ),
      ],
    );
  }
}

/// Renders and edits a table block in the Quill document.
class WriterTableEmbedBuilder extends EmbedBuilder {
  WriterTableEmbedBuilder({required this.onEdit});

  final WriterTableEditCallback onEdit;

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
              label: const Text('টেবিল সম্পাদনা'),
            ),
          ),
          if (rows.isEmpty)
            const Text('খালি টেবিল')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
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
