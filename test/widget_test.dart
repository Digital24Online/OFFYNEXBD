
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';

void main() {
  testWidgets('OFFYNEXBD home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const OFFYNEXBDApp());
    await tester.pumpAndSettle();

    expect(find.text('OFFYNEXBD'), findsWidgets);
    expect(find.text('আপনার অ্যাপস'), findsOneWidget);
    expect(find.text('রাইটার'), findsOneWidget);
    expect(find.text('শিটস'), findsOneWidget);
  });
}
