import 'package:material_ui/material_ui.dart';

import 'sheets_analytics.dart';

class SheetsConditionalRuleDialog extends StatefulWidget {
  const SheetsConditionalRuleDialog({
    super.key,
    required this.initialRange,
    required this.isBangla,
  });

  final String initialRange;
  final bool isBangla;

  @override
  State<SheetsConditionalRuleDialog> createState() =>
      _SheetsConditionalRuleDialogState();
}

class _SheetsConditionalRuleDialogState
    extends State<SheetsConditionalRuleDialog> {
  late final TextEditingController _range;
  final _value = TextEditingController();
  String _operator = 'greaterThan';
  String _fill = 'D9EAD3';
  String _font = '1B5E20';

  String t(String bn, String en) => widget.isBangla ? bn : en;

  @override
  void initState() {
    super.initState();
    _range = TextEditingController(text: widget.initialRange);
  }

  @override
  void dispose() {
    _range.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const operators = {
      'greaterThan': 'Greater than',
      'greaterOrEqual': 'Greater than or equal',
      'lessThan': 'Less than',
      'lessOrEqual': 'Less than or equal',
      'equal': 'Equal to',
      'notEqual': 'Not equal to',
      'contains': 'Text contains',
      'isEmpty': 'Is empty',
      'isNotEmpty': 'Is not empty',
    };
    const colors = {
      'D9EAD3': 'Green',
      'FCE5CD': 'Orange',
      'F4CCCC': 'Red',
      'CFE2F3': 'Blue',
      'D9D2E9': 'Purple',
      'FFF2CC': 'Yellow',
    };
    return AlertDialog(
      title: Text(t('Conditional Formatting', 'Conditional Formatting')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _range,
            decoration: const InputDecoration(labelText: 'Cell range', hintText: 'A2:A100'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _operator,
            decoration: InputDecoration(labelText: t('শর্ত', 'Condition')),
            items: operators.entries.map((entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            )).toList(),
            onChanged: (value) => setState(() => _operator = value ?? _operator),
          ),
          if (!{'isEmpty', 'isNotEmpty'}.contains(_operator))
            TextField(
              controller: _value,
              decoration: InputDecoration(labelText: t('তুলনার মান', 'Compare value')),
            ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _fill,
            decoration: InputDecoration(labelText: t('Cell রং', 'Cell fill')),
            items: colors.entries.map((entry) => DropdownMenuItem(
              value: entry.key,
              child: Row(children: [
                Container(width: 18, height: 18, color: Color(int.parse('FF${entry.key}', radix: 16))),
                const SizedBox(width: 8),
                Text(entry.value),
              ]),
            )).toList(),
            onChanged: (value) => setState(() => _fill = value ?? _fill),
          ),
          DropdownButtonFormField<String>(
            value: _font,
            decoration: InputDecoration(labelText: t('লেখার রং', 'Font color')),
            items: const {
              '1B5E20': 'Green',
              '9C1C1C': 'Red',
              '0B5394': 'Blue',
              '4A148C': 'Purple',
              '333333': 'Dark',
            }.entries.map((entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            )).toList(),
            onChanged: (value) => setState(() => _font = value ?? _font),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('বাতিল', 'Cancel'))),
        FilledButton(
          onPressed: () {
            try {
              final rule = SheetsAnalytics.createConditionalRule(
                range: _range.text,
                operator: _operator,
                value: _value.text,
                fillColor: _fill,
                fontColor: _font,
              );
              Navigator.pop(context, rule);
            } catch (error) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          },
          child: Text(t('নিয়ম যোগ', 'Add rule')),
        ),
      ],
    );
  }
}

class SheetsChartDialog extends StatefulWidget {
  const SheetsChartDialog({
    super.key,
    required this.initialRange,
    required this.isBangla,
  });

  final String initialRange;
  final bool isBangla;

  @override
  State<SheetsChartDialog> createState() => _SheetsChartDialogState();
}

class _SheetsChartDialogState extends State<SheetsChartDialog> {
  late final TextEditingController _range;
  final _title = TextEditingController();
  String _type = 'bar';

  @override
  void initState() {
    super.initState();
    _range = TextEditingController(text: widget.initialRange);
    _title.text = widget.isBangla ? 'নতুন চার্ট' : 'New chart';
  }

  @override
  void dispose() {
    _range.dispose();
    _title.dispose();
    super.dispose();
  }

  String t(String bn, String en) => widget.isBangla ? bn : en;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('Chart তৈরি করুন', 'Create chart')),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _title, decoration: InputDecoration(labelText: t('শিরোনাম', 'Title'))),
      TextField(controller: _range, decoration: const InputDecoration(labelText: 'Data range', hintText: 'A1:C10')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _type,
        decoration: InputDecoration(labelText: t('Chart ধরন', 'Chart type')),
        items: [
          DropdownMenuItem(value: 'bar', child: Text(t('Bar Chart', 'Bar chart'))),
          DropdownMenuItem(value: 'line', child: Text(t('Line Chart', 'Line chart'))),
        ],
        onChanged: (value) => setState(() => _type = value ?? _type),
      ),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(t('বাতিল', 'Cancel'))),
      FilledButton(
        onPressed: () {
          if (_title.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('শিরোনাম লিখুন।', 'Enter a title.'))));
            return;
          }
          try {
            SheetsAnalytics.parseRange(_range.text);
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'range': _range.text.trim().toUpperCase(),
              'type': _type,
            });
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
          }
        },
        child: Text(t('Chart যোগ', 'Add chart')),
      ),
    ],
  );
}

class SheetsPivotDialog extends StatefulWidget {
  const SheetsPivotDialog({
    super.key,
    required this.initialRange,
    required this.isBangla,
  });

  final String initialRange;
  final bool isBangla;

  @override
  State<SheetsPivotDialog> createState() => _SheetsPivotDialogState();
}

class _SheetsPivotDialogState extends State<SheetsPivotDialog> {
  late final TextEditingController _range;
  final _group = TextEditingController(text: 'A');
  final _value = TextEditingController(text: 'B');
  String _aggregation = 'sum';

  @override
  void initState() {
    super.initState();
    _range = TextEditingController(text: widget.initialRange);
  }

  @override
  void dispose() {
    _range.dispose();
    _group.dispose();
    _value.dispose();
    super.dispose();
  }

  String t(String bn, String en) => widget.isBangla ? bn : en;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('Pivot Table তৈরি', 'Create Pivot Table')),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _range, decoration: const InputDecoration(labelText: 'Source range', hintText: 'A1:C100')),
      Row(children: [
        Expanded(child: TextField(controller: _group, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: t('Group Column', 'Row field')))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _value, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: t('Value Column', 'Value field')))),
      ]),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _aggregation,
        decoration: InputDecoration(labelText: t('হিসাবের ধরন', 'Summarize values by')),
        items: [
          DropdownMenuItem(value: 'sum', child: Text(t('যোগফল', 'Sum'))),
          DropdownMenuItem(value: 'count', child: Text(t('গণনা', 'Count'))),
          DropdownMenuItem(value: 'average', child: Text(t('গড়', 'Average'))),
          DropdownMenuItem(value: 'min', child: const Text('Minimum')),
          DropdownMenuItem(value: 'max', child: const Text('Maximum')),
        ],
        onChanged: (value) => setState(() => _aggregation = value ?? _aggregation),
      ),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(t('বাতিল', 'Cancel'))),
      FilledButton(
        onPressed: () {
          try {
            SheetsAnalytics.parseRange(_range.text);
            SheetsAnalytics.columnNumber(_group.text.trim());
            SheetsAnalytics.columnNumber(_value.text.trim());
            if (_group.text.trim().toUpperCase() == _value.text.trim().toUpperCase()) {
              throw const FormatException('Row field and value field must be different columns.');
            }
            Navigator.pop(context, {
              'range': _range.text.trim().toUpperCase(),
              'groupColumn': _group.text.trim().toUpperCase(),
              'valueColumn': _value.text.trim().toUpperCase(),
              'aggregation': _aggregation,
            });
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
          }
        },
        child: Text(t('Pivot তৈরি', 'Create Pivot')),
      ),
    ],
  );
}

class SheetsChartPreview extends StatelessWidget {
  const SheetsChartPreview({
    super.key,
    required this.data,
    required this.type,
  });

  final SheetsChartData data;
  final String type;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SheetsChartPainter(data: data, line: type == 'line'),
    child: const SizedBox.expand(),
  );
}

class _SheetsChartPainter extends CustomPainter {
  const _SheetsChartPainter({required this.data, required this.line});

  final SheetsChartData data;
  final bool line;

  static const colors = [
    Color(0xFF2675D8),
    Color(0xFF17A589),
    Color(0xFFE67E22),
    Color(0xFF8E44AD),
    Color(0xFFC0392B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 30 || size.height <= 30 || data.labels.isEmpty) return;
    const left = 12.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 12.0;
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;
    final maxValue = data.series
        .expand((series) => series.values)
        .fold<double>(0, (max, value) => value > max ? value : max);
    final scale = maxValue <= 0 ? 1.0 : maxValue;
    final axis = Paint()..color = const Color(0xFFB8C3D0)..strokeWidth = 1;
    canvas.drawLine(Offset(left, top), Offset(left, top + plotHeight), axis);
    canvas.drawLine(Offset(left, top + plotHeight), Offset(left + plotWidth, top + plotHeight), axis);
    final count = data.labels.length;
    if (line) {
      for (var seriesIndex = 0; seriesIndex < data.series.length; seriesIndex++) {
        final values = data.series[seriesIndex].values;
        final paint = Paint()
          ..color = colors[seriesIndex % colors.length]
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final path = Path();
        for (var i = 0; i < values.length; i++) {
          final x = left + (count <= 1 ? plotWidth / 2 : plotWidth * i / (count - 1));
          final y = top + plotHeight - (values[i] / scale) * plotHeight;
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        canvas.drawPath(path, paint);
        final dot = Paint()..color = colors[seriesIndex % colors.length];
        for (var i = 0; i < values.length; i++) {
          final x = left + (count <= 1 ? plotWidth / 2 : plotWidth * i / (count - 1));
          final y = top + plotHeight - (values[i] / scale) * plotHeight;
          canvas.drawCircle(Offset(x, y), 3, dot);
        }
      }
    } else {
      final groupWidth = plotWidth / count;
      final barWidth = groupWidth / (data.series.length + 1);
      for (var i = 0; i < count; i++) {
        for (var j = 0; j < data.series.length; j++) {
          final value = data.series[j].values[i];
          final height = (value / scale) * plotHeight;
          final rect = Rect.fromLTWH(
            left + i * groupWidth + j * barWidth + barWidth * 0.15,
            top + plotHeight - height,
            barWidth * 0.7,
            height,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()..color = colors[j % colors.length],
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SheetsChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.line != line;
}
