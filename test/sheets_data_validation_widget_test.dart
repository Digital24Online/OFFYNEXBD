import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_screen.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('cell dropdown applies a permitted value and persists it', (tester) async {
    final workbook = SheetsWorkbook(
      activeSheetId: 'one',
      sheets: [
        SheetsWorksheet(
          id: 'one',
          name: 'One',
          rows: 5,
          columns: 3,
          validations: {'A1': ['Pending', 'Paid']},
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

    await tester.tap(find.byKey(const ValueKey('sheet-cell-A1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheets-open-cell-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = SheetsWorkbookCodec.decode(
      prefs.getString('offynex_sheets_workbook_v1')!,
    );
    expect(saved.activeSheet.cells['A1'], 'Paid');
    expect(saved.activeSheet.validations['A1'], ['Pending', 'Paid']);
  });
}
