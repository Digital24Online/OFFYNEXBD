import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'database_rows_csv_codec.dart';

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
  bool _fileBusy = false;

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

  Future<void> _exportCsv() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final csv = DatabaseRowsCsvCodec.encode(fields: widget.fields, rows: _rows);
      final safeName = widget.tableName
          .replaceAll(RegExp(r'[^a-zA-Z0-9\u0980-\u09FF]+'), '-')
          .replaceAll(RegExp(r'-+'), '-');
      final saved = await FilePicker.saveFile(
        fileName: 'OFFYNEXBD-${safeName.isEmpty ? 'Database' : safeName}.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        dialogTitle: widget.isBangla ? 'CSV Export সংরক্ষণ' : 'Export table CSV',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isBangla ? 'CSV Export সম্পন্ন হয়েছে।' : 'CSV export completed.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.isBangla ? 'Export ব্যর্থ' : 'Export failed'}: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _importCsv() async {
    if (_fileBusy) return;
    setState(() => _fileBusy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final imported = DatabaseRowsCsvCodec.decode(
        bytes,
        expectedFields: widget.fields,
      );
      if (imported.isEmpty) {
        throw const FormatException('CSV contains no data rows.');
      }
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(widget.isBangla ? 'CSV Import করবেন?' : 'Import CSV rows?'),
          content: Text(widget.isBangla
              ? '${imported.length}টি Row পাওয়া গেছে। বর্তমান Row অক্ষত রেখে নতুন Row যোগ হবে।'
              : '${imported.length} rows found. New rows will be appended; existing rows will remain unchanged.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(widget.isBangla ? 'Import' : 'Import'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      setState(() => _rows.addAll(imported));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isBangla
            ? '${imported.length}টি নতুন Row যোগ হয়েছে। সংরক্ষণ করতে নিচে Save চাপুন।'
            : '${imported.length} rows added. Press Save changes below to persist them.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.isBangla ? 'Import ব্যর্থ' : 'Import failed'}: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: _fileBusy ? null : _importCsv,
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(widget.isBangla ? 'CSV Import' : 'Import CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: _fileBusy || _rows.isEmpty ? null : _exportCsv,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(widget.isBangla ? 'CSV Export' : 'Export CSV'),
                ),
              ],
            ),
            if (_fileBusy) const LinearProgressIndicator(),
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
