import 'package:material_ui/material_ui.dart';

class DatabaseRowsDialog extends StatefulWidget {
  const DatabaseRowsDialog({
    super.key,
    required this.isBangla,
    required this.tableName,
    required this.fields,
    required this.initialRows,
  });

  final bool isBangla;
  final String tableName;
  final List<String> fields;
  final List<Map<String, dynamic>> initialRows;

  @override
  State<DatabaseRowsDialog> createState() => _DatabaseRowsDialogState();
}

class _DatabaseRowsDialogState extends State<DatabaseRowsDialog> {
  late final List<Map<String, dynamic>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _editRow({Map<String, dynamic>? row}) async {
    final stored = row?['values'];
    final values = stored is Map
        ? Map<String, String>.from(stored.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          ))
        : <String, String>{};
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DatabaseRowEditDialog(
        isBangla: widget.isBangla,
        fields: widget.fields,
        initialValues: values,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final updated = <String, dynamic>{
        'id': row?['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        'values': result,
      };
      if (row == null) {
        _rows.add(updated);
      } else {
        final index = _rows.indexWhere((item) => item['id'] == row['id']);
        if (index >= 0) _rows[index] = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tableName),
      content: SizedBox(
        width: 520,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isBangla ? '${_rows.length}টি Row' : '${_rows.length} rows'),
            const SizedBox(height: 8),
            Expanded(
              child: _rows.isEmpty
                  ? Center(child: Text(widget.isBangla ? 'এখনো কোনো Row নেই।' : 'No rows yet.'))
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final stored = row['values'];
                        final values = stored is Map ? stored : const {};
                        final summary = widget.fields
                            .map((field) => values[field]?.toString() ?? '')
                            .join(' | ');
                        return ListTile(
                          dense: true,
                          title: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: widget.isBangla ? 'সম্পাদনা' : 'Edit row',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editRow(row: row),
                              ),
                              IconButton(
                                tooltip: widget.isBangla ? 'মুছুন' : 'Delete row',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() => _rows.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _editRow(),
              icon: const Icon(Icons.add),
              label: Text(widget.isBangla ? 'নতুন Row' : 'Add row'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _rows),
          child: Text(widget.isBangla ? 'সব সংরক্ষণ' : 'Save changes'),
        ),
      ],
    );
  }
}

class _DatabaseRowEditDialog extends StatefulWidget {
  const _DatabaseRowEditDialog({
    required this.isBangla,
    required this.fields,
    required this.initialValues,
  });

  final bool isBangla;
  final List<String> fields;
  final Map<String, String> initialValues;

  @override
  State<_DatabaseRowEditDialog> createState() => _DatabaseRowEditDialogState();
}

class _DatabaseRowEditDialogState extends State<_DatabaseRowEditDialog> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.fields
        .map((field) => TextEditingController(text: widget.initialValues[field] ?? ''))
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isBangla ? 'Row তথ্য' : 'Row details'),
      content: SizedBox(
        width: 480,
        height: 320,
        child: ListView(
          children: [
            for (var index = 0; index < widget.fields.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[index],
                  decoration: InputDecoration(
                    labelText: widget.fields[index],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            {
              for (var index = 0; index < widget.fields.length; index++)
                widget.fields[index]: _controllers[index].text,
            },
          ),
          child: Text(widget.isBangla ? 'Row সংরক্ষণ' : 'Save row'),
        ),
      ],
    );
  }
}
