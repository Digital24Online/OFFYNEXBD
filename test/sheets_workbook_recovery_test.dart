import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_screen.dart';
import 'package:offynexbd/lib/modules/sheets/sheets_workbook_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('damaged workbook is preserved before an empty sheet is shown',
      (tester) async {
    const damaged = '{"cells":{"A1":"data"},"rows":"invalid"}';
    SharedPreferences.setMockInitialValues({
      'offynex_sheets_workbook_v1': damaged,
    });

    await tester.pumpWidget(const MaterialApp(
      home: SheetsScreen(isBangla: false),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final prefs = await SharedPreferences.getInstance();
    final recoveryKeys = prefs.getKeys()
        .where((key) => key.startsWith('offynex_sheets_workbook_recovery_'))
        .toList();
    expect(recoveryKeys, hasLength(1));
    expect(prefs.getString(recoveryKeys.single), damaged);
    final savedWorkbook = SheetsWorkbookCodec.decode(
      prefs.getString('offynex_sheets_workbook_v1')!,
    );
    expect(savedWorkbook.sheets, hasLength(1));
    expect(savedWorkbook.activeSheet.name, 'Sheet1');
    expect(savedWorkbook.activeSheet.cells, isEmpty);
  });
}
