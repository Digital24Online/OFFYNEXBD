import 'dart:convert';
import 'dart:typed_data';
import 'package:excel_community/excel_community.dart' as xlsx;
import 'package:file_picker/file_picker.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'sheets_pdf_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sheets_formula_engine.dart';
import 'sheets_workbook_limits.dart';
import 'sheets_import_safety.dart';
import 'sheets_workbook_codec.dart';
import 'sheets_csv_codec.dart';
import 'sheets_row_view.dart';
import 'sheets_find_replace.dart';
import 'sheets_data_validation.dart';
import 'sheets_xlsx_validation_codec.dart';
import 'sheets_analytics.dart';
import 'sheets_analytics_widgets.dart';
import '../../theme/offynex_theme.dart';

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

  SheetsWorkbook _workbook = SheetsWorkbook(
    activeSheetId: 'sheet-1',
    sheets: [
      SheetsWorksheet(
        id: 'sheet-1',
        name: 'Sheet1',
        rows: _initialRows,
        columns: _initialColumns,
      ),
    ],
  );
  SheetsWorksheet get _activeWorksheet => _workbook.activeSheet;
  Map<String, String> get _cells => _activeWorksheet.cells;
  Map<String, Map<String, dynamic>> get _cellStyles => _activeWorksheet.styles;
  int get _rowCount => _activeWorksheet.rows;
  set _rowCount(int value) => _activeWorksheet.rows = value;
  int get _columnCount => _activeWorksheet.columns;
  set _columnCount(int value) => _activeWorksheet.columns = value;
  String get _sheetName => _activeWorksheet.name;
  set _sheetName(String value) => _activeWorksheet.name = value;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _loading = true;
  bool _workbookDataBlocked = false;
  bool _saved = true;
  String? _workbookRecoveryMessage;
  Future<void> _saveQueue = Future<void>.value();
  String? _selectedCell;
  int? _viewColumnIndex;
  bool _sortAscending = true;
  String? _filterQuery;

  final TextEditingController _formulaBarController = TextEditingController();
  int _activeRibbonTab = 0;
  bool _showGridlines = true;
  double _zoom = 1.0;

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
    var canReplaceRawWorkbook = false;
    try {
      _workbook = raw == null
          ? SheetsWorkbook(
              activeSheetId: 'sheet-1',
              sheets: [SheetsWorksheet(id: 'sheet-1', name: 'Sheet1', rows: _initialRows, columns: _initialColumns)],
            )
          : SheetsWorkbookCodec.decode(raw);
      canReplaceRawWorkbook = raw != null;
    } catch (error) {
      final recoveryKey = 'offynex_sheets_workbook_recovery_${DateTime.now().microsecondsSinceEpoch}';
      final preserved = raw != null && await prefs.setString(recoveryKey, raw);
      _workbookDataBlocked = true;
      // A recovery copy is not permission to replace the damaged primary data.
      canReplaceRawWorkbook = false;
      _workbookRecoveryMessage = preserved
          ? _t('Workbook পড়া যায়নি। মূল ডেটার Recovery Copy সংরক্ষিত: $recoveryKey', 'Workbook could not be read. Original data recovery copy saved: $recoveryKey')
          : _t('Workbook পড়া যায়নি এবং Recovery Copy সংরক্ষণ ব্যর্থ হয়েছে: $error', 'Workbook could not be read and recovery copy failed: $error');
      _workbook = SheetsWorkbook(
        activeSheetId: 'sheet-1',
        sheets: [SheetsWorksheet(id: 'sheet-1', name: 'Sheet1', rows: _initialRows, columns: _initialColumns)],
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
    final recoveryMessage = _workbookRecoveryMessage;
    if (recoveryMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(recoveryMessage), duration: const Duration(seconds: 10)),
      );
    }
    if (raw != null && canReplaceRawWorkbook &&
        !raw.contains('"format":"OFFYNEXBD_SHEETS_WORKBOOK"')) {
      await _saveWorkbook();
    }
  }

  Future<void> _saveWorkbook() async {
    if (_workbookDataBlocked) return;
    final snapshot = SheetsWorkbookCodec.encode(_workbook);
    if (mounted) setState(() => _saved = false);
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_sheetStorageKey, snapshot);
      if (!success) throw StateError('Workbook could not be saved');
    });
    final saveOperation = _saveQueue;
    try {
      await saveOperation;
      if (mounted && identical(_saveQueue, saveOperation)) setState(() => _saved = true);
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
    final raw = _cells[key] ?? '';
    final parsed = raw.startsWith('=') ? _numericValue(key) : double.tryParse(raw);
    final numeric = parsed != null && parsed.isFinite ? parsed : null;
    if (raw.startsWith('=') && numeric == null) return '#ERROR';
    if (numeric == null) return raw;
    switch (_cellStyles[key]?['numberFormat']) {
      case 'number': return numeric.toStringAsFixed(2);
      case 'currency': return '৳${numeric.toStringAsFixed(2)}';
      case 'percent': return '${(numeric * 100).toStringAsFixed(2)}%';
      default:
        return numeric == numeric.roundToDouble()
            ? numeric.toStringAsFixed(0)
            : numeric.toString();
    }
  }

  Map<String, dynamic> _styleFor(String key) =>
      Map<String, dynamic>.from(_cellStyles[key] ?? const {});

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return fallback;
    return Color(int.parse('FF$hex', radix: 16));
  }

  TextStyle _cellTextStyle(String key, [Map<String, dynamic>? resolvedStyle]) {
    final style = resolvedStyle ?? _cellStyles[key] ?? const <String, dynamic>{};
    return TextStyle(
      fontSize: ((style['fontSize'] as num?)?.toDouble() ?? 13) * _zoom,
      fontWeight: style['bold'] == true ? FontWeight.bold : FontWeight.normal,
      fontStyle: style['italic'] == true ? FontStyle.italic : FontStyle.normal,
      decoration: style['underline'] == true ? TextDecoration.underline : TextDecoration.none,
      color: _colorFromHex(style['fontColor'] as String?, Colors.black87),
    );
  }

  Alignment _cellAlignment(String key, [Map<String, dynamic>? resolvedStyle]) {
    final style = resolvedStyle ?? _cellStyles[key] ?? const <String, dynamic>{};
    final horizontal = switch (style['align']) {
      'center' => 0.0,
      'right' => 1.0,
      _ => -1.0,
    };
    final vertical = switch (style['verticalAlign']) {
      'top' => -1.0,
      'center' => 0.0,
      'bottom' => 1.0,
      _ => 0.0,
    };
    return Alignment(horizontal, vertical);
  }

  TextAlign _cellTextAlign(String key, [Map<String, dynamic>? resolvedStyle]) {
    switch ((resolvedStyle ?? _cellStyles[key])?['align']) {
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      default: return TextAlign.left;
    }
  }

  Future<void> _applyCellStyle(String property, dynamic value) async {
    final key = _selectedCell;
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('আগে একটি Cell নির্বাচন করুন।', 'Select a cell first.'))),
      );
      return;
    }
    setState(() {
      final style = _styleFor(key);
      if (value == null) {
        style.remove(property);
      } else {
        style[property] = value;
      }
      if (style.isEmpty) {
        _cellStyles.remove(key);
      } else {
        _cellStyles[key] = style;
      }
    });
    await _saveWorkbook();
  }

  Future<void> _toggleCellStyle(String property) async {
    final key = _selectedCell;
    if (key == null) {
      await _applyCellStyle(property, true);
      return;
    }
    await _applyCellStyle(property, _cellStyles[key]?[property] != true);
  }

  Future<void> _chooseFontSize() async {
    const sizes = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(_t('Font Size', 'Font Size')),
        children: [
          for (final size in sizes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, size),
              child: Text('$size pt'),
            ),
        ],
      ),
    );
    if (selected != null) await _applyCellStyle('fontSize', selected);
  }

  Future<void> _chooseCellColor({required bool background}) async {
    const colors = [
      '000000', '434343', '666666', '999999', 'D9EAD3', 'B6D7A8',
      '6AA84F', '38761D', 'CFE2F3', '9FC5E8', '3D85C6', '0B5394',
      'FCE5CD', 'F9CB9C', 'F6B26B', 'E69138', 'F4CCCC', 'EA9999',
      'E06666', 'CC0000', 'D9D2E9', 'B4A7D6', '8E7CC3', '674EA7', 'FFFFFF',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(background ? _t('Fill Color', 'Fill Color') : _t('Font Color', 'Font Color')),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final hex in colors)
                InkWell(
                  onTap: () => Navigator.pop(dialogContext, hex),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _colorFromHex(hex, Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, ''), child: Text(_t('রং সরান', 'Clear color'))),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_t('বাতিল', 'Cancel'))),
        ],
      ),
    );
    if (selected == null) return;
    await _applyCellStyle(background ? 'fillColor' : 'fontColor', selected.isEmpty ? null : selected);
  }

  Future<void> _chooseNumberFormat() async {
    const formats = {
      'general': 'General',
      'number': 'Number (2 decimals)',
      'currency': 'Currency (৳)',
      'percent': 'Percentage',
    };
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(_t('Number Format', 'Number Format')),
        children: [
          for (final entry in formats.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (selected != null) await _applyCellStyle('numberFormat', selected);
  }


  String _defaultAnalysisRange() {
    var lastRow = 2;
    var lastColumn = 2;
    for (final key in {
      ..._cells.keys,
      ..._cellStyles.keys,
      ..._activeWorksheet.validations.keys,
    }) {
      try {
        final cell = SheetsAnalytics.parseRange(key);
        if (cell.firstRow > lastRow) lastRow = cell.firstRow;
        if (cell.firstColumn > lastColumn) lastColumn = cell.firstColumn;
      } on FormatException {
        continue;
      }
    }
    lastRow = lastRow.clamp(2, SheetsWorkbookLimits.maxRows).toInt();
    lastColumn = lastColumn.clamp(2, SheetsWorkbookLimits.maxColumns).toInt();
    return 'A1:${SheetsAnalytics.columnName(lastColumn)}$lastRow';
  }

  Map<String, String> _resolvedSheetValues(SheetsWorksheet sheet) {
    final engine = SheetsFormulaEngine(sheet.cells);
    return {
      for (final entry in sheet.cells.entries)
        entry.key: entry.value.startsWith('=')
            ? (engine.evaluateCell(entry.key)?.toString() ?? '#ERROR')
            : entry.value,
    };
  }

  Future<void> _setConditionalFormatting() async {
    final selected = _selectedCell;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('আগে একটি Cell নির্বাচন করুন।', 'Select a cell first.'))),
      );
      return;
    }
    if (_activeWorksheet.conditionalFormats.length >= SheetsAnalytics.maxConditionalRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('সর্বোচ্চ ১০০টি নিয়ম রাখা যাবে।', 'A worksheet can have up to 100 rules.'))),
      );
      return;
    }
    final rule = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SheetsConditionalRuleDialog(initialRange: selected, isBangla: _bn),
    );
    if (rule == null || !mounted) return;
    setState(() => _activeWorksheet.conditionalFormats.add(rule));
    await _saveWorkbook();
  }

  Future<void> _clearConditionalFormatting() async {
    if (_activeWorksheet.conditionalFormats.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Conditional Formatting সরাবেন?', 'Clear conditional formatting?')),
        content: Text(_t(
          'এই Worksheet-এর সব Conditional Formatting নিয়ম সরানো হবে।',
          'All conditional formatting rules on this worksheet will be removed.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('সব সরান', 'Clear rules'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _activeWorksheet.conditionalFormats.clear());
    await _saveWorkbook();
  }

  Future<void> _createChart() async {
    if (_activeWorksheet.charts.length >= SheetsAnalytics.maxCharts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('একটি Worksheet-এ সর্বোচ্চ ২০টি Chart রাখা যাবে।', 'A worksheet can contain up to 20 charts.'))),
      );
      return;
    }
    final chart = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => SheetsChartDialog(initialRange: _defaultAnalysisRange(), isBangla: _bn),
    );
    if (chart == null || !mounted) return;
    try {
      SheetsAnalytics.buildChartData(_resolvedSheetValues(_activeWorksheet), chart['range']!);
      setState(() => _activeWorksheet.charts.add(chart));
      await _saveWorkbook();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Chart তৈরি করা যায়নি: ', 'Could not create chart: ') + error.toString())),
      );
    }
  }

  Future<void> _deleteChart(int index) async {
    if (index < 0 || index >= _activeWorksheet.charts.length) return;
    setState(() => _activeWorksheet.charts.removeAt(index));
    await _saveWorkbook();
  }

  Future<void> _createPivotTable() async {
    if (_workbook.sheets.length >= SheetsWorkbookCodec.maxWorksheets) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('সর্বোচ্চ ১০০টি Worksheet রাখা যাবে।', 'A workbook can contain up to 100 worksheets.'))),
      );
      return;
    }
    final config = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => SheetsPivotDialog(initialRange: _defaultAnalysisRange(), isBangla: _bn),
    );
    if (config == null || !mounted) return;
    try {
      final rows = SheetsAnalytics.buildPivotSummary(
        cells: _resolvedSheetValues(_activeWorksheet),
        rangeText: config['range']!,
        groupColumn: config['groupColumn']!,
        valueColumn: config['valueColumn']!,
        aggregation: config['aggregation']!,
      );
      final names = _workbook.sheets.map((sheet) => sheet.name.toLowerCase()).toSet();
      var suffix = 1;
      var name = 'Pivot Table';
      while (names.contains(name.toLowerCase())) {
        suffix++;
        name = 'Pivot Table $suffix';
      }
      final cells = <String, String>{};
      final styles = <String, Map<String, dynamic>>{};
      for (var row = 0; row < rows.length; row++) {
        for (var column = 0; column < rows[row].length; column++) {
          final key = SheetsAnalytics.columnName(column + 1) + (row + 1).toString();
          cells[key] = rows[row][column];
          if (row == 0) styles[key] = {'bold': true, 'fillColor': 'CFE2F3'};
          if (row == rows.length - 1) styles[key] = {...?styles[key], 'bold': true};
        }
      }
      final pivotSheet = SheetsWorksheet(
        id: 'pivot-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        rows: rows.length,
        columns: 2,
        cells: cells,
        styles: styles,
        pivotConfig: {'sourceSheetId': _activeWorksheet.id, ...config},
      );
      setState(() {
        _workbook.sheets.add(pivotSheet);
        _workbook.activeSheetId = pivotSheet.id;
        _selectedCell = 'A1';
        _formulaBarController.text = cells['A1'] ?? '';
        _viewColumnIndex = null;
        _filterQuery = null;
      });
      await _saveWorkbook();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Pivot Table তৈরি করা যায়নি: ', 'Could not create Pivot Table: ') + error.toString())),
      );
    }
  }

  Future<void> _refreshPivotTable() async {
    final config = _activeWorksheet.pivotConfig;
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('এই Worksheet Pivot Table নয়।', 'This worksheet is not a Pivot Table.'))),
      );
      return;
    }
    try {
      SheetsWorksheet? source;
      for (final sheet in _workbook.sheets) {
        if (sheet.id == config['sourceSheetId']) source = sheet;
      }
      if (source == null) throw const FormatException('The original source worksheet no longer exists.');
      final rows = SheetsAnalytics.buildPivotSummary(
        cells: _resolvedSheetValues(source),
        rangeText: config['range']?.toString() ?? '',
        groupColumn: config['groupColumn']?.toString() ?? '',
        valueColumn: config['valueColumn']?.toString() ?? '',
        aggregation: config['aggregation']?.toString() ?? '',
      );
      final cells = <String, String>{};
      final styles = <String, Map<String, dynamic>>{};
      for (var row = 0; row < rows.length; row++) {
        for (var column = 0; column < rows[row].length; column++) {
          final key = SheetsAnalytics.columnName(column + 1) + (row + 1).toString();
          cells[key] = rows[row][column];
          if (row == 0) styles[key] = {'bold': true, 'fillColor': 'CFE2F3'};
          if (row == rows.length - 1) styles[key] = {...?styles[key], 'bold': true};
        }
      }
      setState(() {
        _activeWorksheet.cells..clear()..addAll(cells);
        _activeWorksheet.styles..clear()..addAll(styles);
        _activeWorksheet.rows = rows.length;
        _activeWorksheet.columns = 2;
        _selectedCell = 'A1';
        _formulaBarController.text = cells['A1'] ?? '';
      });
      await _saveWorkbook();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Pivot Refresh করা যায়নি: ', 'Pivot refresh failed: ') + error.toString())),
      );
    }
  }

  Widget _buildChartGallery() {
    final charts = _activeWorksheet.charts;
    if (charts.isEmpty) return const SizedBox.shrink();
    final values = _resolvedSheetValues(_activeWorksheet);
    return Container(
      height: 190,
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OFFYNEXTheme.border))),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        scrollDirection: Axis.horizontal,
        itemCount: charts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chart = charts[index];
          SheetsChartData? data;
          String? error;
          try {
            data = SheetsAnalytics.buildChartData(values, chart['range']?.toString() ?? '');
          } catch (exception) {
            error = exception.toString();
          }
          return SizedBox(
            width: 280,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text(
                      chart['title']?.toString() ?? _t('Chart', 'Chart'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    IconButton(
                      tooltip: _t('Chart মুছুন', 'Remove chart'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteChart(index),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ]),
                  Expanded(
                    child: data == null
                        ? Center(child: Text(error ?? _t('Data পাওয়া যায়নি', 'No chart data')))
                        : SheetsChartPreview(data: data, type: chart['type']?.toString() ?? 'bar'),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _setDataValidation() async {
    final key = _selectedCell;
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('আগে একটি Cell নির্বাচন করুন।', 'Select a cell first.'))),
      );
      return;
    }
    final controller = TextEditingController(
      text: (_activeWorksheet.validations[key] ?? const <String>[]).join('\n'),
    );
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Dropdown তালিকা', 'Dropdown list validation')),
        content: TextField(
          key: const ValueKey('sheets-validation-options'),
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: _t('প্রতি লাইনে একটি Option', 'One option per line'),
            hintText: 'Pending\nPaid\nDue',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Text(_t('নিয়ম সরান', 'Remove rule')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_t('সংরক্ষণ', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || !mounted) return;
    try {
      final options = raw.trim().isEmpty
          ? null
          : SheetsDataValidation.parseOptions(raw);
      final currentValue = _cells[key] ?? '';
      if (!SheetsDataValidation.accepts(currentValue, options)) {
        throw const FormatException(
          'Current cell value is not in the new dropdown options. Change the cell value first.',
        );
      }
      setState(() {
        if (options == null) {
          _activeWorksheet.validations.remove(key);
        } else {
          _activeWorksheet.validations[key] = options;
        }
      });
      await _saveWorkbook();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(options == null
              ? _t('Dropdown নিয়ম সরানো হয়েছে।', 'Dropdown rule removed.')
              : _t('Dropdown নিয়ম সংরক্ষিত হয়েছে।', 'Dropdown rule saved.'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('নিয়ম সংরক্ষণ করা যায়নি: ', 'Could not save rule: ') + error.toString())),
        );
      }
    }
  }

  Future<void> _chooseValidatedValue() async {
    final key = _selectedCell;
    if (key == null) return;
    final options = _activeWorksheet.validations[key];
    if (options == null || options.isEmpty) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(_t('একটি Option নির্বাচন করুন', 'Choose a value')),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option),
              child: Text(option),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _writeCellValue(key, selected);
  }

  bool _cellValueAllowed(String key, String value) =>
      SheetsDataValidation.accepts(value, _activeWorksheet.validations[key]);

  /// One guarded write path for interactive cell-value changes.
  Future<bool> _writeCellValue(
    String key,
    String value, {
    bool selectAfterWrite = false,
  }) async {
    final normalized = value.trim();
    if (!_cellValueAllowed(key, normalized)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(
            'এই Cell-এর Dropdown তালিকা থেকে মান নির্বাচন করুন।',
            'Choose a value from this cell’s dropdown list.',
          ))),
        );
      }
      return false;
    }
    if (!mounted) return false;
    setState(() {
      if (normalized.isEmpty) {
        _cells.remove(key);
      } else {
        _cells[key] = normalized;
      }
      if (selectAfterWrite) _selectedCell = key;
      if (_selectedCell == key) _formulaBarController.text = normalized;
    });
    await _saveWorkbook();
    return true;
  }

  Future<void> _toggleFreezeTopRow() async {
    setState(() {
      _activeWorksheet.freezeTopRow = !_activeWorksheet.freezeTopRow;
    });
    await _saveWorkbook();
  }

  Future<void> _toggleCellBorder() async {
    final key = _selectedCell;
    await _applyCellStyle('border', key == null || _cellStyles[key]?['border'] != true);
  }

  Future<void> _toggleWrapText() async {
    final key = _selectedCell;
    await _applyCellStyle('wrapText', key == null || _cellStyles[key]?['wrapText'] != true);
  }

  Future<void> _editCell(int row, int column) async {
    final key = _cellKey(row, column);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _CellEditDialog(
        cellKey: key,
        initialValue: _cells[key] ?? '',
        title: _t('সেল সম্পাদনা', 'Edit cell'),
        valueLabel: _t('মান অথবা Formula', 'Value or formula'),
        cancelLabel: _t('বাতিল', 'Cancel'),
        clearLabel: _t('মুছুন', 'Clear'),
        saveLabel: _t('সংরক্ষণ', 'Save'),
      ),
    );
    if (result == null || !mounted) return;
    await _writeCellValue(key, result, selectAfterWrite: true);
  }

  Future<void> _renameSheet() async {
    final controller = TextEditingController(text: _sheetName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('শিটের নাম', 'Sheet name')),
        content: TextField(controller: controller, autofocus: true, maxLength: SheetsWorkbookCodec.maxSheetNameLength),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(_t('সংরক্ষণ', 'Save'))),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    try {
      SheetsWorkbookCodec.validateSheetName(result);
      if (_workbook.sheets.any((sheet) =>
          sheet.id != _workbook.activeSheetId &&
          sheet.name.toLowerCase() == result.toLowerCase())) {
        throw const FormatException('A worksheet with this name already exists.');
      }
      setState(() => _sheetName = result);
      await _saveWorkbook();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('শিটের নাম গ্রহণযোগ্য নয়: ', 'Invalid sheet name: ') + error.toString())),
        );
      }
    }
  }

  Future<void> _addWorksheet() async {
    if (_workbook.sheets.length >= SheetsWorkbookCodec.maxWorksheets) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('সর্বোচ্চ ১০০টি Worksheet রাখা যাবে।', 'A workbook can contain up to 100 worksheets.'))),
      );
      return;
    }
    final names = _workbook.sheets.map((sheet) => sheet.name.toLowerCase()).toSet();
    var number = 1;
    while (names.contains('sheet$number')) {
      number++;
    }
    final sheet = SheetsWorksheet(
      id: 'sheet-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Sheet$number',
      rows: _initialRows,
      columns: _initialColumns,
    );
    setState(() {
      _workbook.sheets.add(sheet);
      _workbook.activeSheetId = sheet.id;
      _selectedCell = null;
      _viewColumnIndex = null;
      _filterQuery = null;
      _formulaBarController.clear();
    });
    await _saveWorkbook();
  }

  Future<void> _selectWorksheet(String id) async {
    if (id == _workbook.activeSheetId) return;
    await _saveQueue;
    if (!mounted) return;
    setState(() {
      _workbook.activeSheetId = id;
      _selectedCell = null;
      _viewColumnIndex = null;
      _filterQuery = null;
      _sortAscending = true;
      _formulaBarController.clear();
    });
    await _saveWorkbook();
  }

  Future<void> _deleteWorksheet() async {
    final dependentPivots = _workbook.sheets.where(
      (sheet) => sheet.pivotConfig?['sourceSheetId'] == _workbook.activeSheetId,
    );
    if (dependentPivots.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(
        'এই Worksheet-এর ওপর Pivot Table নির্ভর করছে। আগে Pivot Worksheet মুছুন।',
        'A Pivot Table depends on this worksheet. Delete the dependent Pivot worksheet first.',
      ))));
      return;
    }
    if (_workbook.sheets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('কমপক্ষে একটি Worksheet রাখতে হবে।', 'At least one worksheet must remain.'))),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Worksheet মুছবেন?', 'Delete worksheet?')),
        content: Text(_t(
          '“$_sheetName” এবং এর সব Cell ও Formatting মুছে যাবে।',
          '“$_sheetName” and all its cells and formatting will be deleted.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('মুছুন', 'Delete'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removedId = _workbook.activeSheetId;
    setState(() {
      _workbook.sheets.removeWhere((sheet) => sheet.id == removedId);
      _workbook.activeSheetId = _workbook.sheets.first.id;
      _selectedCell = null;
      _viewColumnIndex = null;
      _filterQuery = null;
      _formulaBarController.clear();
    });
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
    final formulaPattern = RegExp(
      r'(?<![A-Z0-9_])[A-Z]+' +
          rowNumber.toString() +
          r'(?!\d)(?!\s*\()',
    );
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key.toUpperCase()) && entry.value.isNotEmpty);
    final hasFormatting = _cellStyles.keys.any((key) => cellPattern.hasMatch(key.toUpperCase()));
    final hasValidation = _activeWorksheet.validations.keys.any((key) => cellPattern.hasMatch(key.toUpperCase()));
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value.toUpperCase()));
    if (hasData || hasFormatting || hasValidation || hasFormulaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Row-তে তথ্য বা Formula reference আছে। আগে তা সরান।', 'The last row has data or formula references. Clear them first.'))),
      );
      return;
    }
    setState(() {
      _rowCount--;
      if (_selectedCell != null && cellPattern.hasMatch(_selectedCell!)) {
        _selectedCell = null;
        _formulaBarController.clear();
      }
    });
    await _saveWorkbook();
  }

  Future<void> _removeLastColumn() async {
    if (_columnCount <= 1) return;
    final lastColumn = _columnName(_columnCount - 1);
    final cellPattern = RegExp('^${RegExp.escape(lastColumn)}[1-9]\\d*\$', caseSensitive: false);
    final formulaPattern = RegExp('(?<![A-Z0-9_])${RegExp.escape(lastColumn)}[1-9]\\d*(?!\\d)', caseSensitive: false);
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key) && entry.value.isNotEmpty);
    final hasFormatting = _cellStyles.keys.any((key) => cellPattern.hasMatch(key));
    final hasValidation = _activeWorksheet.validations.keys.any((key) => cellPattern.hasMatch(key));
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value));
    if (hasData || hasFormatting || hasValidation || hasFormulaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('শেষ Column-তে তথ্য বা Formula reference আছে। আগে তা সরান।', 'The last column has data or formula references. Clear them first.'))),
      );
      return;
    }
    setState(() {
      _columnCount--;
      if (_selectedCell != null && cellPattern.hasMatch(_selectedCell!)) {
        _selectedCell = null;
        _formulaBarController.clear();
      }
    });
    await _saveWorkbook();
  }



  int? _selectedColumnIndex() =>
      SheetsRowView.columnIndexFromCellKey(_selectedCell);

  void _sortBySelectedColumn() {
    final column = _selectedColumnIndex();
    if (column == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('আগে যে Column সাজাতে চান, তার একটি Cell নির্বাচন করুন।', 'Select a cell in the column you want to sort.'))),
      );
      return;
    }
    setState(() {
      _sortAscending = _viewColumnIndex == column ? !_sortAscending : true;
      _viewColumnIndex = column;
    });
  }

  Future<void> _findAndReplace() async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    var matchCase = false;
    var includeFormulas = false;
    final request = await showDialog<({String find, String replacement, bool matchCase, bool includeFormulas})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('Find & Replace', 'Find & Replace')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('sheets-find-text'),
                controller: findController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _t('যে লেখা খুঁজবেন', 'Find what'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('sheets-replace-text'),
                controller: replaceController,
                decoration: InputDecoration(
                  labelText: _t('যে লেখা বসাবেন', 'Replace with'),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: matchCase,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(_t('বড়/ছোট হাতের অক্ষর মিলিয়ে খুঁজুন', 'Match case')),
                onChanged: (value) => setDialogState(() {
                  matchCase = value ?? false;
                }),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: includeFormulas,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(_t('Formula-এর ভেতরেও খুঁজুন', 'Include formulas')),
                onChanged: (value) => setDialogState(() {
                  includeFormulas = value ?? false;
                }),
              ),
              Text(
                _t(
                  'সব Worksheet-এর Cell-এ খোঁজা ও পরিবর্তন করা হবে।',
                  'Search and replace across every worksheet.',
                ),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              key: const ValueKey('sheets-find-replace-submit'),
              onPressed: () => Navigator.pop(
                dialogContext,
                (
                  find: findController.text,
                  replacement: replaceController.text,
                  matchCase: matchCase,
                  includeFormulas: includeFormulas,
                ),
              ),
              child: Text(_t('সব পরিবর্তন', 'Replace all')),
            ),
          ],
        ),
      ),
    );
    findController.dispose();
    replaceController.dispose();
    if (request == null || !mounted) return;
    if (request.find.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('খোঁজার লেখা দিন।', 'Enter text to find.'))),
      );
      return;
    }

    final count = SheetsFindReplace.replaceInWorkbook(
      _workbook,
      find: request.find,
      replacement: request.replacement,
      matchCase: request.matchCase,
      includeFormulas: request.includeFormulas,
    );
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('কোনো মিল পাওয়া যায়নি।', 'No matches found.'))),
      );
      return;
    }
    setState(() {
      _selectedCell = null;
      _formulaBarController.clear();
      _viewColumnIndex = null;
      _filterQuery = null;
      _sortAscending = true;
    });
    await _saveWorkbook();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _bn ? '$countটি পরিবর্তন সংরক্ষণ করা হয়েছে।' : '$count replacements saved.',
        ),
      ),
    );
  }

  Future<void> _filterBySelectedColumn() async {
    final column = _selectedColumnIndex();
    if (column == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Filter করার Column থেকে একটি Cell নির্বাচন করুন।', 'Select a cell in the column you want to filter.'))),
      );
      return;
    }
    final controller = TextEditingController(
      text: _viewColumnIndex == column ? (_filterQuery ?? '') : '',
    );
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Column Filter', 'Filter column')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _t('যে লেখা বা সংখ্যা খুঁজবেন', 'Text or number to find'),
            hintText: _t('ফাঁকা রাখলে Filter বন্ধ হবে', 'Leave blank to clear the filter'),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_t('প্রয়োগ', 'Apply')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || !mounted) return;
    setState(() {
      _viewColumnIndex = column;
      _filterQuery = query.trim().isEmpty ? null : query.trim();
    });
  }

  void _clearSortAndFilter() {
    setState(() {
      _viewColumnIndex = null;
      _filterQuery = null;
      _sortAscending = true;
    });
  }

  List<int> _buildVisibleRowIndices() {
    return SheetsRowView.buildOrder(
      rowCount: _rowCount,
      valueForRow: (row) => _viewColumnIndex == null
          ? ''
          : _displayValue(_cellKey(row, _viewColumnIndex!)),
      filter: _filterQuery,
      sortAscending: _viewColumnIndex == null ? null : _sortAscending,
    );
  }

  Future<void> _importCsv() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
        throw const FormatException('CSV file must be between 1 byte and 20 MB.');
      }
      final rows = SheetsCsvCodec.decode(utf8.decode(bytes, allowMalformed: false));
      if (rows.isEmpty) throw const FormatException('CSV file is empty');
      final columns = rows.fold<int>(
        0,
        (maximum, row) => row.length > maximum ? row.length : maximum,
      );
      SheetsWorkbookLimits.validate(rows.length, columns);

      final imported = <String, String>{};
      for (var row = 0; row < rows.length; row++) {
        for (var column = 0; column < rows[row].length; column++) {
          final value = rows[row][column];
          if (value.isNotEmpty) imported[_cellKey(row, column)] = value;
        }
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('CSV Import করবেন?', 'Import CSV?')),
          content: Text(_t(
            '${rows.length}টি Row ও $columnsটি Column বর্তমান শিটের জায়গা নেবে। CSV-তে Cell formatting থাকে না; বর্তমান তথ্য ও Formatting বদলে যাবে.',
            '${rows.length} rows and $columns columns will replace the current sheet. CSV does not contain cell formatting; current data and formatting will be replaced.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('Import', 'Import')),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      // Wait for pending edits, then preserve the complete workbook before
      // replacing this worksheet with imported CSV data.
      await _saveQueue;
      final preferences = await SharedPreferences.getInstance();
      final backupKey = await SheetsImportSafety.preserveCurrentWorkbook(
        preferences,
        preferences.getString(_sheetStorageKey),
      );
      if (!mounted) return;
      setState(() {
        _cells..clear()..addAll(imported);
        _cellStyles.clear();
        _rowCount = rows.length.clamp(1, SheetsWorkbookLimits.maxRows);
        _columnCount = columns.clamp(1, SheetsWorkbookLimits.maxColumns);
        _selectedCell = null;
        _viewColumnIndex = null;
        _filterQuery = null;
        _sortAscending = true;
        _formulaBarController.clear();
      });
      await _saveWorkbook();
      if (!_saved) {
        throw StateError('CSV data could not be saved. The previous workbook backup was preserved.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(backupKey == null
            ? _t('CSV Import সফল হয়েছে।', 'CSV imported successfully.')
            : _t('CSV Import সফল। আগের Workbook Backup: $backupKey', 'CSV imported. Previous workbook backup: $backupKey'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('CSV Import করা যায়নি: ', 'CSV import failed: ') + error.toString())),
      );
    }
  }

  Future<void> _exportCsv() async {
    try {
      var lastRow = 0;
      var lastColumn = 0;
      var hasCells = false;
      for (final key in _cells.keys) {
        final match = RegExp(r'^([A-Z]+)([1-9]\d*)').firstMatch(key.toUpperCase());
        if (match == null || match.end != key.length) continue;
        hasCells = true;
        final row = int.parse(match.group(2)!) - 1;
        var column = 0;
        for (final rune in match.group(1)!.runes) {
          column = column * 26 + rune - 64;
        }
        if (row > lastRow) lastRow = row;
        if (column - 1 > lastColumn) lastColumn = column - 1;
      }
      final rowCount = hasCells ? lastRow + 1 : 1;
      final columnCount = hasCells ? lastColumn + 1 : 1;
      SheetsWorkbookLimits.validate(rowCount, columnCount);
      final values = List<List<String>>.generate(
        rowCount,
        (row) => List<String>.generate(
          columnCount,
          (column) {
            final key = _cellKey(row, column);
            final raw = _cells[key] ?? '';
            // CSV exports values, not executable spreadsheet formulas.
            return raw.startsWith('=') ? _displayValue(key) : raw;
          },
        ),
      );
      final bytes = Uint8List.fromList(utf8.encode(SheetsCsvCodec.encode(values)));
      final safeName = _sheetName.trim().isEmpty ? 'OFFYNEXBD-Sheet' : _sheetName.trim();
      final saved = await FilePicker.saveFile(
        fileName: '${safeName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.csv',
        bytes: bytes,
        mimeType: 'text/csv',
        dialogTitle: _t('CSV ফাইল সংরক্ষণ', 'Save CSV file'),
      );
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('CSV Export সম্পন্ন হয়েছে।', 'CSV export completed.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('CSV Export করা যায়নি: ', 'CSV export failed: ') + error.toString())),
      );
    }
  }

  SheetsWorksheet _worksheetFromExcel(String name, xlsx.Sheet source, int index) {
    SheetsWorkbookLimits.validate(source.maxRows, source.maxColumns);
    final cells = <String, String>{};
    final styles = <String, Map<String, dynamic>>{};
    for (final row in source.rows) {
      for (final cell in row) {
        if (cell == null) continue;
        final key = _cellKey(cell.rowIndex, cell.columnIndex);
        if (cell.value != null) {
          final dynamic value = cell.value;
          final text = value is xlsx.FormulaCellValue
              ? '=${value.formula.toString().replaceFirst(RegExp(r'^='), '')}'
              : value.toString();
          if (text.isNotEmpty) cells[key] = text;
        }
        final importedStyle = cell.cellStyle;
        if (importedStyle == null) continue;
        final style = <String, dynamic>{};
        if (importedStyle.isBold) style['bold'] = true;
        if (importedStyle.isItalic) style['italic'] = true;
        if (importedStyle.underline != xlsx.Underline.None) style['underline'] = true;
        if (importedStyle.fontSize != null) style['fontSize'] = importedStyle.fontSize;
        final format = importedStyle.numberFormat.formatCode;
        if (format.contains('%')) {
          style['numberFormat'] = 'percent';
        } else if (format.contains('৳') || format.contains(r'\$')) {
          style['numberFormat'] = 'currency';
        } else if (format.contains('0.00')) {
          style['numberFormat'] = 'number';
        }
        final font = importedStyle.fontColor.colorHex;
        if (font != 'none' && font.toUpperCase() != 'FF000000') {
          style['fontColor'] = font.length == 8 ? font.substring(2) : font;
        }
        final fill = importedStyle.backgroundColor.colorHex;
        if (fill != 'none') {
          style['fillColor'] = fill.length == 8 ? fill.substring(2) : fill;
        }
        switch (importedStyle.verticalAlignment) {
          case xlsx.VerticalAlign.Top: style['verticalAlign'] = 'top'; break;
          case xlsx.VerticalAlign.Center: style['verticalAlign'] = 'center'; break;
          default: style['verticalAlign'] = 'bottom'; break;
        }
        if (importedStyle.wrap == xlsx.TextWrapping.WrapText) style['wrapText'] = true;
        switch (importedStyle.horizontalAlignment) {
          case xlsx.HorizontalAlign.Center: style['align'] = 'center'; break;
          case xlsx.HorizontalAlign.Right: style['align'] = 'right'; break;
          default: style['align'] = 'left'; break;
        }
        if (importedStyle.leftBorder.borderStyle != null ||
            importedStyle.rightBorder.borderStyle != null ||
            importedStyle.topBorder.borderStyle != null ||
            importedStyle.bottomBorder.borderStyle != null) {
          style['border'] = true;
        }
        if (style.isNotEmpty) styles[key] = style;
      }
    }
    final importedValidation = SheetsXlsxValidationCodec.read(
      source,
      baseRows: source.maxRows.clamp(1, SheetsWorkbookLimits.maxRows).toInt(),
      baseColumns: source.maxColumns.clamp(1, SheetsWorkbookLimits.maxColumns).toInt(),
    );
    SheetsWorkbookLimits.validate(
      importedValidation.rows,
      importedValidation.columns,
    );
    return SheetsWorksheet(
      id: 'import-$index-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      rows: importedValidation.rows,
      columns: importedValidation.columns,
      cells: cells,
      styles: styles,
      validations: importedValidation.validations,
    );
  }

  Future<void> _importWorkbook() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      SheetsWorkbookLimits.validateImportBytes(bytes.length);
      final sourceWorkbook = xlsx.Excel.decodeBytes(bytes);
      final names = sourceWorkbook.tables.keys.toList(growable: false);
      if (names.isEmpty) throw const FormatException('Workbook has no worksheets.');
      if (names.length > SheetsWorkbookCodec.maxWorksheets) {
        throw const FormatException('Workbook contains more than 100 worksheets.');
      }
      final imported = <SheetsWorksheet>[];
      for (var i = 0; i < names.length; i++) {
        final source = sourceWorkbook.tables[names[i]];
        if (source == null) throw FormatException('Could not read worksheet ${names[i]}.');
        imported.add(_worksheetFromExcel(names[i], source, i));
      }
      final totalCells = imported.fold<int>(0, (total, sheet) => total + sheet.cells.length);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('সব Worksheet Import করবেন?', 'Import all worksheets?')),
          content: Text(_t(
            '${imported.length}টি Worksheet এবং $totalCellsটি Cell বর্তমান Workbook-এর জায়গায় আসবে। আগের Workbook-এর Backup রাখা হবে।',
            '${imported.length} worksheets and $totalCells cells will replace the current workbook. A backup will be kept.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t('বাতিল', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t('সব Import', 'Import all'))),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _saveQueue;
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final oldRaw = prefs.getString(_sheetStorageKey);
      final backupKey = await SheetsImportSafety.preserveCurrentWorkbook(prefs, oldRaw);
      if (!mounted) return;
      setState(() {
        _workbook = SheetsWorkbook(activeSheetId: imported.first.id, sheets: imported);
        _selectedCell = null;
        _viewColumnIndex = null;
        _filterQuery = null;
        _sortAscending = true;
        _formulaBarController.clear();
      });
      await _saveWorkbook();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(backupKey == null
            ? _t('সব Worksheet Import সফল হয়েছে।', 'All worksheets imported successfully.')
            : _t('Import সফল। আগের Workbook-এর Backup: $backupKey', 'Import successful. Previous workbook backup: $backupKey'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Import করা যায়নি: ', 'Import failed: ') + error.toString())),
      );
    }
  }

  void _writeWorksheetToExcel(xlsx.Excel workbook, SheetsWorksheet source) {
    final sheet = workbook[source.name];
    final engine = SheetsFormulaEngine(source.cells);
    for (final key in {...source.cells.keys, ...source.styles.keys}) {
      final value = source.cells[key] ?? '';
      final cell = sheet.cell(xlsx.CellIndex.indexByString(key.toUpperCase()));
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
      final resolvedValue = value.startsWith('=')
          ? (engine.evaluateCell(key)?.toString() ?? '#ERROR')
          : value;
      final style = <String, dynamic>{
        ...?source.styles[key],
        ...SheetsAnalytics.conditionalStyleForCell(key, resolvedValue, source.conditionalFormats),
      };
      if (style.isEmpty) continue;
      final alignment = switch (style['align']) {
        'center' => xlsx.HorizontalAlign.Center,
        'right' => xlsx.HorizontalAlign.Right,
        _ => xlsx.HorizontalAlign.Left,
      };
      final format = switch (style['numberFormat']) {
        'number' => xlsx.CustomNumericNumFormat(formatCode: '#,##0.00'),
        'currency' => xlsx.CustomNumericNumFormat(formatCode: '৳#,##0.00'),
        'percent' => xlsx.CustomNumericNumFormat(formatCode: '0.00%'),
        _ => xlsx.NumFormat.standard_0,
      };
      final fill = style['fillColor'] as String?;
      final font = style['fontColor'] as String?;
      final border = style['border'] == true;
      cell.cellStyle = xlsx.CellStyle(
        bold: style['bold'] == true,
        italic: style['italic'] == true,
        underline: style['underline'] == true ? xlsx.Underline.Single : xlsx.Underline.None,
        fontSize: (style['fontSize'] as num?)?.toInt(),
        fontColorHex: font == null ? xlsx.ExcelColor.black : xlsx.ExcelColor.fromHexString('#$font'),
        backgroundColorHex: fill == null ? xlsx.ExcelColor.none : xlsx.ExcelColor.fromHexString('#$fill'),
        horizontalAlign: alignment,
        verticalAlign: switch (style['verticalAlign']) {
          'top' => xlsx.VerticalAlign.Top,
          'center' => xlsx.VerticalAlign.Center,
          _ => xlsx.VerticalAlign.Bottom,
        },
        textWrapping: style['wrapText'] == true ? xlsx.TextWrapping.WrapText : xlsx.TextWrapping.Clip,
        numberFormat: format,
        leftBorder: border ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
        rightBorder: border ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
        topBorder: border ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
        bottomBorder: border ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
      );
    }
    SheetsXlsxValidationCodec.write(sheet, source.validations);
  }

  Future<void> _exportWorkbook() async {
    try {
      final workbook = xlsx.Excel.createExcel();
      final firstName = _workbook.sheets.first.name;
      final defaultName = workbook.getDefaultSheet();
      if (defaultName != null && defaultName != firstName) workbook.rename(defaultName, firstName);
      for (final source in _workbook.sheets) {
        _writeWorksheetToExcel(workbook, source);
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('XLSX encoding failed');
      final safeName = _sheetName.trim().isEmpty ? 'OFFYNEXBD-Workbook' : _sheetName.trim();
      final fileName = '${safeName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.xlsx';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        dialogTitle: _t('XLSX ফাইল সংরক্ষণ', 'Save XLSX workbook'),
      );
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('সব Worksheet-সহ XLSX Export সম্পন্ন হয়েছে।', 'XLSX export completed with all worksheets.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Export করা যায়নি: ', 'Export failed: ') + error.toString())),
      );
    }
  }

  Future<Uint8List> _buildSheetPdf() async {
    var lastRow = 0;
    var lastColumn = 0;
    for (final key in {..._cells.keys, ..._cellStyles.keys}) {
      final match = RegExp(r'^([A-Z]+)([1-9]\d*)$').firstMatch(key.toUpperCase());
      if (match == null) continue;
      final row = int.parse(match.group(2)!) - 1;
      var column = 0;
      for (final rune in match.group(1)!.runes) { column = column * 26 + rune - 64; }
      if (row > lastRow) lastRow = row;
      if (column - 1 > lastColumn) lastColumn = column - 1;
    }
    final rows = _cells.isEmpty && _cellStyles.isEmpty ? 1 : lastRow + 1;
    final columns = _cells.isEmpty && _cellStyles.isEmpty ? 1 : lastColumn + 1;
    final values = List<List<String>>.generate(rows, (row) => List<String>.generate(columns, (column) => _displayValue(_cellKey(row, column))));
    final styles = List<List<Map<String, dynamic>>>.generate(rows, (row) => List<Map<String, dynamic>>.generate(columns, (column) => _styleFor(_cellKey(row, column))));
    final sans = await rootBundle.load('assets/fonts/NotoSansBengali.ttf');
    final serif = await rootBundle.load('assets/fonts/NotoSerifBengali.ttf');
    final latin = await rootBundle.load('assets/fonts/NotoSans.ttf');
    return SheetsPdfExportService.build(sheetName: _sheetName, values: values, styles: styles, sansFontData: sans, serifFontData: serif, latinFontData: latin, showGridlines: _showGridlines, pageFormat: PdfPageFormat.a4.landscape);
  }

  Future<void> _exportPdf() async {
    try {
      final bytes = await _buildSheetPdf();
      final safeName = _sheetName.trim().isEmpty ? 'OFFYNEXBD-Sheet' : _sheetName.trim();
      final saved = await FilePicker.saveFile(fileName: '${safeName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf', bytes: bytes, mimeType: 'application/pdf', dialogTitle: _t('PDF সংরক্ষণ', 'Save sheet as PDF'));
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('PDF তৈরি হয়েছে।', 'PDF created successfully.'))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('PDF তৈরি করা যায়নি: ', 'PDF export failed: ') + error.toString())));
    }
  }

  Future<void> _printSheet() async {
    try {
      await Printing.layoutPdf(name: '${_sheetName.isEmpty ? 'OFFYNEXBD-Sheet' : _sheetName}.pdf', format: PdfPageFormat.a4.landscape, onLayout: (_) => _buildSheetPdf());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('প্রিন্ট তৈরি করা যায়নি: ', 'Print failed: ') + error.toString())));
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
      _cellStyles.clear();
      _activeWorksheet.validations.clear();
      _activeWorksheet.conditionalFormats.clear();
      _activeWorksheet.charts.clear();
      _activeWorksheet.pivotConfig = null;
      _selectedCell = null;
      _viewColumnIndex = null;
      _filterQuery = null;
      _sortAscending = true;
      _formulaBarController.clear();
    });
    await _saveWorkbook();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _formulaBarController.dispose();
    super.dispose();
  }

  void _selectCell(String key) {
    setState(() {
      _selectedCell = key;
      _formulaBarController.text = _cells[key] ?? '';
      _formulaBarController.selection = TextSelection.collapsed(
        offset: _formulaBarController.text.length,
      );
    });
  }

  Future<void> _commitFormulaBar() async {
    final key = _selectedCell;
    if (key == null) return;
    final value = _formulaBarController.text;
    await _writeCellValue(key, value);
  }

  Future<void> _clearSelectedCell() async {
    final key = _selectedCell;
    if (key == null) return;
    setState(() {
      _cells.remove(key);
      _formulaBarController.clear();
    });
    await _saveWorkbook();
  }

  Future<void> _clearSelectedCellFormats() async {
    final key = _selectedCell;
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('আগে একটি Cell নির্বাচন করুন।', 'Select a cell first.'))),
      );
      return;
    }
    if (!_cellStyles.containsKey(key)) return;
    setState(() => _cellStyles.remove(key));
    await _saveWorkbook();
  }

  Future<void> _insertFunction(String function) async {
    final key = _selectedCell;
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('আগে একটি Cell নির্বাচন করুন।', 'Select a cell first.'))),
      );
      return;
    }
    if (function == 'PI') {
      await _writeCellValue(key, '=PI()');
      return;
    }
    const examples = <String, String>{
      'SUM': 'A1:A5',
      'AVERAGE': 'A1:A5',
      'COUNT': 'A1:A5',
      'MIN': 'A1:A5',
      'MAX': 'A1:A5',
      'PRODUCT': 'A1:A5',
      'ABS': 'A1',
      'ROUND': 'A1,2',
      'ROUNDUP': 'A1,2',
      'ROUNDDOWN': 'A1,2',
      'LARGE': 'A1:A5,1',
      'SMALL': 'A1:A5,1',
      'MEDIAN': 'A1:A5',
      'CEILING': 'A1,1',
      'FLOOR': 'A1,1',
      'PI': '',
      'EXP': 'A1',
      'LN': 'A1',
      'LOG': 'A1',
      'LOG10': 'A1',
      'SIN': 'A1',
      'COS': 'A1',
      'TAN': 'A1',
      'ASIN': 'A1',
      'ACOS': 'A1',
      'ATAN': 'A1',
      'SQRT': 'A1',
      'POWER': 'A1,2',
      'MOD': 'A1,2',
      'INT': 'A1',
      'SIGN': 'A1',
      'IF': 'A1>0,1,0',
      'AND': 'A1>0,B1>0',
      'OR': 'A1>0,B1>0',
      'NOT': 'A1=0',
    };
    final example = examples[function] ?? 'A1';
    final controller = TextEditingController(text: example);
    final range = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$function(…)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _t('Argument / Cell / Range', 'Arguments, cells or ranges'),
            hintText: example,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_t('যোগ করুন', 'Insert')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (range == null || range.isEmpty || !mounted) return;
    final formula = '=$function($range)';
    await _writeCellValue(key, formula);
  }

  Widget _ribbonCommand(String label, IconData icon, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: OFFYNEXTheme.ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: OFFYNEXTheme.border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }

  Widget _buildRibbon() {
    const tabs = ['File', 'Home', 'Insert', 'Formulas', 'Data', 'View'];
    final labels = _bn ? ['ফাইল', 'হোম', 'ইনসার্ট', 'ফর্মুলা', 'ডেটা', 'ভিউ'] : tabs;
    final commands = <Widget>[];
    switch (_activeRibbonTab) {
      case 0:
        commands.addAll([
          _ribbonCommand('Import XLSX', Icons.file_open, _importWorkbook),
          _ribbonCommand('Export XLSX', Icons.file_download, _exportWorkbook),
          _ribbonCommand('Import CSV', Icons.table_view, _importCsv),
          _ribbonCommand('Export CSV', Icons.file_download_outlined, _exportCsv),
          _ribbonCommand(_t('PDF সংরক্ষণ', 'Save PDF'), Icons.picture_as_pdf, _exportPdf),
          _ribbonCommand(_t('প্রিন্ট', 'Print'), Icons.print, _printSheet),
          _ribbonCommand(_t('নাম পরিবর্তন', 'Rename sheet'), Icons.drive_file_rename_outline, _renameSheet),
          _ribbonCommand(_t('শিট খালি', 'Clear sheet'), Icons.delete_outline, _clearSheet),
        ]);
        break;
      case 1:
        commands.addAll([
          _ribbonCommand(_t('খুঁজুন ও পরিবর্তন', 'Find & Replace'), Icons.find_replace, _findAndReplace),
          _ribbonCommand(_t('শর্তসাপেক্ষ Formatting', 'Conditional Formatting'), Icons.format_color_fill, _setConditionalFormatting),
          _ribbonCommand(_t('Formatting নিয়ম সরান', 'Clear formatting rules'), Icons.format_clear, _clearConditionalFormatting),
          _ribbonCommand(_t('সেল সম্পাদনা', 'Edit cell'), Icons.edit, () {
            final key = _selectedCell;
            if (key == null) return;
            final match = RegExp(r'^([A-Z]+)([1-9]\d*)$').firstMatch(key);
            if (match == null) return;
            final row = int.parse(match.group(2)!) - 1;
            var column = 0;
            for (final rune in match.group(1)!.runes) {
              column = column * 26 + rune - 64;
            }
            _editCell(row, column - 1);
          }),
          _ribbonCommand('Bold', Icons.format_bold, () => _toggleCellStyle('bold')),
          _ribbonCommand(_t('ফরম্যাট মুছুন', 'Clear Formats'), Icons.format_clear, _clearSelectedCellFormats),
          _ribbonCommand('Italic', Icons.format_italic, () => _toggleCellStyle('italic')),
          _ribbonCommand('Underline', Icons.format_underline, () => _toggleCellStyle('underline')),
          _ribbonCommand('Font Size', Icons.format_size, _chooseFontSize),
          _ribbonCommand('Font Color', Icons.format_color_text, () => _chooseCellColor(background: false)),
          _ribbonCommand('Fill Color', Icons.format_color_fill, () => _chooseCellColor(background: true)),
          _ribbonCommand('Align Left', Icons.format_align_left, () => _applyCellStyle('align', 'left')),
          _ribbonCommand('Center', Icons.format_align_center, () => _applyCellStyle('align', 'center')),
          _ribbonCommand('Align Right', Icons.format_align_right, () => _applyCellStyle('align', 'right')),
          _ribbonCommand('Wrap Text', Icons.wrap_text, _toggleWrapText),
          _ribbonCommand('Top Align', Icons.vertical_align_top, () => _applyCellStyle('verticalAlign', 'top')),
          _ribbonCommand('Middle Align', Icons.vertical_align_center, () => _applyCellStyle('verticalAlign', 'center')),
          _ribbonCommand('Bottom Align', Icons.vertical_align_bottom, () => _applyCellStyle('verticalAlign', 'bottom')),
          _ribbonCommand('Number Format', Icons.numbers, _chooseNumberFormat),
          _ribbonCommand('Borders', Icons.border_all, _toggleCellBorder),
          _ribbonCommand(_t('সেল মুছুন', 'Clear cell'), Icons.backspace_outlined, _clearSelectedCell),
          _ribbonCommand(_t('১০টি Row', 'Add 10 rows'), Icons.table_rows, _addRows),
          _ribbonCommand(_t('২টি Column', 'Add 2 columns'), Icons.view_column, _addColumns),
          _ribbonCommand(_t('শেষ Row বাদ', 'Remove last row'), Icons.remove, _removeLastRow),
          _ribbonCommand(_t('শেষ Column বাদ', 'Remove last column'), Icons.remove, _removeLastColumn),
        ]);
        break;
      case 2:
        commands.addAll([
          _ribbonCommand(_t('Row যোগ', 'Add rows'), Icons.add, _addRows),
          _ribbonCommand(_t('Column যোগ', 'Add columns'), Icons.view_column, _addColumns),
          _ribbonCommand(_t('শিটের নাম', 'Sheet name'), Icons.drive_file_rename_outline, _renameSheet),
          _ribbonCommand(_t('Chart তৈরি', 'Create chart'), Icons.insert_chart_outlined, _createChart),
        ]);
        break;
      case 3:
        for (final function in [
          'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX', 'PRODUCT', 'MEDIAN',
          'LARGE', 'SMALL', 'ABS', 'ROUND', 'ROUNDUP', 'ROUNDDOWN',
          'CEILING', 'FLOOR', 'SQRT', 'POWER', 'MOD', 'INT', 'SIGN',
          'PI', 'EXP', 'LN', 'LOG', 'LOG10', 'SIN', 'COS', 'TAN',
          'ASIN', 'ACOS', 'ATAN', 'IF', 'AND', 'OR', 'NOT',
        ]) {
          commands.add(_ribbonCommand(function, Icons.functions, () => _insertFunction(function)));
        }
        break;
      case 4:
        commands.addAll([
          _ribbonCommand(_t('Dropdown Validation', 'Dropdown Validation'), Icons.arrow_drop_down_circle_outlined, _setDataValidation),
          _ribbonCommand(_t('Pivot Table তৈরি', 'Create Pivot Table'), Icons.table_chart_outlined, _createPivotTable),
          _ribbonCommand(_t('Pivot Refresh', 'Refresh Pivot'), Icons.refresh, _refreshPivotTable),
          _ribbonCommand(_t('শর্তসাপেক্ষ Formatting', 'Conditional Formatting'), Icons.format_color_fill, _setConditionalFormatting),
          _ribbonCommand('Import XLSX', Icons.file_open, _importWorkbook),
          _ribbonCommand('Export XLSX', Icons.file_download, _exportWorkbook),
          _ribbonCommand('Import CSV', Icons.table_view, _importCsv),
          _ribbonCommand('Export CSV', Icons.file_download_outlined, _exportCsv),
          _ribbonCommand(_t('A→Z সাজান', 'Sort A→Z'), Icons.sort_by_alpha, _sortBySelectedColumn),
          _ribbonCommand(_t('Filter', 'Filter'), Icons.filter_alt, _filterBySelectedColumn),
          _ribbonCommand(_t('Sort/Filter বন্ধ', 'Clear sort/filter'), Icons.filter_alt_off, _clearSortAndFilter),
          _ribbonCommand(_t('সব মুছুন', 'Clear all'), Icons.delete_outline, _clearSheet),
        ]);
        break;
      case 5:
        commands.add(_ribbonCommand(
          _activeWorksheet.freezeTopRow
              ? _t('প্রথম Row ছাড়ুন', 'Unfreeze Top Row')
              : _t('প্রথম Row স্থির', 'Freeze Top Row'),
          _activeWorksheet.freezeTopRow ? Icons.vertical_align_bottom : Icons.vertical_align_top,
          _toggleFreezeTopRow,
        ));
        commands.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_t('Gridlines', 'Gridlines')),
            Switch(value: _showGridlines, onChanged: (value) => setState(() => _showGridlines = value)),
            const SizedBox(width: 10),
            const Text('Zoom'),
            SizedBox(
              width: 140,
              child: Slider(
                value: _zoom,
                min: 0.75,
                max: 1.5,
                divisions: 15,
                onChanged: (value) => setState(() => _zoom = value),
              ),
            ),
          ]),
        ));
        break;
    }
    return Material(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OFFYNEXTheme.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: List.generate(tabs.length, (index) {
            final selected = _activeRibbonTab == index;
            return InkWell(
              onTap: () => setState(() => _activeRibbonTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? OFFYNEXTheme.blueSoft : Colors.white,
                  border: Border(bottom: BorderSide(
                    color: selected ? OFFYNEXTheme.blue : Colors.transparent,
                    width: 3,
                  )),
                ),
                child: Text(labels[index], style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? OFFYNEXTheme.blue : OFFYNEXTheme.muted,
                )),
              ),
            );
          })),
        ),
        const Divider(height: 1, color: OFFYNEXTheme.border),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: commands)),
        const Divider(height: 1, color: Color(0xFFE5EAF1)),
        ]),
      ),
    );
  }

  Widget _buildFormulaBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      child: Row(children: [
        Container(
          width: 62,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: OFFYNEXTheme.canvas,
            border: Border.all(color: OFFYNEXTheme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_selectedCell ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        const Text('fx', style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _formulaBarController,
          enabled: _selectedCell != null,
          onSubmitted: (_) => _commitFormulaBar(),
          minLines: 1,
          maxLines: 1,
          decoration: InputDecoration(
            hintText: _t('Cell নির্বাচন করে মান বা Formula লিখুন', 'Select a cell and enter a value or formula'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OFFYNEXTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: OFFYNEXTheme.border)),
          ),
        )),
        if (_selectedCell != null && _activeWorksheet.validations.containsKey(_selectedCell))
          IconButton(
            key: const ValueKey('sheets-open-cell-dropdown'),
            tooltip: _t('Dropdown থেকে নির্বাচন', 'Choose from dropdown'),
            onPressed: _chooseValidatedValue,
            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
          ),
        IconButton(
          tooltip: _t('প্রয়োগ করুন', 'Apply'),
          onPressed: _selectedCell == null ? null : _commitFormulaBar,
          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF159B68)),
        ),
      ]),
    );
  }

  double get _gridWidth => 42 + (_columnCount * 104 * _zoom) + 8;

  Widget _buildGridHeader() {
    return Container(
      height: 38 * _zoom,
      color: OFFYNEXTheme.blueSoft,
      child: Row(children: [
        SizedBox(
          width: 42,
          child: Center(child: Text('#', style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
        for (var column = 0; column < _columnCount; column++)
          Container(
            width: 104 * _zoom,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFD8E0EA), width: 0.5)),
            ),
            child: Text(
              _columnName(column),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ]),
    );
  }

  Widget _buildGridCell(int row, int column) {
    final key = _cellKey(row, column);
    final rawValue = _cells[key] ?? '';
    final resolvedValue = rawValue.startsWith('=') ? (_numericValue(key)?.toString() ?? '#ERROR') : rawValue;
    final style = <String, dynamic>{
      ...?_cellStyles[key],
      ...SheetsAnalytics.conditionalStyleForCell(key, resolvedValue, _activeWorksheet.conditionalFormats),
    };
    final wrapText = style['wrapText'] == true;
    return SizedBox(
      width: 104 * _zoom,
      child: InkWell(
        key: ValueKey('sheet-cell-$key'),
        onTap: () => _selectCell(key),
        onLongPress: () => _editCell(row, column),
        child: Container(
          alignment: _cellAlignment(key, style),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _selectedCell == key
                ? OFFYNEXTheme.blueSoft
                : _colorFromHex(style['fillColor'] as String?, Colors.white),
            border: style['border'] == true
                ? Border.all(color: const Color(0xFF596579), width: 1.2)
                : _showGridlines
                    ? Border.all(color: OFFYNEXTheme.border, width: 0.6)
                    : Border.all(color: Colors.transparent, width: 0.5),
          ),
          child: Text(
            _displayValue(key),
            maxLines: wrapText ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: _cellTextAlign(key, style),
            style: _cellTextStyle(key, style),
          ),
        ),
      ),
    );
  }

  Widget _buildGridRow(int row, {bool frozen = false}) {
    return SizedBox(
      key: frozen ? const ValueKey('sheets-frozen-top-row') : ValueKey('sheets-grid-row-$row'),
      height: 56 * _zoom,
      child: Row(children: [
        SizedBox(
          width: 42,
          child: Center(
            child: Text(
              '${row + 1}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ),
        for (var column = 0; column < _columnCount; column++)
          _buildGridCell(row, column),
      ]),
    );
  }

  Widget _buildGrid(List<int> visibleRows) {
    final frozenRow = _activeWorksheet.freezeTopRow ? 0 : null;
    final scrollingRows = frozenRow == null
        ? visibleRows
        : visibleRows.where((row) => row != frozenRow).toList(growable: false);
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _gridWidth,
          child: Column(children: [
            _buildGridHeader(),
            if (frozenRow != null) _buildGridRow(frozenRow, frozen: true),
            Expanded(
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                child: ListView.builder(
                  key: const ValueKey('sheets-grid-vertical'),
                  controller: _verticalController,
                  itemCount: scrollingRows.length,
                  itemExtent: 56 * _zoom,
                  itemBuilder: (context, index) => _buildGridRow(scrollingRows[index]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_workbookDataBlocked) {
      return Scaffold(
        backgroundColor: OFFYNEXTheme.canvas,
        appBar: AppBar(
          title: Text(_t('OFFYNEX শিটস', 'OFFYNEX Sheets')),
          backgroundColor: OFFYNEXTheme.canvas,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _workbookRecoveryMessage ?? _t(
                'Workbook ডেটা ক্ষতিগ্রস্ত। মূল ডেটা সুরক্ষার জন্য সম্পাদনা বন্ধ রাখা হয়েছে।',
                'Workbook data is damaged. Editing is blocked to protect the original data.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final visibleRows = _buildVisibleRowIndices();
    return Scaffold(
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        title: Text(_t('OFFYNEX শিটস', 'OFFYNEX Sheets'), style: const TextStyle(color: OFFYNEXTheme.ink, fontWeight: FontWeight.w800)),
        backgroundColor: OFFYNEXTheme.canvas,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _t('সংরক্ষণ', 'Save'),
            onPressed: _saveWorkbook,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildRibbon(),
                _buildFormulaBar(),
                Container(
                  width: double.infinity,
                  color: OFFYNEXTheme.canvas,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(children: [
                    Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 16,
                        color: _saved ? OFFYNEXTheme.teal : Colors.orange),
                    const SizedBox(width: 6),
                    Text(_saved ? _t('সংরক্ষিত', 'Saved') : _t('সংরক্ষণ হচ্ছে', 'Saving'),
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(
                      _filterQuery == null
                          ? '$_rowCount × $_columnCount'
                          : '${visibleRows.length}/$_rowCount rows',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ]),
                ),
                Expanded(child: _buildGrid(visibleRows)),
                _buildChartGallery(),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OFFYNEXTheme.border))),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final worksheet in _workbook.sheets)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: InkWell(
                                key: ValueKey('worksheet-tab-${worksheet.id}'),
                                onTap: () => _selectWorksheet(worksheet.id),
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: worksheet.id == _workbook.activeSheetId
                                        ? OFFYNEXTheme.blueSoft
                                        : OFFYNEXTheme.canvas,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: worksheet.id == _workbook.activeSheetId
                                            ? OFFYNEXTheme.blue
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    worksheet.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: worksheet.id == _workbook.activeSheetId
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('add-worksheet'),
                      tooltip: _t('নতুন Worksheet', 'Add worksheet'),
                      onPressed: _addWorksheet,
                      icon: const Icon(Icons.add, color: OFFYNEXTheme.blue),
                    ),
                    IconButton(
                      key: const ValueKey('rename-worksheet'),
                      tooltip: _t('নাম পরিবর্তন', 'Rename worksheet'),
                      onPressed: _renameSheet,
                      icon: const Icon(Icons.drive_file_rename_outline),
                    ),
                    IconButton(
                      key: const ValueKey('delete-worksheet'),
                      tooltip: _t('Worksheet মুছুন', 'Delete worksheet'),
                      onPressed: _workbook.sheets.length <= 1 ? null : _deleteWorksheet,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }

}

class _CellEditDialog extends StatefulWidget {
  const _CellEditDialog({
    required this.cellKey,
    required this.initialValue,
    required this.title,
    required this.valueLabel,
    required this.cancelLabel,
    required this.clearLabel,
    required this.saveLabel,
  });

  final String cellKey;
  final String initialValue;
  final String title;
  final String valueLabel;
  final String cancelLabel;
  final String clearLabel;
  final String saveLabel;

  @override
  State<_CellEditDialog> createState() => _CellEditDialogState();
}

class _CellEditDialogState extends State<_CellEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.title} — ${widget.cellKey}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: widget.valueLabel,
          hintText: '=SUM(A1:A5)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text(widget.clearLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
