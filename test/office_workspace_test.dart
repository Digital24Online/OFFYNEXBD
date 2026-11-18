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
    await tester.enterText(fields.at(1), 'গ্রাহক ফরম');
    await tester.enterText(fields.at(2), 'নাম\nমোবাইল\nঠিকানা');
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

  testWidgets('Forms collects answers for each newline-separated question and shows responses',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_workspace_forms_v1': jsonEncode([
        {
          'id': 'form-1',
          'title': 'Customer Registration',
          'content': 'Full name\nMobile number\nAddress',
          'updatedAt': '2026-11-18T10:00:00Z',
        },
      ]),
    });
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Forms', isBangla: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collect response'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).decoration?.labelText,
      'Full name',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).decoration?.labelText,
      'Mobile number',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(3)).decoration?.labelText,
      'Address',
    );

    await tester.enterText(find.byType(TextField).at(1), 'Test User');
    await tester.enterText(find.byType(TextField).at(2), '01700000000');
    await tester.enterText(find.byType(TextField).at(3), 'Rajshahi');
    await tester.tap(find.text('Save response'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('offynex_forms_responses_v1')!) as List;
    expect(saved, hasLength(1));
    expect(saved.single['formId'], 'form-1');
    expect(saved.single['answers'], [
      {'question': 'Full name', 'answer': 'Test User'},
      {'question': 'Mobile number', 'answer': '01700000000'},
      {'question': 'Address', 'answer': 'Rajshahi'},
    ]);

    await tester.tap(find.text('Responses'));
    await tester.pumpAndSettle();
    expect(find.text('Full name: Test User'), findsOneWidget);
    expect(find.text('Mobile number: 01700000000'), findsOneWidget);
    expect(find.text('Address: Rajshahi'), findsOneWidget);
  });

  testWidgets('Database workspace creates and updates offline table rows',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_workspace_database_v1': jsonEncode([
        {
          'id': 'table-1',
          'title': 'Customers',
          'content': 'Name, Phone',
          'updatedAt': '2026-11-18T10:00:00Z',
        },
      ]),
    });
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Database', isBangla: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage table rows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add row'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Test Customer');
    await tester.enterText(find.byType(TextField).at(2), '01700000000');
    await tester.tap(find.text('Save row'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    var prefs = await SharedPreferences.getInstance();
    var database = jsonDecode(prefs.getString('offynex_database_rows_v1')!) as Map;
    var rows = database['table-1'] as List;
    expect(rows, hasLength(1));
    expect(rows.single['values'], {
      'Name': 'Test Customer',
      'Phone': '01700000000',
    });

    await tester.tap(find.byTooltip('Manage table rows'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit row'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Updated Customer');
    await tester.tap(find.text('Save row'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    database = jsonDecode(prefs.getString('offynex_database_rows_v1')!) as Map;
    rows = database['table-1'] as List;
    expect(rows.single['values']['Name'], 'Updated Customer');
    expect(rows.single['values']['Phone'], '01700000000');
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
    await tester.enterText(find.byType(TextField).last, 'name, phone, email');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final items = jsonDecode(prefs.getString('offynex_workspace_database_v1')!) as List;
    expect(items.single['content'], 'name, phone, email');
  });

  testWidgets('damaged workspace records are preserved before recovery',
      (tester) async {
    const damaged = '{"records":"not-a-list"}';
    SharedPreferences.setMockInitialValues({
      'offynex_workspace_slides_v1': damaged,
    });

    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Slides', isBangla: false),
    ));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final recoveryKeys = prefs.getKeys()
        .where((key) => key.startsWith('offynex_workspace_slides_v1_recovery_'))
        .toList();
    expect(recoveryKeys, hasLength(1));
    expect(prefs.getString(recoveryKeys.single), damaged);
    expect(prefs.getString('offynex_workspace_slides_v1'), damaged);
    expect(find.text('Nothing saved yet.'), findsOneWidget);
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
  testWidgets('workspace search filters saved records by title and content',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'offynex_workspace_slides_v1': jsonEncode([
        {'id': '1', 'title': 'Annual Report', 'content': 'Revenue growth', 'updatedAt': '2026-11-18T10:00:00Z'},
        {'id': '2', 'title': 'Training', 'content': 'New staff onboarding', 'updatedAt': '2026-11-18T11:00:00Z'},
      ]),
    });
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Slides', isBangla: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Annual Report'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'revenue');
    await tester.pumpAndSettle();

    expect(find.text('Annual Report'), findsOneWidget);
    expect(find.text('Training'), findsNothing);
    expect(find.text('No matching records found.'), findsNothing);
  });

  testWidgets('damaged database row store is preserved and editing is stopped',
      (tester) async {
    const damaged = '{"table-1": "not-a-row-list"}';
    SharedPreferences.setMockInitialValues({
      'offynex_workspace_database_v1': jsonEncode([
        {
          'id': 'table-1',
          'title': 'Customers',
          'content': 'Name, Phone',
          'updatedAt': '2026-11-18T10:00:00Z',
        },
      ]),
      'offynex_database_rows_v1': damaged,
    });
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Database', isBangla: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage table rows'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final recoveryKeys = prefs.getKeys()
        .where((key) => key.startsWith('offynex_database_rows_recovery_'))
        .toList();
    expect(recoveryKeys, hasLength(1));
    expect(prefs.getString(recoveryKeys.single), damaged);
    expect(prefs.getString('offynex_database_rows_v1'), damaged);
    expect(find.text('Add row'), findsNothing);
  });

  testWidgets('database row with malformed field values is preserved unchanged',
      (tester) async {
    const damaged = '{"table-1":[{"id":"row-1","values":{"Name":7}}]}';
    SharedPreferences.setMockInitialValues({
      'offynex_workspace_database_v1': jsonEncode([
        {
          'id': 'table-1',
          'title': 'Customers',
          'content': 'Name, Phone',
          'updatedAt': '2026-11-18T10:00:00Z',
        },
      ]),
      'offynex_database_rows_v1': damaged,
    });
    await tester.pumpWidget(const MaterialApp(
      home: OfficeWorkspaceScreen(module: 'Database', isBangla: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage table rows'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final recoveryKeys = prefs.getKeys()
        .where((key) => key.startsWith('offynex_database_rows_recovery_'))
        .toList();
    expect(recoveryKeys, hasLength(1));
    expect(prefs.getString(recoveryKeys.single), damaged);
    expect(prefs.getString('offynex_database_rows_v1'), damaged);
    expect(find.text('Add row'), findsNothing);
  });

}
