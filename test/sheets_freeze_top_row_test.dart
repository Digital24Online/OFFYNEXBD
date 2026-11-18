import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_screen.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Freeze Top Row pins the first visible row and persists its state',
      (tester) async {
    final workbook = SheetsWorkbook(
      activeSheetId: 'one',
      sheets: [
        SheetsWorksheet(
          id: 'one',
          name: 'One',
          rows: 8,
          columns: 4,
          cells: {'A1': 'Pinned row', 'A2': 'Scrollable row'},
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': SheetsWorkbookCodec.encode(workbook),
    });

    await tester.pumpWidget(const MaterialApp(
      home: SheetsScreen(isBangla: false),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sheets-frozen-top-row')), findsNothing);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freeze Top Row'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sheets-frozen-top-row')), findsOneWidget);
    expect(find.text('Pinned row'), findsOneWidget);
    expect(find.text('Scrollable row'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    var saved = SheetsWorkbookCodec.decode(
      prefs.getString('offynex_sheets_workbook_v1')!,
    );
    expect(saved.activeSheet.freezeTopRow, isTrue);

    await tester.tap(find.text('Unfreeze Top Row'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheets-frozen-top-row')), findsNothing);
    saved = SheetsWorkbookCodec.decode(
      prefs.getString('offynex_sheets_workbook_v1')!,
    );
    expect(saved.activeSheet.freezeTopRow, isFalse);
  });
}
