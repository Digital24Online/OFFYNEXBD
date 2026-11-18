import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_screen.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('legacy workbook migrates and worksheets keep independent cell data',
      (tester) async {
    const legacy = '{"name":"Legacy","rows":30,"columns":12,'
        '"cells":{"A1":"old-data"},"styles":{"A1":{"bold":true}}}';
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': legacy,
    });

    await tester.pumpWidget(const MaterialApp(
      home: SheetsScreen(isBangla: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('old-data'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    var workbook = SheetsWorkbookCodec.decode(
      prefs.getString('offynex_sheets_workbook_v1')!,
    );
    expect(workbook.sheets, hasLength(1));
    expect(workbook.activeSheet.name, 'Legacy');

    await tester.tap(find.byKey(const ValueKey('add-worksheet')));
    await tester.pumpAndSettle();
    expect(find.text('Sheet2'), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey('sheet-cell-A1')));
    await tester.pumpAndSettle();
    final editor = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(editor, 'new-data');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('worksheet-tab-legacy-sheet-1')));
    await tester.pumpAndSettle();
    expect(find.text('old-data'), findsOneWidget);

    await tester.tap(find.text('Sheet2'));
    await tester.pumpAndSettle();
    expect(find.text('new-data'), findsOneWidget);

    workbook = SheetsWorkbookCodec.decode(
      prefs.getString('offynex_sheets_workbook_v1')!,
    );
    expect(workbook.sheets, hasLength(2));
    expect(workbook.sheets.first.cells['A1'], 'old-data');
    expect(workbook.activeSheet.cells['A1'], 'new-data');
  });
}
