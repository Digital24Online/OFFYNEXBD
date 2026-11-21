import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'database_field_codec.dart';
import 'database_rows_csv_codec.dart';
import 'database_rows_query.dart';

class DatabaseRowsDialog extends StatefulWidget {
  const DatabaseRowsDialog({
    super.key,
    required this.isBangla,
    required this.tableName,
    required this.schema,
    required this.initialRows,
  });

  final bool isBangla;
  final String tableName;
  final List<DatabaseField> schema;
  final List<Map<String, dynamic>> initialRows;

  List<String> get fields => schema.map((field) => field.name).toList(growable: false);

  @override
  State<DatabaseRowsDialog> createState() => _DatabaseRowsDialogState();
}

class _DatabaseRowsDialogState extends State<DatabaseRowsDialog> {
  late final List<Map<String, dynamic>> _rows;
  bool _fileBusy = false;
  late final TextEditingController _searchController;
  String? _sortField;
  bool _ascending = true;

  List<Map<String, dynamic>> get _visibleRows => DatabaseRowsQuery.apply(
        rows: _rows,
        fields: widget.fields,
        query: _searchController.text,
        sortField: _sortField,
        ascending: _ascending,
      );

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows.map((row) => Map<String, dynamic>.from(row)).toList();
    _searchController = TextEditingController();
    _sortField = widget.fields.isEmpty ? null : widget.fields.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        schema: widget.schema,
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
      final imported = DatabaseRowsCsvCodec.decode(bytes, expectedFields: widget.fields);
      if (imported.isEmpty) throw const FormatException('CSV contains no data rows.');
      for (var rowIndex = 0; rowIndex < imported.length; rowIndex++) {
        final values = imported[rowIndex]['values'] as Map;
        for (final field in widget.schema) {
          final value = values[field.name]?.toString() ?? '';
          if (!DatabaseFieldCodec.isValueValid(field, value)) {
            throw FormatException(
              'CSV row ${rowIndex + 2} has an invalid value for "${field.name}".',
            );
          }
        }
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
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.isBangla ? 'Row-এর তথ্য খুঁজুন' : 'Search row values',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            if (widget.fields.isNotEmpty)
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortField,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: widget.isBangla ? 'যে ফিল্ড অনুযায়ী সাজাবেন' : 'Sort by field',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final field in widget.fields)
                        DropdownMenuItem(value: field, child: Text(field, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) => setState(() => _sortField = value),
                  ),
                ),
                IconButton(
                  tooltip: _ascending
                      ? (widget.isBangla ? 'ছোট থেকে বড়' : 'Ascending')
                      : (widget.isBangla ? 'বড় থেকে ছোট' : 'Descending'),
                  onPressed: () => setState(() => _ascending = !_ascending),
                  icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                ),
              ]),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.isBangla
                    ? '${_visibleRows.length}টি দেখানো হচ্ছে'
                    : 'Showing ${_visibleRows.length} of ${_rows.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _rows.isEmpty
                  ? Center(child: Text(widget.isBangla ? 'এখনো কোনো Row নেই।' : 'No rows yet.'))
                  : _visibleRows.isEmpty
                      ? Center(child: Text(widget.isBangla ? 'কোনো মিল পাওয়া যায়নি।' : 'No matching rows.'))
                      : ListView.builder(
                      itemCount: _visibleRows.length,
                      itemBuilder: (context, index) {
                        final row = _visibleRows[index];
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
                                onPressed: () => setState(() => _rows.removeWhere((item) => item['id'] == row['id'])),
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
    required this.schema,
    required this.initialValues,
  });

  final bool isBangla;
  final List<DatabaseField> schema;
  final Map<String, String> initialValues;

  @override
  State<_DatabaseRowEditDialog> createState() => _DatabaseRowEditDialogState();
}

class _DatabaseRowEditDialogState extends State<_DatabaseRowEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  late final Map<int, String?> _choices;

  @override
  void initState() {
    super.initState();
    _controllers = widget.schema
        .map((field) => TextEditingController(text: widget.initialValues[field.name] ?? ''))
        .toList(growable: false);
    _choices = {
      for (var index = 0; index < widget.schema.length; index++)
        if (widget.schema[index].type == 'choice' &&
            (widget.initialValues[widget.schema[index].name]?.isNotEmpty ?? false))
          index: widget.initialValues[widget.schema[index].name],
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseDate(int index) async {
    final current = DateTime.tryParse(_controllers[index].text);
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected != null) {
      _controllers[index].text =
          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    }
  }

  String? _validate(DatabaseField field, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return field.required
          ? (widget.isBangla ? 'এই ঘরটি পূরণ করুন' : 'This field is required')
          : null;
    }
    switch (field.type) {
      case 'number':
        if (num.tryParse(value) == null) {
          return widget.isBangla ? 'সঠিক সংখ্যা লিখুন' : 'Enter a valid number';
        }
        break;
      case 'email':
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
          return widget.isBangla ? 'সঠিক ইমেইল লিখুন' : 'Enter a valid email';
        }
        break;
      case 'date':
        if (DateTime.tryParse(value) == null) {
          return widget.isBangla ? 'সঠিক তারিখ বাছাই করুন' : 'Choose a valid date';
        }
        break;
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, {
      for (var index = 0; index < widget.schema.length; index++)
        widget.schema[index].name: widget.schema[index].type == 'choice'
            ? (_choices[index] ?? '')
            : _controllers[index].text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isBangla ? 'Row তথ্য' : 'Row details'),
      content: SizedBox(
        width: 480,
        height: 360,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              for (var index = 0; index < widget.schema.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Builder(builder: (context) {
                    final field = widget.schema[index];
                    final label = field.required ? '${field.name} *' : field.name;
                    if (field.type == 'choice') {
                      final selected = _choices[index];
                      final savedLegacyValue = selected != null &&
                          !field.options.contains(selected);
                      return DropdownButtonFormField<String>(
                        initialValue: selected,
                        decoration: InputDecoration(
                          labelText: label,
                          helperText: savedLegacyValue
                              ? (widget.isBangla
                                  ? 'আগের সংরক্ষিত মানটি রাখা হয়েছে; চাইলে নতুন বিকল্প বাছুন।'
                                  : 'The previously saved value is preserved; choose a new option if needed.')
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          if (savedLegacyValue)
                            DropdownMenuItem(
                              value: selected,
                              child: Text(widget.isBangla
                                  ? '$selected (আগের মান)'
                                  : '$selected (saved value)'),
                            ),
                          for (final option in field.options)
                            DropdownMenuItem(value: option, child: Text(option)),
                        ],
                        onChanged: (value) => setState(() => _choices[index] = value),
                        validator: (value) {
                          if (field.required && value == null) {
                            return widget.isBangla
                                ? 'একটি বিকল্প বেছে নিন'
                                : 'Choose an option';
                          }
                          if (value != null &&
                              !field.options.contains(value) &&
                              value != widget.initialValues[field.name]) {
                            return widget.isBangla
                                ? 'তালিকার একটি বিকল্প বাছুন'
                                : 'Choose an available option';
                          }
                          return null;
                        },
                      );
                    }
                    final type = field.type;
                    return TextFormField(
                      controller: _controllers[index],
                      readOnly: type == 'date',
                      onTap: type == 'date' ? () => _chooseDate(index) : null,
                      keyboardType: type == 'email'
                          ? TextInputType.emailAddress
                          : type == 'number'
                              ? const TextInputType.numberWithOptions(decimal: true)
                              : TextInputType.text,
                      validator: (value) => _validate(field, value),
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                        suffixIcon: type == 'date'
                            ? IconButton(
                                tooltip: widget.isBangla ? 'তারিখ বাছাই' : 'Choose date',
                                onPressed: () => _chooseDate(index),
                                icon: const Icon(Icons.calendar_month_outlined),
                              )
                            : null,
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isBangla ? 'বাতিল' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isBangla ? 'Row সংরক্ষণ' : 'Save row'),
        ),
      ],
    );
  }
}
