import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offynexbd/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android software keyboard opens from Writer title and document body',
    (WidgetTester tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();

      await tester.pumpWidget(const OFFYNEXBDApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('রাইটার'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('নতুন ডকুমেন্ট'));
      await tester.pumpAndSettle();

      // This checks the real Android window inset, not Flutter's fake
      // TestTextInput visibility used by ordinary widget tests.
      await tester.tap(find.byType(TextField).first);
      await _waitForKeyboard(tester, visible: true);

      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await _waitForKeyboard(tester, visible: false);

      final page = find.byKey(const ValueKey('writer-page-canvas'));
      expect(page, findsOneWidget);
      await tester.tapAt(tester.getCenter(page));
      await _waitForKeyboard(tester, visible: true);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _waitForKeyboard(
  WidgetTester tester, {
  required bool visible,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final isVisible = tester.view.viewInsets.bottom > 0;
    if (isVisible == visible) return;
  }

  fail(
    'Android software keyboard did not become ${visible ? 'visible' : 'hidden'}; '
    'viewInsets.bottom=${tester.view.viewInsets.bottom}.',
  );
}
