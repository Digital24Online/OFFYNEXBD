import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';

void main() {
  testWidgets('App Info includes the declared founder attribution',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AppInfoScreen(isBangla: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFYNEXBD'), findsOneWidget);
    expect(find.text('The Future of Office Productivity'), findsOneWidget);
    expect(find.text('© 2026 OFFYNEXBD. All Rights Reserved.'), findsNothing);
    expect(find.text('MD PIYARUL ISLAM'), findsOneWidget);
    expect(find.text('Founder & Original Creator'), findsOneWidget);
    expect(find.text('Creator Recognition'), findsOneWidget);
    expect(find.text('Rajshahi, Bangladesh'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
