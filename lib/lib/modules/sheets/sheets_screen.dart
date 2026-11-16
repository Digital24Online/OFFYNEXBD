import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_picker/file_picker.dart';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sheets_formula_engine.dart';

const String _sheetStorageKey = 'offynex_sheets_workbook_v1';

class SheetsScreen extends StatefulWidget {
  const SheetsScreen({super.key, this.isBangla = true});

  final bool isBangla;

  @override
  State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> {
  static const int _initialRows = 30;
  static const int _initialColumns = 12;

  final Map<String, String> _cells = {};
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _loading = true;
  bool _saved = true;
  Future<void> _saveQueue = Future<void>.value();
  int _rowCount = _initialRows;
  int _columnCount = _initialColumns;
  String _sheetName = 'Sheet1';
  String? _selectedCell;

  bool get _bn => widget.isBangla;

  String _t(String bn, String en) => _bn ? bn : en;

  String _columnName(int index) {
    var number = index + 1;
    var result = '';
    while (number > 0) {
      final remainder = (number - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      number = (number - 1) ~/ 26;
    }
    return result;
  }

  String _cellKey(int row, int column) => '${_columnName(column)}${row + 1}';

  @override
  void initState() {
    super.initState();
    _loadWorkbook();
  }

  Future<void> _loadWorkbook() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sheetStorageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final storedCells = data['cells'];
        if (storedCells is Map) {
          _cells.addAll(storedCells.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ));
        }
        _sheetName = data['name']?.toString() ?? 'Sheet1';
        _rowCount = (data['rows'] as num?)?.toInt() ?? _initialRows;
        _columnCount = (data['columns'] as num?)?.toInt() ?? _initialColumns;
        // Preserve intentionally reduced dimensions from previously saved workbooks.
        _rowCount = _rowCount.clamp(1, 1000);
        _columnCount = _columnCount.clamp(1, 100);
      } catch (_) {
        // Ignore a damaged workbook and keep a fresh empty sheet.
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _saveWorkbook() async {
    // Capture a snapshot now and serialize writes to prevent stale saves winning races.
    final snapshot = jsonEncode({
      'name': _sheetName,
      'rows': _rowCount,
      'columns': _columnCount,
      'cells': Map<String, String>.from(_cells),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (mounted) setState(() => _saved = false);
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_sheetStorageKey, snapshot);
      if (!success) throw StateError('Workbook could not be saved');
    });
    final saveOperation = _saveQueue;
    try {
      await saveOperation;
      if (mounted && identical(_saveQueue, saveOperation)) {
        setState(() => _saved = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।', 'Could not save. Please try again.'))),
      );
    }
  }

  double? _numericValue(String reference, [Set<String>? visiting]) {
    return SheetsFormulaEngine(_cells).evaluateCell(reference, visiting);
  }

  String _displayValue(String key) {
    final value = _cells[key] ?? '';
    if (!value.startsWith('=')) return value;
    final result = _numericValue(key);
    if (result == null) return '#ERROR';
    return result == result.roundToDouble()
        ? result.toInt().toString()
        : result.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _editCell(int row, int column) async {
    final key = _cellKey(row, column);
    final controller = TextEditingController(text: _cells[key] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_t('সেল সম্পাদনা', 'Edit cell')} — $key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: _t('মান অথবা Formula', 'Value or formula'),
            hintText: '=SUM(A1:A5)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Text(_t('মুছুন', 'Clear')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_t('সংরক্ষণ', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    if (result.trim().isEmpty) {
      _cells.remove(key);
    } else {
      _cells[key] = result.trim();
    }
    setState(() => _selectedCell = key);
    await _saveWorkbook();
  }

  Future<void> _renameSheet() async {
    final controller = TextEditingController(text: _sheetName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('শিটের নাম', 'Sheet name')),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(_t('সংরক্ষণ', 'Save'))),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _sheetName = result);
    await _saveWorkbook();
  }

  Future<void> _addRows() async {
    setState(() => _rowCount = (_rowCount + 10).clamp(1, 1000));
    await _saveWorkbook();
  }

  Future<void> _addColumns() async {
    if (_columnCount >= 100) return;
    setState(() => _columnCount = (_columnCount + 2).clamp(1, 100));
    await _saveWorkbook();
  }

  Future<void> _removeLastRow() async {
    if (_rowCount <= 1) return;
    final rowNumber = _rowCount;
    final cellPattern = RegExp(r'^[A-Z]+' + rowNumber.toString() + r'$');
    final formulaPattern = RegExp(r'(?<![A-Z0-9_])[A-Z]+' + rowNumber.toString() + r'(?!\d)');
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key.toUpperCase()) && entry.value.isNotEmpty);
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value.toUpperCase()));
    if (hasData || hasFormulaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Row-তে তথ্য বা Formula reference আছে। আগে তা সরান।', 'The last row has data or formula references. Clear them first.'))),
      );
      return;
    }
    setState(() {
      _rowCount--;
      if (_selectedCell != null && cellPattern.hasMatch(_selectedCell!)) {
        _selectedCell = null;
      }
    });
    await _saveWorkbook();
  }

  Future<void> _removeLastColumn() async {
    if (_columnCount <= 1) return;
    final lastColumn = _columnName(_columnCount - 1);
    final escapedLastColumn = RegExp.escape(lastColumn);
    final cellPattern = RegExp('^${RegExp.escape(lastColumn)}[1-9]\\d*
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key) && entry.value.isNotEmpty);
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value));
    if (hasData || hasFormulaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Column-তে তথ্য বা Formula reference আছে। আগে তা সরান।', 'The last column has data or formula references. Clear them first.'))),
      );
      return;
    }
    setState(() {
      _columnCount--;
      if (_selectedCell != null && cellPattern.hasMatch(_selectedCell!)) {
        _selectedCell = null;
      }
    });
    await _saveWorkbook();
  }

  Future<void> _importWorkbook() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final workbook = xlsx.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) throw FormatException('Workbook has no worksheets');
      final sheetName = workbook.getDefaultSheet() ?? workbook.tables.keys.first;
      final sheet = workbook.tables[sheetName];
      if (sheet == null) throw FormatException('Worksheet could not be read');
      final imported = <String, String>{};
      for (final row in sheet.rows) {
        for (final cell in row) {
          if (cell == null || cell.value == null) continue;
          final key = _cellKey(cell.rowIndex, cell.columnIndex);
          final dynamic cellValue = cell.value;
          final String value = cellValue is xlsx.FormulaCellValue
              ? '=${cellValue.formula.toString().replaceFirst(RegExp(r'^='), '')}'
              : cellValue.toString();
          if (value.isNotEmpty) imported[key] = value;
        }
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('Workbook Import করবেন?', 'Import workbook?')),
          content: Text(_t(
            '$sheetName থেকে ${imported.length}টি সেল বর্তমান শিটের জায়গায় আসবে। বর্তমান শিটের তথ্য বদলে যাবে।',
            '${imported.length} cells from $sheetName will replace the current sheet data.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('Import', 'Import'))),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      setState(() {
        _cells..clear()..addAll(imported);
        _rowCount = sheet.maxRows.clamp(1, 1000);
        _columnCount = sheet.maxColumns.clamp(1, 100);
        _sheetName = sheetName;
        _selectedCell = null;
      });
      await _saveWorkbook();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Import সফল হয়েছে।', 'XLSX imported successfully.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Import করা যায়নি: ', 'Import failed: ') + error.toString())),
      );
    }
  }

  Future<void> _exportWorkbook() async {
    try {
      final workbook = xlsx.Excel.createExcel();
      final defaultName = workbook.getDefaultSheet();
      final safeName = _sheetName.trim().isEmpty ? 'Sheet1' : _sheetName.trim();
      if (defaultName != null && defaultName != safeName) workbook.rename(defaultName, safeName);
      final sheet = workbook[safeName];
      for (final entry in _cells.entries) {
        final value = entry.value;
        final cell = sheet.cell(xlsx.CellIndex.indexByString(entry.key.toUpperCase()));
        if (value.startsWith('=')) {
          cell.value = xlsx.FormulaCellValue(value.substring(1));
        } else {
          final numeric = double.tryParse(value);
          if (numeric != null && numeric.isFinite) {
            cell.value = numeric == numeric.roundToDouble()
                ? xlsx.IntCellValue(numeric.toInt())
                : xlsx.DoubleCellValue(numeric);
          } else if (value.toUpperCase() == 'TRUE' || value.toUpperCase() == 'FALSE') {
            cell.value = xlsx.BoolCellValue(value.toUpperCase() == 'TRUE');
          } else {
            cell.value = xlsx.TextCellValue(value);
          }
        }
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('XLSX encoding failed');
      final fileName = '${safeName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.xlsx';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        dialogTitle: _t('XLSX ফাইল সংরক্ষণ', 'Save XLSX workbook'),
      );
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Export সম্পন্ন হয়েছে।', 'XLSX export completed.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Export করা যায়নি: ', 'Export failed: ') + error.toString())),
      );
    }
  }

  Future<void> _clearSheet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('শিট খালি করবেন?', 'Clear sheet?')),
        content: Text(_t('সব সেলের তথ্য মুছে যাবে।', 'All cell data will be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('মুছুন', 'Clear'))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _cells.clear();
      _selectedCell = null;
    });
    await _saveWorkbook();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(_t('OFFYNEX শিটস', 'OFFYNEX Sheets')),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t('XLSX Import', 'Import XLSX'),
            onPressed: _importWorkbook,
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: _t('XLSX Export', 'Export XLSX'),
            onPressed: _exportWorkbook,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: _t('শিটের নাম পরিবর্তন', 'Rename sheet'),
            onPressed: _renameSheet,
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
          IconButton(
            tooltip: _t('সংরক্ষণ', 'Save'),
            onPressed: _saveWorkbook,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: _t('সব মুছুন', 'Clear all'),
            onPressed: _clearSheet,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addRows,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('১০টি Row', '10 Rows')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addColumns,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('২টি Column', '2 Columns')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _rowCount > 1 ? _removeLastRow : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Row বাদ', 'Remove last row')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _columnCount > 1 ? _removeLastColumn : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Column বাদ', 'Remove last column')),
                      ),
                      Chip(
                        avatar: Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 16),
                        label: Text(_saved ? _t('সংরক্ষিত', 'Saved') : _t('সংরক্ষণ হচ্ছে', 'Saving')),
                      ),
                    ],
                  ),
                ),
                if (_selectedCell != null)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEAF2FC),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Text(_selectedCell!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_cells[_selectedCell!] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('= ${_displayValue(_selectedCell!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) => notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            horizontalMargin: 8,
                            columnSpacing: 4,
                            headingRowHeight: 38,
                            dataRowMinHeight: 42,
                            dataRowMaxHeight: 48,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFE5ECF5)),
                            columns: [
                              DataColumn(label: SizedBox(width: 42, child: Center(child: Text('#')))),
                              for (var column = 0; column < _columnCount; column++)
                                DataColumn(
                                  label: SizedBox(
                                    width: 104,
                                    child: Center(
                                      child: Text(_columnName(column), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (var row = 0; row < _rowCount; row++)
                                DataRow(
                                  cells: [
                                    DataCell(SizedBox(width: 42, child: Center(child: Text('${row + 1}', style: const TextStyle(color: Colors.black54))))),
                                    for (var column = 0; column < _columnCount; column++)
                                      DataCell(
                                        SizedBox(
                                          width: 104,
                                          child: InkWell(
                                            onTap: () => _editCell(row, column),
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: _selectedCell == _cellKey(row, column) ? const Color(0xFFDCEBFF) : Colors.white,
                                                border: Border.all(color: const Color(0xFFE1E6ED), width: 0.5),
                                              ),
                                              child: Text(
                                                _displayValue(_cellKey(row, column)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_on, size: 17, color: Color(0xFF159B68)),
                      const SizedBox(width: 8),
                      Text(_sheetName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('$_rowCount × $_columnCount', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
, caseSensitive: false);
    final formulaPattern = RegExp('(?<![A-Z0-9_])' + escapedLastColumn + r'[1-9]\d*(?!\d)', caseSensitive: false);
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key) && entry.value.isNotEmpty);
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value));
    if (hasData || hasFormulaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Column-তে তথ্য বা Formula reference আছে। আগে তা সরান।', 'The last column has data or formula references. Clear them first.'))),
      );
      return;
    }
    setState(() {
      _columnCount--;
      if (_selectedCell != null && cellPattern.hasMatch(_selectedCell!)) {
        _selectedCell = null;
      }
    });
    await _saveWorkbook();
  }

  Future<void> _importWorkbook() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final workbook = xlsx.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) throw FormatException('Workbook has no worksheets');
      final sheetName = workbook.getDefaultSheet() ?? workbook.tables.keys.first;
      final sheet = workbook.tables[sheetName];
      if (sheet == null) throw FormatException('Worksheet could not be read');
      final imported = <String, String>{};
      for (final row in sheet.rows) {
        for (final cell in row) {
          if (cell == null || cell.value == null) continue;
          final key = _cellKey(cell.rowIndex, cell.columnIndex);
          final dynamic cellValue = cell.value;
          final String value = cellValue is xlsx.FormulaCellValue
              ? '=${cellValue.formula.toString().replaceFirst(RegExp(r'^='), '')}'
              : cellValue.toString();
          if (value.isNotEmpty) imported[key] = value;
        }
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('Workbook Import করবেন?', 'Import workbook?')),
          content: Text(_t(
            '$sheetName থেকে ${imported.length}টি সেল বর্তমান শিটের জায়গায় আসবে। বর্তমান শিটের তথ্য বদলে যাবে।',
            '${imported.length} cells from $sheetName will replace the current sheet data.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('Import', 'Import'))),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      setState(() {
        _cells..clear()..addAll(imported);
        _rowCount = sheet.maxRows.clamp(1, 1000);
        _columnCount = sheet.maxColumns.clamp(1, 100);
        _sheetName = sheetName;
        _selectedCell = null;
      });
      await _saveWorkbook();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Import সফল হয়েছে।', 'XLSX imported successfully.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Import করা যায়নি: ', 'Import failed: ') + error.toString())),
      );
    }
  }

  Future<void> _exportWorkbook() async {
    try {
      final workbook = xlsx.Excel.createExcel();
      final defaultName = workbook.getDefaultSheet();
      final safeName = _sheetName.trim().isEmpty ? 'Sheet1' : _sheetName.trim();
      if (defaultName != null && defaultName != safeName) workbook.rename(defaultName, safeName);
      final sheet = workbook[safeName];
      for (final entry in _cells.entries) {
        final value = entry.value;
        final cell = sheet.cell(xlsx.CellIndex.indexByString(entry.key.toUpperCase()));
        if (value.startsWith('=')) {
          cell.value = xlsx.FormulaCellValue(value.substring(1));
        } else {
          final numeric = double.tryParse(value);
          if (numeric != null && numeric.isFinite) {
            cell.value = numeric == numeric.roundToDouble()
                ? xlsx.IntCellValue(numeric.toInt())
                : xlsx.DoubleCellValue(numeric);
          } else if (value.toUpperCase() == 'TRUE' || value.toUpperCase() == 'FALSE') {
            cell.value = xlsx.BoolCellValue(value.toUpperCase() == 'TRUE');
          } else {
            cell.value = xlsx.TextCellValue(value);
          }
        }
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('XLSX encoding failed');
      final fileName = '${safeName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.xlsx';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        dialogTitle: _t('XLSX ফাইল সংরক্ষণ', 'Save XLSX workbook'),
      );
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Export সম্পন্ন হয়েছে।', 'XLSX export completed.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Export করা যায়নি: ', 'Export failed: ') + error.toString())),
      );
    }
  }

  Future<void> _clearSheet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('শিট খালি করবেন?', 'Clear sheet?')),
        content: Text(_t('সব সেলের তথ্য মুছে যাবে।', 'All cell data will be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('মুছুন', 'Clear'))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _cells.clear();
      _selectedCell = null;
    });
    await _saveWorkbook();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(_t('OFFYNEX শিটস', 'OFFYNEX Sheets')),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t('XLSX Import', 'Import XLSX'),
            onPressed: _importWorkbook,
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: _t('XLSX Export', 'Export XLSX'),
            onPressed: _exportWorkbook,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: _t('শিটের নাম পরিবর্তন', 'Rename sheet'),
            onPressed: _renameSheet,
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
          IconButton(
            tooltip: _t('সংরক্ষণ', 'Save'),
            onPressed: _saveWorkbook,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: _t('সব মুছুন', 'Clear all'),
            onPressed: _clearSheet,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addRows,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('১০টি Row', '10 Rows')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addColumns,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('২টি Column', '2 Columns')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _rowCount > 1 ? _removeLastRow : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Row বাদ', 'Remove last row')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _columnCount > 1 ? _removeLastColumn : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Column বাদ', 'Remove last column')),
                      ),
                      Chip(
                        avatar: Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 16),
                        label: Text(_saved ? _t('সংরক্ষিত', 'Saved') : _t('সংরক্ষণ হচ্ছে', 'Saving')),
                      ),
                    ],
                  ),
                ),
                if (_selectedCell != null)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEAF2FC),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Text(_selectedCell!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_cells[_selectedCell!] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('= ${_displayValue(_selectedCell!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) => notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            horizontalMargin: 8,
                            columnSpacing: 4,
                            headingRowHeight: 38,
                            dataRowMinHeight: 42,
                            dataRowMaxHeight: 48,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFE5ECF5)),
                            columns: [
                              DataColumn(label: SizedBox(width: 42, child: Center(child: Text('#')))),
                              for (var column = 0; column < _columnCount; column++)
                                DataColumn(
                                  label: SizedBox(
                                    width: 104,
                                    child: Center(
                                      child: Text(_columnName(column), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (var row = 0; row < _rowCount; row++)
                                DataRow(
                                  cells: [
                                    DataCell(SizedBox(width: 42, child: Center(child: Text('${row + 1}', style: const TextStyle(color: Colors.black54))))),
                                    for (var column = 0; column < _columnCount; column++)
                                      DataCell(
                                        SizedBox(
                                          width: 104,
                                          child: InkWell(
                                            onTap: () => _editCell(row, column),
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: _selectedCell == _cellKey(row, column) ? const Color(0xFFDCEBFF) : Colors.white,
                                                border: Border.all(color: const Color(0xFFE1E6ED), width: 0.5),
                                              ),
                                              child: Text(
                                                _displayValue(_cellKey(row, column)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_on, size: 17, color: Color(0xFF159B68)),
                      const SizedBox(width: 8),
                      Text(_sheetName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('$_rowCount × $_columnCount', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
, caseSensitive: false);
    final formulaPattern = RegExp('(?<![A-Z0-9_])${RegExp.escape(lastColumn)}[1-9]\\d*(?!\\d)', caseSensitive: false);
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key) && entry.value.isNotEmpty);
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value));
    if (hasData || hasFormulaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Column-তে তথ্য বা Formula reference আছে। আগে তা সরান।', 'The last column has data or formula references. Clear them first.'))),
      );
      return;
    }
    setState(() {
      _columnCount--;
      if (_selectedCell != null && cellPattern.hasMatch(_selectedCell!)) {
        _selectedCell = null;
      }
    });
    await _saveWorkbook();
  }

  Future<void> _importWorkbook() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final workbook = xlsx.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) throw FormatException('Workbook has no worksheets');
      final sheetName = workbook.getDefaultSheet() ?? workbook.tables.keys.first;
      final sheet = workbook.tables[sheetName];
      if (sheet == null) throw FormatException('Worksheet could not be read');
      final imported = <String, String>{};
      for (final row in sheet.rows) {
        for (final cell in row) {
          if (cell == null || cell.value == null) continue;
          final key = _cellKey(cell.rowIndex, cell.columnIndex);
          final dynamic cellValue = cell.value;
          final String value = cellValue is xlsx.FormulaCellValue
              ? '=${cellValue.formula.toString().replaceFirst(RegExp(r'^='), '')}'
              : cellValue.toString();
          if (value.isNotEmpty) imported[key] = value;
        }
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('Workbook Import করবেন?', 'Import workbook?')),
          content: Text(_t(
            '$sheetName থেকে ${imported.length}টি সেল বর্তমান শিটের জায়গায় আসবে। বর্তমান শিটের তথ্য বদলে যাবে।',
            '${imported.length} cells from $sheetName will replace the current sheet data.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('Import', 'Import'))),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      setState(() {
        _cells..clear()..addAll(imported);
        _rowCount = sheet.maxRows.clamp(1, 1000);
        _columnCount = sheet.maxColumns.clamp(1, 100);
        _sheetName = sheetName;
        _selectedCell = null;
      });
      await _saveWorkbook();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Import সফল হয়েছে।', 'XLSX imported successfully.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Import করা যায়নি: ', 'Import failed: ') + error.toString())),
      );
    }
  }

  Future<void> _exportWorkbook() async {
    try {
      final workbook = xlsx.Excel.createExcel();
      final defaultName = workbook.getDefaultSheet();
      final safeName = _sheetName.trim().isEmpty ? 'Sheet1' : _sheetName.trim();
      if (defaultName != null && defaultName != safeName) workbook.rename(defaultName, safeName);
      final sheet = workbook[safeName];
      for (final entry in _cells.entries) {
        final value = entry.value;
        final cell = sheet.cell(xlsx.CellIndex.indexByString(entry.key.toUpperCase()));
        if (value.startsWith('=')) {
          cell.value = xlsx.FormulaCellValue(value.substring(1));
        } else {
          final numeric = double.tryParse(value);
          if (numeric != null && numeric.isFinite) {
            cell.value = numeric == numeric.roundToDouble()
                ? xlsx.IntCellValue(numeric.toInt())
                : xlsx.DoubleCellValue(numeric);
          } else if (value.toUpperCase() == 'TRUE' || value.toUpperCase() == 'FALSE') {
            cell.value = xlsx.BoolCellValue(value.toUpperCase() == 'TRUE');
          } else {
            cell.value = xlsx.TextCellValue(value);
          }
        }
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('XLSX encoding failed');
      final fileName = '${safeName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.xlsx';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        dialogTitle: _t('XLSX ফাইল সংরক্ষণ', 'Save XLSX workbook'),
      );
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Export সম্পন্ন হয়েছে।', 'XLSX export completed.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Export করা যায়নি: ', 'Export failed: ') + error.toString())),
      );
    }
  }

  Future<void> _clearSheet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('শিট খালি করবেন?', 'Clear sheet?')),
        content: Text(_t('সব সেলের তথ্য মুছে যাবে।', 'All cell data will be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('মুছুন', 'Clear'))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _cells.clear();
      _selectedCell = null;
    });
    await _saveWorkbook();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(_t('OFFYNEX শিটস', 'OFFYNEX Sheets')),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t('XLSX Import', 'Import XLSX'),
            onPressed: _importWorkbook,
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: _t('XLSX Export', 'Export XLSX'),
            onPressed: _exportWorkbook,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: _t('শিটের নাম পরিবর্তন', 'Rename sheet'),
            onPressed: _renameSheet,
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
          IconButton(
            tooltip: _t('সংরক্ষণ', 'Save'),
            onPressed: _saveWorkbook,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: _t('সব মুছুন', 'Clear all'),
            onPressed: _clearSheet,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addRows,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('১০টি Row', '10 Rows')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addColumns,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('২টি Column', '2 Columns')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _rowCount > 1 ? _removeLastRow : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Row বাদ', 'Remove last row')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _columnCount > 1 ? _removeLastColumn : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Column বাদ', 'Remove last column')),
                      ),
                      Chip(
                        avatar: Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 16),
                        label: Text(_saved ? _t('সংরক্ষিত', 'Saved') : _t('সংরক্ষণ হচ্ছে', 'Saving')),
                      ),
                    ],
                  ),
                ),
                if (_selectedCell != null)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEAF2FC),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Text(_selectedCell!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_cells[_selectedCell!] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('= ${_displayValue(_selectedCell!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) => notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            horizontalMargin: 8,
                            columnSpacing: 4,
                            headingRowHeight: 38,
                            dataRowMinHeight: 42,
                            dataRowMaxHeight: 48,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFE5ECF5)),
                            columns: [
                              DataColumn(label: SizedBox(width: 42, child: Center(child: Text('#')))),
                              for (var column = 0; column < _columnCount; column++)
                                DataColumn(
                                  label: SizedBox(
                                    width: 104,
                                    child: Center(
                                      child: Text(_columnName(column), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (var row = 0; row < _rowCount; row++)
                                DataRow(
                                  cells: [
                                    DataCell(SizedBox(width: 42, child: Center(child: Text('${row + 1}', style: const TextStyle(color: Colors.black54))))),
                                    for (var column = 0; column < _columnCount; column++)
                                      DataCell(
                                        SizedBox(
                                          width: 104,
                                          child: InkWell(
                                            onTap: () => _editCell(row, column),
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: _selectedCell == _cellKey(row, column) ? const Color(0xFFDCEBFF) : Colors.white,
                                                border: Border.all(color: const Color(0xFFE1E6ED), width: 0.5),
                                              ),
                                              child: Text(
                                                _displayValue(_cellKey(row, column)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_on, size: 17, color: Color(0xFF159B68)),
                      const SizedBox(width: 8),
                      Text(_sheetName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('$_rowCount × $_columnCount', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
, caseSensitive: false);
    final formulaPattern = RegExp('(?<![A-Z0-9_])' + escapedLastColumn + r'[1-9]\d*(?!\d)', caseSensitive: false);
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key) && entry.value.isNotEmpty);
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value));
    if (hasData || hasFormulaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Column-তে তথ্য বা Formula reference আছে। আগে তা সরান।', 'The last column has data or formula references. Clear them first.'))),
      );
      return;
    }
    setState(() {
      _columnCount--;
      if (_selectedCell != null && cellPattern.hasMatch(_selectedCell!)) {
        _selectedCell = null;
      }
    });
    await _saveWorkbook();
  }

  Future<void> _importWorkbook() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final workbook = xlsx.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) throw FormatException('Workbook has no worksheets');
      final sheetName = workbook.getDefaultSheet() ?? workbook.tables.keys.first;
      final sheet = workbook.tables[sheetName];
      if (sheet == null) throw FormatException('Worksheet could not be read');
      final imported = <String, String>{};
      for (final row in sheet.rows) {
        for (final cell in row) {
          if (cell == null || cell.value == null) continue;
          final key = _cellKey(cell.rowIndex, cell.columnIndex);
          final dynamic cellValue = cell.value;
          final String value = cellValue is xlsx.FormulaCellValue
              ? '=${cellValue.formula.toString().replaceFirst(RegExp(r'^='), '')}'
              : cellValue.toString();
          if (value.isNotEmpty) imported[key] = value;
        }
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('Workbook Import করবেন?', 'Import workbook?')),
          content: Text(_t(
            '$sheetName থেকে ${imported.length}টি সেল বর্তমান শিটের জায়গায় আসবে। বর্তমান শিটের তথ্য বদলে যাবে।',
            '${imported.length} cells from $sheetName will replace the current sheet data.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('Import', 'Import'))),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      setState(() {
        _cells..clear()..addAll(imported);
        _rowCount = sheet.maxRows.clamp(1, 1000);
        _columnCount = sheet.maxColumns.clamp(1, 100);
        _sheetName = sheetName;
        _selectedCell = null;
      });
      await _saveWorkbook();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Import সফল হয়েছে।', 'XLSX imported successfully.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Import করা যায়নি: ', 'Import failed: ') + error.toString())),
      );
    }
  }

  Future<void> _exportWorkbook() async {
    try {
      final workbook = xlsx.Excel.createExcel();
      final defaultName = workbook.getDefaultSheet();
      final safeName = _sheetName.trim().isEmpty ? 'Sheet1' : _sheetName.trim();
      if (defaultName != null && defaultName != safeName) workbook.rename(defaultName, safeName);
      final sheet = workbook[safeName];
      for (final entry in _cells.entries) {
        final value = entry.value;
        final cell = sheet.cell(xlsx.CellIndex.indexByString(entry.key.toUpperCase()));
        if (value.startsWith('=')) {
          cell.value = xlsx.FormulaCellValue(value.substring(1));
        } else {
          final numeric = double.tryParse(value);
          if (numeric != null && numeric.isFinite) {
            cell.value = numeric == numeric.roundToDouble()
                ? xlsx.IntCellValue(numeric.toInt())
                : xlsx.DoubleCellValue(numeric);
          } else if (value.toUpperCase() == 'TRUE' || value.toUpperCase() == 'FALSE') {
            cell.value = xlsx.BoolCellValue(value.toUpperCase() == 'TRUE');
          } else {
            cell.value = xlsx.TextCellValue(value);
          }
        }
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('XLSX encoding failed');
      final fileName = '${safeName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.xlsx';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        dialogTitle: _t('XLSX ফাইল সংরক্ষণ', 'Save XLSX workbook'),
      );
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('XLSX Export সম্পন্ন হয়েছে।', 'XLSX export completed.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Export করা যায়নি: ', 'Export failed: ') + error.toString())),
      );
    }
  }

  Future<void> _clearSheet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('শিট খালি করবেন?', 'Clear sheet?')),
        content: Text(_t('সব সেলের তথ্য মুছে যাবে।', 'All cell data will be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('মুছুন', 'Clear'))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _cells.clear();
      _selectedCell = null;
    });
    await _saveWorkbook();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(_t('OFFYNEX শিটস', 'OFFYNEX Sheets')),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t('XLSX Import', 'Import XLSX'),
            onPressed: _importWorkbook,
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: _t('XLSX Export', 'Export XLSX'),
            onPressed: _exportWorkbook,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: _t('শিটের নাম পরিবর্তন', 'Rename sheet'),
            onPressed: _renameSheet,
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
          IconButton(
            tooltip: _t('সংরক্ষণ', 'Save'),
            onPressed: _saveWorkbook,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: _t('সব মুছুন', 'Clear all'),
            onPressed: _clearSheet,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addRows,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('১০টি Row', '10 Rows')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addColumns,
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(_t('২টি Column', '2 Columns')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _rowCount > 1 ? _removeLastRow : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Row বাদ', 'Remove last row')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _columnCount > 1 ? _removeLastColumn : null,
                        icon: const Icon(Icons.remove, size: 17),
                        label: Text(_t('শেষ Column বাদ', 'Remove last column')),
                      ),
                      Chip(
                        avatar: Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 16),
                        label: Text(_saved ? _t('সংরক্ষিত', 'Saved') : _t('সংরক্ষণ হচ্ছে', 'Saving')),
                      ),
                    ],
                  ),
                ),
                if (_selectedCell != null)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEAF2FC),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Text(_selectedCell!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_cells[_selectedCell!] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('= ${_displayValue(_selectedCell!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) => notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            horizontalMargin: 8,
                            columnSpacing: 4,
                            headingRowHeight: 38,
                            dataRowMinHeight: 42,
                            dataRowMaxHeight: 48,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFE5ECF5)),
                            columns: [
                              DataColumn(label: SizedBox(width: 42, child: Center(child: Text('#')))),
                              for (var column = 0; column < _columnCount; column++)
                                DataColumn(
                                  label: SizedBox(
                                    width: 104,
                                    child: Center(
                                      child: Text(_columnName(column), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                            ],
                            rows: [
                              for (var row = 0; row < _rowCount; row++)
                                DataRow(
                                  cells: [
                                    DataCell(SizedBox(width: 42, child: Center(child: Text('${row + 1}', style: const TextStyle(color: Colors.black54))))),
                                    for (var column = 0; column < _columnCount; column++)
                                      DataCell(
                                        SizedBox(
                                          width: 104,
                                          child: InkWell(
                                            onTap: () => _editCell(row, column),
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: _selectedCell == _cellKey(row, column) ? const Color(0xFFDCEBFF) : Colors.white,
                                                border: Border.all(color: const Color(0xFFE1E6ED), width: 0.5),
                                              ),
                                              child: Text(
                                                _displayValue(_cellKey(row, column)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_on, size: 17, color: Color(0xFF159B68)),
                      const SizedBox(width: 8),
                      Text(_sheetName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('$_rowCount × $_columnCount', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
