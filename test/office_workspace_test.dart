import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/workspace/office_workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Forms workspace creates and persists a form draft',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Forms', isBangla: true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('নতুন তৈরি'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'গ্রাহক ফরম');
    await tester.enterText(fields.at(1), 'নাম\nমোবাইল\nঠিকানা');
    await tester.tap(find.text('সংরক্ষণ'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_workspace_forms_v1');
    expect(raw, isNotNull);
    final items = jsonDecode(raw!) as List<dynamic>;
    expect(items, hasLength(1));
    expect(items.first['title'], 'গ্রাহক ফরম');
    expect(items.first['content'], 'নাম\nমোবাইল\nঠিকানা');
  });

  testWidgets('Database workspace supports editing an existing schema note',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_workspace_database_v1': jsonEncode([
        {'id': '1', 'title': 'Customers', 'content': 'name, phone', 'updatedAt': '2026-11-18'}
      ]),
    });
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Database', isBangla: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'name, phone, email');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final items = jsonDecode(prefs.getString('offynex_workspace_database_v1')!) as List;
    expect(items.single['content'], 'name, phone, email');
  });

  testWidgets('Cloud backup panel explains local-only status and generates backup',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_writer_documents': '[{"id":"doc-1"}]',
      'offynex_sheets_workbook_v1': '{"name":"Sheet1"}',
    });
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Cloud', isBangla: true),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('অনলাইন Cloud Sync এখনো সংযুক্ত নয়'), findsOneWidget);
    await tester.tap(find.text('ব্যাকআপ তৈরি'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    final backup = field.controller!.text;
    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    expect(decoded['format'], 'OFFYNEXBD_LOCAL_BACKUP');
    final data = decoded['data'] as Map<String, dynamic>;
    expect(data['offynex_writer_documents'], contains('doc-1'));
    expect(data['offynex_sheets_workbook_v1'], contains('Sheet1'));
  });
}
