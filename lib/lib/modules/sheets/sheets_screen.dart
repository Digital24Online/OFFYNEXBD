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
  final Map<String, Map<String, dynamic>> _cellStyles = {};
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _loading = true;
  bool _saved = true;
  Future<void> _saveQueue = Future<void>.value();
  int _rowCount = _initialRows;
  int _columnCount = _initialColumns;
  String _sheetName = 'Sheet1';
  String? _selectedCell;

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
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final storedCells = data['cells'];
        if (storedCells is Map) {
          _cells.addAll(storedCells.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ));
        }
        final storedStyles = data['styles'];
        if (storedStyles is Map) {
          for (final entry in storedStyles.entries) {
            if (entry.value is Map) {
              _cellStyles[entry.key.toString()] = Map<String, dynamic>.from(entry.value as Map);
            }
          }
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
      'styles': _cellStyles,
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
            ? numeric.toInt().toString()
            : numeric.toString();
  }

  Map<String, dynamic> _styleFor(String key) =>
      Map<String, dynamic>.from(_cellStyles[key] ?? const {});

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return fallback;
    return Color(int.parse('FF$hex', radix: 16));
  }

  TextStyle _cellTextStyle(String key) {
    final style = _cellStyles[key] ?? const <String, dynamic>{};
    return TextStyle(
      fontSize: ((style['fontSize'] as num?)?.toDouble() ?? 13) * _zoom,
      fontWeight: style['bold'] == true ? FontWeight.bold : FontWeight.normal,
      fontStyle: style['italic'] == true ? FontStyle.italic : FontStyle.normal,
      decoration: style['underline'] == true ? TextDecoration.underline : TextDecoration.none,
      color: _colorFromHex(style['fontColor'] as String?, Colors.black87),
    );
  }

  Alignment _cellAlignment(String key) {
    final style = _cellStyles[key] ?? const <String, dynamic>{};
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

  TextAlign _cellTextAlign(String key) {
    switch (_cellStyles[key]?['align']) {
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
    if (result.trim().isEmpty) {
      _cells.remove(key);
    } else {
      _cells[key] = result.trim();
    }
    setState(() {
      _selectedCell = key;
      _formulaBarController.text = _cells[key] ?? '';
    });
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
    final formulaPattern = RegExp(
      r'(?<![A-Z0-9_])[A-Z]+' +
          rowNumber.toString() +
          r'(?!\\d)(?!\\s*\\()',
    );
    final hasData = _cells.entries.any((entry) =>
        cellPattern.hasMatch(entry.key.toUpperCase()) && entry.value.isNotEmpty);
    final hasFormatting = _cellStyles.keys.any((key) => cellPattern.hasMatch(key.toUpperCase()));
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value.toUpperCase()));
    if (hasData || hasFormatting || hasFormulaReference) {
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
    final hasFormulaReference = _cells.values.any((value) =>
        value.startsWith('=') && formulaPattern.hasMatch(value));
    if (hasData || hasFormatting || hasFormulaReference) {
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
      final importedStyles = <String, Map<String, dynamic>>{};
      for (final row in sheet.rows) {
        for (final cell in row) {
          if (cell == null) continue;
          final key = _cellKey(cell.rowIndex, cell.columnIndex);
          if (cell.value != null) {
            final dynamic cellValue = cell.value;
            final String value = cellValue is xlsx.FormulaCellValue
                ? '=${cellValue.formula.toString().replaceFirst(RegExp(r'^='), '')}'
                : cellValue.toString();
            if (value.isNotEmpty) imported[key] = value;
          }
          final importedStyle = cell.cellStyle;
          if (importedStyle != null) {
            final style = <String, dynamic>{};
            if (importedStyle.isBold) style['bold'] = true;
            if (importedStyle.isItalic) style['italic'] = true;
            if (importedStyle.underline != xlsx.Underline.None) style['underline'] = true;
            if (importedStyle.fontSize != null) style['fontSize'] = importedStyle.fontSize;
            final formatCode = importedStyle.numberFormat.formatCode;
            if (formatCode.contains('%')) {
              style['numberFormat'] = 'percent';
            } else if (formatCode.contains('৳') || formatCode.contains(r'\$')) {
              style['numberFormat'] = 'currency';
            } else if (formatCode.contains('0.00')) {
              style['numberFormat'] = 'number';
            }
            final fontHex = importedStyle.fontColor.colorHex;
            if (fontHex != 'none' && fontHex.toUpperCase() != 'FF000000') {
              style['fontColor'] = fontHex.length == 8 ? fontHex.substring(2) : fontHex;
            }
            final fillHex = importedStyle.backgroundColor.colorHex;
            if (fillHex != 'none') {
              style['fillColor'] = fillHex.length == 8 ? fillHex.substring(2) : fillHex;
            }
            switch (importedStyle.verticalAlignment) {
              case xlsx.VerticalAlign.Top:
                style['verticalAlign'] = 'top';
                break;
              case xlsx.VerticalAlign.Center:
                style['verticalAlign'] = 'center';
                break;
              default:
                style['verticalAlign'] = 'bottom';
                break;
            }
            if (importedStyle.wrap == xlsx.TextWrapping.WrapText) {
              style['wrapText'] = true;
            }
            switch (importedStyle.horizontalAlignment) {
              case xlsx.HorizontalAlign.Center:
                style['align'] = 'center';
                break;
              case xlsx.HorizontalAlign.Right:
                style['align'] = 'right';
                break;
              default:
                style['align'] = 'left';
                break;
            }
            if (importedStyle.leftBorder.borderStyle != null ||
                importedStyle.rightBorder.borderStyle != null ||
                importedStyle.topBorder.borderStyle != null ||
                importedStyle.bottomBorder.borderStyle != null) {
              style['border'] = true;
            }
            if (style.isNotEmpty) importedStyles[key] = style;
          }
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
        _cellStyles..clear()..addAll(importedStyles);
        _rowCount = sheet.maxRows.clamp(1, 1000);
        _columnCount = sheet.maxColumns.clamp(1, 100);
        _sheetName = sheetName;
        _selectedCell = null;
        _formulaBarController.clear();
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
      for (final key in {..._cells.keys, ..._cellStyles.keys}) {
        final value = _cells[key] ?? '';
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
        final style = _cellStyles[key];
        if (style != null && style.isNotEmpty) {
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
          final hasBorder = style['border'] == true;
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
            textWrapping: style['wrapText'] == true
                ? xlsx.TextWrapping.WrapText
                : xlsx.TextWrapping.Clip,
            numberFormat: format,
            leftBorder: hasBorder ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
            rightBorder: hasBorder ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
            topBorder: hasBorder ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
            bottomBorder: hasBorder ? xlsx.Border(borderStyle: xlsx.BorderStyle.Thin) : null,
          );
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
      _selectedCell = null;
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
    final value = _formulaBarController.text.trim();
    setState(() {
      if (value.isEmpty) {
        _cells.remove(key);
      } else {
        _cells[key] = value;
      }
    });
    await _saveWorkbook();
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
      setState(() {
        _cells[key] = '=PI()';
        _formulaBarController.text = '=PI()';
      });
      await _saveWorkbook();
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
    setState(() {
      _cells[key] = formula;
      _formulaBarController.text = formula;
    });
    await _saveWorkbook();
  }

  Widget _ribbonCommand(String label, IconData icon, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF263B55),
          side: const BorderSide(color: Color(0xFFDCE3EC)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
          _ribbonCommand(_t('PDF সংরক্ষণ', 'Save PDF'), Icons.picture_as_pdf, _exportPdf),
          _ribbonCommand(_t('প্রিন্ট', 'Print'), Icons.print, _printSheet),
          _ribbonCommand(_t('নাম পরিবর্তন', 'Rename sheet'), Icons.drive_file_rename_outline, _renameSheet),
          _ribbonCommand(_t('শিট খালি', 'Clear sheet'), Icons.delete_outline, _clearSheet),
        ]);
        break;
      case 1:
        commands.addAll([
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
        ]);
        break;
      case 3:
        for (final function in [
          'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX', 'PRODUCT', 'MEDIAN',
          'LARGE', 'SMALL', 'ABS', 'ROUND', 'ROUNDUP', 'ROUNDDOWN',
          'CEILING', 'FLOOR', 'SQRT', 'POWER', 'MOD', 'INT', 'SIGN',
          'PI', 'EXP', 'LN', 'LOG', 'LOG10', 'SIN', 'COS', 'TAN',
          'ASIN', 'ACOS', 'ATAN',
        ]) {
          commands.add(_ribbonCommand(function, Icons.functions, () => _insertFunction(function)));
        }
        break;
      case 4:
        commands.addAll([
          _ribbonCommand('Import XLSX', Icons.file_open, _importWorkbook),
          _ribbonCommand('Export XLSX', Icons.file_download, _exportWorkbook),
          _ribbonCommand(_t('সব মুছুন', 'Clear all'), Icons.delete_outline, _clearSheet),
        ]);
        break;
      case 5:
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
                  color: selected ? const Color(0xFFEAF2FC) : Colors.white,
                  border: Border(bottom: BorderSide(
                    color: selected ? const Color(0xFF1677E8) : Colors.transparent,
                    width: 3,
                  )),
                ),
                child: Text(labels[index], style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? const Color(0xFF1265C5) : const Color(0xFF34445A),
                )),
              ),
            );
          })),
        ),
        const Divider(height: 1, color: Color(0xFFE5EAF1)),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: commands)),
        const Divider(height: 1, color: Color(0xFFE5EAF1)),
      ]),
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
            color: const Color(0xFFF1F4F8),
            border: Border.all(color: const Color(0xFFDCE3EC)),
            borderRadius: BorderRadius.circular(5),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
          ),
        )),
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
      color: const Color(0xFFE5ECF5),
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
    final style = _cellStyles[key] ?? const <String, dynamic>{};
    final wrapText = style['wrapText'] == true;
    return SizedBox(
      width: 104 * _zoom,
      child: InkWell(
        key: ValueKey('sheet-cell-$key'),
        onTap: () => _selectCell(key),
        onLongPress: () => _editCell(row, column),
        child: Container(
          alignment: _cellAlignment(key),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _selectedCell == key
                ? const Color(0xFFDCEBFF)
                : _colorFromHex(style['fillColor'] as String?, Colors.white),
            border: style['border'] == true
                ? Border.all(color: const Color(0xFF596579), width: 1.2)
                : _showGridlines
                    ? Border.all(color: const Color(0xFFE1E6ED), width: 0.5)
                    : Border.all(color: Colors.transparent, width: 0.5),
          ),
          child: Text(
            _displayValue(key),
            maxLines: wrapText ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: _cellTextAlign(key),
            style: _cellTextStyle(key),
          ),
        ),
      ),
    );
  }

  Widget _buildGridRow(int row) {
    return SizedBox(
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

  Widget _buildGrid() {
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
            Expanded(
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                child: ListView.builder(
                  key: const ValueKey('sheets-grid-vertical'),
                  controller: _verticalController,
                  itemCount: _rowCount,
                  itemExtent: 56 * _zoom,
                  itemBuilder: (context, row) => _buildGridRow(row),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(_t('OFFYNEX শিটস', 'OFFYNEX Sheets')),
        backgroundColor: Colors.white,
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
                  color: const Color(0xFFF7F9FC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(children: [
                    Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 16,
                        color: _saved ? const Color(0xFF159B68) : Colors.orange),
                    const SizedBox(width: 6),
                    Text(_saved ? _t('সংরক্ষিত', 'Saved') : _t('সংরক্ষণ হচ্ছে', 'Saving'),
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text('$_rowCount × $_columnCount',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
                ),
                Expanded(child: _buildGrid()),
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
