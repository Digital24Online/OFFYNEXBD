
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_quill/flutter_quill.dart';

typedef WriterTableEditCallback = Future<void> Function(
  BuildContext context,
  Map<String, dynamic> data,
  int offset,
);

class WriterTableBlockEmbed extends CustomBlockEmbed {
  static const String tableType = 'offynex_table';

  const WriterTableBlockEmbed(String value)
      : super(tableType, value);

  factory WriterTableBlockEmbed.fromData(
    Map<String, dynamic> data,
  ) {
    return WriterTableBlockEmbed(jsonEncode(data));
  }

  Map<String, dynamic> get tableData {
    return Map<String, dynamic>.from(
      jsonDecode(data) as Map,
    );
  }
}

class WriterTableEmbedBuilder extends EmbedBuilder {
  final WriterTableEditCallback? onEdit;

  WriterTableEmbedBuilder({this.onEdit});

  @override
  String get key => WriterTableBlockEmbed.tableType;

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final table = WriterTableBlockEmbed(
      embedContext.node.value.data as String,
    );

    final data = table.tableData;
    final rows = (data['rows'] as List? ?? [])
        .map<List<String>>(
          (row) => (row as List)
              .map((cell) => cell.toString())
              .toList(),
        )
        .toList();

    final borderColor = data['borderColor'] as int? ??
        0xFF333333;

    final backgroundColor =
        data['backgroundColor'] as int? ?? 0xFFFFFFFF;

    return GestureDetector(
      onTap: onEdit == null
          ? null
          : () => onEdit!(
                context,
                data,
                embedContext.node.documentOffset,
              ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              border: TableBorder.all(
                color: Color(borderColor),
                width: 1,
              ),
              children: rows.map((row) {
                return TableRow(
                  children: row.map((cell) {
                    return Container(
                      color: Color(backgroundColor),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(
                        minHeight: 35,
                      ),
                      child: Text(
                        cell,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
            if (onEdit != null)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text(
                  'টেবিল সম্পাদনা করতে ট্যাপ করুন',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WriterTableEditor extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>>? onChanged;

  const WriterTableEditor({
    super.key,
    this.initialData,
    this.onChanged,
  });

  @override
  State<WriterTableEditor> createState() =>
      _WriterTableEditorState();
}

class _WriterTableEditorState extends State<WriterTableEditor> {
  late List<List<TextEditingController>> cells;

  int borderColor = 0xFF333333;
  int backgroundColor = 0xFFFFFFFF;

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    borderColor = data?['borderColor'] ?? 0xFF333333;
    backgroundColor =
        data?['backgroundColor'] ?? 0xFFFFFFFF;

    final savedRows = data?['rows'];

    if (savedRows is List && savedRows.isNotEmpty) {
      cells = savedRows.map<List<TextEditingController>>(
        (row) {
          return (row as List).map<TextEditingController>(
            (value) {
              return TextEditingController(
                text: value.toString(),
              );
            },
          ).toList();
        },
      ).toList();
    } else {
      cells = List.generate(
        3,
        (_) => List.generate(
          3,
          (_) => TextEditingController(),
        ),
      );
    }

    final columnCount = cells.first.length;

    for (final row in cells) {
      while (row.length < columnCount) {
        row.add(TextEditingController());
      }
    }
  }

  Map<String, dynamic> getTableData() {
    return {
      'type': WriterTableBlockEmbed.tableType,
      'rows': cells.map((row) {
        return row.map((cell) => cell.text).toList();
      }).toList(),
      'borderColor': borderColor,
      'backgroundColor': backgroundColor,
    };
  }

  void notifyChanged() {
    widget.onChanged?.call(getTableData());
  }

  void addRow() {
    setState(() {
      cells.add(
        List.generate(
          cells.first.length,
          (_) => TextEditingController(),
        ),
      );
    });

    notifyChanged();
  }

  void removeRow() {
    if (cells.length <= 1) return;

    setState(() {
      final removed = cells.removeLast();

      for (final controller in removed) {
        controller.dispose();
      }
    });

    notifyChanged();
  }

  void addColumn() {
    setState(() {
      for (final row in cells) {
        row.add(TextEditingController());
      }
    });

    notifyChanged();
  }

  void removeColumn() {
    if (cells.first.length <= 1) return;

    setState(() {
      for (final row in cells) {
        row.removeLast().dispose();
      }
    });

    notifyChanged();
  }

  Future<void> chooseColor(bool isBorder) async {
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
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isBorder ? 'Border Color' : 'Background Color',
          ),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((color) {
              return InkWell(
                onTap: () => Navigator.pop(
                  dialogContext,
                  color,
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Color(color),
                    border: Border.all(
                      color: Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (isBorder) {
        borderColor = selected;
      } else {
        backgroundColor = selected;
      }
    });

    notifyChanged();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: addRow,
              icon: const Icon(Icons.add),
              label: const Text('Add Row'),
            ),
            OutlinedButton.icon(
              onPressed: removeRow,
              icon: const Icon(Icons.remove),
              label: const Text('Remove Row'),
            ),
            OutlinedButton.icon(
              onPressed: addColumn,
              icon: const Icon(Icons.add),
              label: const Text('Add Column'),
            ),
            OutlinedButton.icon(
              onPressed: removeColumn,
              icon: const Icon(Icons.remove),
              label: const Text('Remove Column'),
            ),
            OutlinedButton(
              onPressed: () => chooseColor(true),
              child: const Text('Border Color'),
            ),
            OutlinedButton(
              onPressed: () => chooseColor(false),
              child: const Text('Background'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Rows: ${cells.length}   Columns: ${cells.first.length}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth:
                    const FixedColumnWidth(160),
                border: TableBorder.all(
                  color: Color(borderColor),
                  width: 1,
                ),
                children: List.generate(
                  cells.length,
                  (rowIndex) {
                    return TableRow(
                      children: List.generate(
                        cells[rowIndex].length,
                        (columnIndex) {
                          return Container(
                            color: Color(backgroundColor),
                            padding: const EdgeInsets.all(5),
                            child: TextField(
                              controller:
                                  cells[rowIndex][columnIndex],
                              onChanged: (_) => notifyChanged(),
                              maxLines: 3,
                              minLines: 1,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Type here...',
                                contentPadding:
                                    EdgeInsets.all(8),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<Map<String, dynamic>?> showWriterTableEditor(
  BuildContext context, {
  Map<String, dynamic>? initialData,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      final editorKey =
          GlobalKey<_WriterTableEditorState>();

      return AlertDialog(
        title: const Text('Insert Table'),
        content: SizedBox(
          width: 700,
          height: 450,
          child: WriterTableEditor(
            key: editorKey,
            initialData: initialData,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final data =
                  editorKey.currentState?.getTableData();

              if (data != null) {
                Navigator.pop(dialogContext, data);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save Table'),
          ),
        ],
      );
    },
  );
}
