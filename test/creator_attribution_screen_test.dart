import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/creator_attribution_screen.dart';

void main() {
  testWidgets('Creator attribution is a separate in-app page with portrait',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: CreatorAttributionScreen(isBangla: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFYNEXBD'), findsOneWidget);
    expect(find.text('MD PIYARUL ISLAM'), findsOneWidget);
    expect(find.text('Founder & Original Creator'), findsOneWidget);
    expect(find.text('Creator Recognition'), findsOneWidget);
    expect(find.text('Rajshahi, Bangladesh'), findsNothing);
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.textContaining('release'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('© 2026 OFFYNEXBD. All Rights Reserved.'), findsOneWidget);
  });
}
