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
}
