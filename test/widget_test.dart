import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';
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
    expect(find.text('পিডিএফ'), findsOneWidget);
  });

  testWidgets('PDF tile opens the PDF-to-Document workspace', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('পিডিএফ'));
    await tester.pumpAndSettle();
    expect(find.text('PDF থেকে Document'), findsOneWidget);
    expect(find.text('PDF নির্বাচন করুন'), findsOneWidget);
    expect(find.text('ছবি থেকে Document'), findsOneWidget);
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
    var workbook = SheetsWorkbookCodec.decode(raw!);
    var styles = workbook.activeSheet.styles;
    expect(styles['A1']?['bold'], isTrue);

    await tester.ensureVisible(find.text('Wrap Text'));
    await tester.tap(find.text('Wrap Text'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Top Align'));
    await tester.tap(find.text('Top Align'));
    await tester.pumpAndSettle();

    final updatedRaw = prefs.getString('offynex_sheets_workbook_v1');
    workbook = SheetsWorkbookCodec.decode(updatedRaw!);
    styles = workbook.activeSheet.styles;
    expect(styles['A1']?['wrapText'], isTrue);
    expect(styles['A1']?['verticalAlign'], 'top');

    await tester.ensureVisible(find.text('ফরম্যাট মুছুন'));
    await tester.tap(find.text('ফরম্যাট মুছুন'));
    await tester.pumpAndSettle();

    final clearedRaw = prefs.getString('offynex_sheets_workbook_v1');
    final clearedWorkbook = SheetsWorkbookCodec.decode(clearedRaw!);
    expect(clearedWorkbook.activeSheet.cells['A1'], 'Keep me');
    expect(clearedWorkbook.activeSheet.styles.containsKey('A1'), isFalse);
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
    var workbook = SheetsWorkbookCodec.decode(raw!);
    expect(workbook.activeSheet.rows, 30);
    expect(workbook.activeSheet.columns, 12);
    expect(workbook.activeSheet.cells['A30'], 'Keep row');
    expect(workbook.activeSheet.cells['L1'], 'Keep column');

    await tester.ensureVisible(find.text('১০টি Row'));
    await tester.tap(find.text('১০টি Row'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('২টি Column'));
    await tester.tap(find.text('২টি Column'));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    raw = prefs.getString('offynex_sheets_workbook_v1');
    workbook = SheetsWorkbookCodec.decode(raw!);
    expect(workbook.activeSheet.rows, 40);
    expect(workbook.activeSheet.columns, 14);
    expect(workbook.activeSheet.cells['A30'], 'Keep row');
    expect(workbook.activeSheet.cells['L1'], 'Keep column');
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
    final workbook = SheetsWorkbookCodec.decode(raw!);
    expect(workbook.activeSheet.cells['A1'], '10');
    expect(workbook.activeSheet.cells['A2'], '=A1*2');
  });

  testWidgets('Sheets row removal does not mistake LOG10 for a cell reference',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': jsonEncode({
        'name': 'Sheet1',
        'rows': 10,
        'columns': 12,
        'cells': {'B1': '=LOG10(1000)'},
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

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_sheets_workbook_v1');
    final workbook = SheetsWorkbookCodec.decode(raw!);
    expect(workbook.activeSheet.rows, 9);
    expect(workbook.activeSheet.cells['B1'], '=LOG10(1000)');
  });

  testWidgets('Sheets protects rows referenced by formulas',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': jsonEncode({
        'name': 'Sheet1',
        'rows': 10,
        'columns': 12,
        'cells': {'B1': '=A10'},
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

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_sheets_workbook_v1');
    final workbook = SheetsWorkbookCodec.decode(raw!);
    expect(workbook.activeSheet.rows, 10);
    expect(workbook.activeSheet.cells['B1'], '=A10');
  });

  testWidgets('Sheets general number display preserves calculated precision',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': jsonEncode({
        'name': 'Sheet1',
        'rows': 30,
        'columns': 12,
        'cells': {'A1': '=1/3'},
        'styles': {},
      }),
    });
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('শিটস'));
    await tester.pumpAndSettle();

    expect(find.text('0.3333333333333333'), findsOneWidget);
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
    final workbook = SheetsWorkbookCodec.decode(raw!);
    final style = workbook.activeSheet.styles['A1']!;
    expect(style['wrapText'], isNot(true));
    expect(style['verticalAlign'], 'top');
    expect(style['align'], 'right');
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
