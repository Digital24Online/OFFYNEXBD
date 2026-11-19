import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';

void main() {
  testWidgets('App Info records the creator attribution and selected portrait',
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
    expect(find.text('Work Smart, Be Productive'), findsNothing);
    expect(find.text('MD PIYARUL ISLAM'), findsOneWidget);
    expect(find.text('Founder & Original Creator'), findsOneWidget);
    expect(find.text('Rajshahi, Bangladesh'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Creator Statement'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('Creator Statement'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('© 2026 OFFYNEXBD. All Rights Reserved.'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('© 2026 OFFYNEXBD. All Rights Reserved.'), findsOneWidget);
    expect(find.text('MD'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
