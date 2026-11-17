import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  testWidgets('OFFYNEXBD home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    expect(find.text('OFFYNEXBD'), findsWidgets);
    expect(find.text('OFFYNEXBD  •  The Future of Office Productivity'), findsOneWidget);
    expect(find.text('আপনার অ্যাপস'), findsOneWidget);
    expect(find.text('রাইটার'), findsOneWidget);
    expect(find.text('শিটস'), findsOneWidget);
  });

  testWidgets('Sheets displays the desktop-style Ribbon and formula bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();

    expect(find.text('ফাইল'), findsOneWidget);
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('ইনসার্ট'), findsOneWidget);
    expect(find.text('ফর্মুলা'), findsOneWidget);
    expect(find.text('ডেটা'), findsOneWidget);
    expect(find.text('ভিউ'), findsOneWidget);
    expect(find.text('fx'), findsOneWidget);

    await tester.tap(find.text('ফর্মুলা'));
    await tester.pumpAndSettle();
    expect(find.text('SUM'), findsOneWidget);
    expect(find.text('AVERAGE'), findsOneWidget);

    await tester.tap(find.text('ভিউ'));
    await tester.pumpAndSettle();
    expect(find.text('Gridlines'), findsOneWidget);
  }); 
  testWidgets('Sheets Home Ribbon applies and saves cell formatting',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('হোম'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sheet-cell-A1')));
    await tester.pumpAndSettle();

    expect(find.text('Bold'), findsOneWidget);
    expect(find.text('Italic'), findsOneWidget);
    expect(find.text('Underline'), findsOneWidget);
    expect(find.text('Font Size'), findsOneWidget);
    expect(find.text('Font Color'), findsOneWidget);
    expect(find.text('Fill Color'), findsOneWidget);
    expect(find.text('Number Format'), findsOneWidget);
    expect(find.text('Borders'), findsOneWidget);
    expect(find.text('Wrap Text'), findsOneWidget);
    expect(find.text('Top Align'), findsOneWidget);
    expect(find.text('Middle Align'), findsOneWidget);
    expect(find.text('Bottom Align'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Keep me');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bold'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_sheets_workbook_v1');
    expect(raw, isNotNull);
    final workbook = jsonDecode(raw!) as Map<String, dynamic>;
    final styles = workbook['styles'] as Map<String, dynamic>;
    expect((styles['A1'] as Map<String, dynamic>)['bold'], isTrue);

    await tester.ensureVisible(find.text('Wrap Text'));
    await tester.tap(find.text('Wrap Text'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Top Align'));
    await tester.tap(find.text('Top Align'));
    await tester.pumpAndSettle();

    final updatedRaw = prefs.getString('offynex_sheets_workbook_v1');
    final updatedWorkbook = jsonDecode(updatedRaw!) as Map<String, dynamic>;
    final updatedStyles = updatedWorkbook['styles'] as Map<String, dynamic>;
    expect((updatedStyles['A1'] as Map<String, dynamic>)['wrapText'], isTrue);
    expect((updatedStyles['A1'] as Map<String, dynamic>)['verticalAlign'], 'top');

    await tester.ensureVisible(find.text('ফরম্যাট মুছুন'));
    await tester.tap(find.text('ফরম্যাট মুছুন'));
    await tester.pumpAndSettle();

    final clearedRaw = prefs.getString('offynex_sheets_workbook_v1');
    final clearedWorkbook = jsonDecode(clearedRaw!) as Map<String, dynamic>;
    final clearedCells = clearedWorkbook['cells'] as Map<String, dynamic>;
    final clearedStyles = clearedWorkbook['styles'] as Map<String, dynamic>;
    expect(clearedCells['A1'], 'Keep me');
    expect(clearedStyles.containsKey('A1'), isFalse);
  });

  testWidgets('Sheets protects populated edge rows and columns',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': jsonEncode({
        'name': 'Sheet1',
        'rows': 30,
        'columns': 12,
        'cells': {'A30': 'Keep row', 'L1': 'Keep column'},
        'styles': {},
      }),
    });
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('হোম'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('শেষ Row বাদ'));
    await tester.tap(find.text('শেষ Row বাদ'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('শেষ Column বাদ'));
    await tester.tap(find.text('শেষ Column বাদ'));
    await tester.pumpAndSettle();

    var prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString('offynex_sheets_workbook_v1');
    var workbook = jsonDecode(raw!) as Map<String, dynamic>;
    expect(workbook['rows'], 30);
    expect(workbook['columns'], 12);
    expect((workbook['cells'] as Map<String, dynamic>)['A30'], 'Keep row');
    expect((workbook['cells'] as Map<String, dynamic>)['L1'], 'Keep column');

    await tester.ensureVisible(find.text('১০টি Row'));
    await tester.tap(find.text('১০টি Row'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('২টি Column'));
    await tester.tap(find.text('২টি Column'));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    raw = prefs.getString('offynex_sheets_workbook_v1');
    workbook = jsonDecode(raw!) as Map<String, dynamic>;
    expect(workbook['rows'], 40);
    expect(workbook['columns'], 14);
    expect((workbook['cells'] as Map<String, dynamic>)['A30'], 'Keep row');
    expect((workbook['cells'] as Map<String, dynamic>)['L1'], 'Keep column');
  });

  testWidgets('Sheets cell editing recalculates formulas and persists data',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('sheet-cell-A1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '10');
    await tester.tap(find.text('সংরক্ষণ'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('sheet-cell-A2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '=A1*2');
    await tester.tap(find.text('সংরক্ষণ'));
    await tester.pumpAndSettle();

    expect(find.text('20'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();

    expect(find.text('20'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_sheets_workbook_v1');
    final workbook = jsonDecode(raw!) as Map<String, dynamic>;
    final cells = workbook['cells'] as Map<String, dynamic>;
    expect(cells['A1'], '10');
    expect(cells['A2'], '=A1*2');
  });

  testWidgets('Sheets vertical alignment works without Wrap Text',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('হোম'));
    await tester.pumpAndSettle();

    final cellFinder = find.byKey(const ValueKey('sheet-cell-A1'));
    await tester.tap(cellFinder);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Top Align'));
    await tester.tap(find.text('Top Align'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Align Right'));
    await tester.tap(find.text('Align Right'));
    await tester.pumpAndSettle();

    final cellContainer = find.descendant(
      of: cellFinder,
      matching: find.byType(Container),
    ).first;
    expect(
      tester.widget<Container>(cellContainer).alignment,
      Alignment.topRight,
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_sheets_workbook_v1');
    final workbook = jsonDecode(raw!) as Map<String, dynamic>;
    final styles = workbook['styles'] as Map<String, dynamic>;
    expect((styles['A1'] as Map<String, dynamic>)['wrapText'], isNot(true));
    expect((styles['A1'] as Map<String, dynamic>)['verticalAlign'], 'top');
    expect((styles['A1'] as Map<String, dynamic>)['align'], 'right');
  });

  testWidgets('Sheets builds distant rows only when they become visible',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': jsonEncode({
        'name': 'Sheet1',
        'rows': 1000,
        'columns': 12,
        'cells': {'A1000': 'Bottom row'},
        'styles': {},
      }),
    });

    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sheet-cell-A1000')), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('sheets-grid-vertical')),
      const Offset(0, -100000),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sheet-cell-A1000')), findsOneWidget);
  });

}
