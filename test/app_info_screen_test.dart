import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';

void main() {
  testWidgets('App Info records the creator attribution and selected portrait',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppInfoScreen(isBangla: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFYNEXBD'), findsOneWidget);
    expect(find.text('MD PIYARUL ISLAM'), findsOneWidget);
    expect(find.text('Founder & Original Creator'), findsOneWidget);
    expect(find.text('Rajshahi, Bangladesh'), findsOneWidget);
    expect(find.text('Creator Statement'), findsOneWidget);
    expect(find.text('© 2026 OFFYNEXBD. All Rights Reserved.'), findsOneWidget);
    expect(find.text('MD'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
