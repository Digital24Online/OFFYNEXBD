import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  testWidgets('OFFYNEXBD home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    expect(find.text('OFFYNEXBD'), findsWidgets);
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
    expect(find.text('Clear Formats'), findsOneWidget);

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

    await tester.ensureVisible(find.text('Clear Formats'));
    await tester.tap(find.text('Clear Formats'));
    await tester.pumpAndSettle();

    final clearedRaw = prefs.getString('offynex_sheets_workbook_v1');
    final clearedWorkbook = jsonDecode(clearedRaw!) as Map<String, dynamic>;
    final clearedCells = clearedWorkbook['cells'] as Map<String, dynamic>;
    final clearedStyles = clearedWorkbook['styles'] as Map<String, dynamic>;
    expect(clearedCells['A1'], 'Keep me');
    expect(clearedStyles.containsKey('A1'), isFalse);
  });

}
