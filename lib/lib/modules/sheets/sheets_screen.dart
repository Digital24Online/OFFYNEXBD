import 'dart:convert';

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
    // Capture an immutable snapshot now and serialize writes to prevent older saves
    // from overwriting a newer edit when several saves happen close together.
    final snapshot = jsonEncode({
      'name': _sheetName,
      'rows': _rowCount,
      'columns': _columnCount,
      'cells': Map<String, String>.from(_cells),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (mounted) setState(() => _saved = false);
    _saveQueue = _saveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_sheetStorageKey, snapshot);
      if (!success) throw StateError('Workbook could not be saved');
    });
    try {
      await _saveQueue;
      if (mounted) setState(() => _saved = true);
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
    final pattern = RegExp(r'^[A-Z]+' + _rowCount.toString() + r'

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
);
    final hasData = _cells.entries.any((entry) =>
        pattern.hasMatch(entry.key.toUpperCase()) && entry.value.isNotEmpty);
    if (hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Row-তে তথ্য আছে। আগে তথ্য সরান।', 'The last row contains data. Clear it before removing.'))),
      );
      return;
    }
    setState(() {
      _rowCount--;
      if (_selectedCell != null && RegExp(r'^[A-Z]+' + (_rowCount + 1).toString() + r'

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
).hasMatch(_selectedCell!)) {
        _selectedCell = null;
      }
    });
    await _saveWorkbook();
  }

  Future<void> _removeLastColumn() async {
    if (_columnCount <= 1) return;
    final lastColumn = _columnName(_columnCount - 1);
    final pattern = RegExp('^' + lastColumn + r'[1-9]\\d*

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
    final hasData = _cells.entries.any((entry) =>
        pattern.hasMatch(entry.key) && entry.value.isNotEmpty);
    if (hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Column-তে তথ্য আছে। আগে তথ্য সরান।', 'The last column contains data. Clear it before removing.'))),
      );
      return;
    }
    setState(() {
      _columnCount--;
      if (_selectedCell != null && _selectedCell!.startsWith(lastColumn)) {
        _selectedCell = null;
      }
    });
    await _saveWorkbook();
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
