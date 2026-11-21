import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/main.dart';

void main() {
  testWidgets('App Info shows the creator proof and approved app identity',
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
    expect(find.text('Created & Developed By:'), findsOneWidget);
    expect(find.text('MD PIYARUL ISLAM'), findsOneWidget);
    expect(find.text('Founder & Original Creator'), findsOneWidget);
    expect(find.text('Creator Recognition'), findsOneWidget);
    expect(find.text('© 2026 OFFYNEXBD. All Rights Reserved.'), findsOneWidget);
    expect(find.text('Rajshahi, Bangladesh'), findsNothing);
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.textContaining('commit history'), findsNothing);
    expect(find.textContaining('release record'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('App Info translates the creator label into Bangla',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppInfoScreen(isBangla: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('তৈরি ও উন্নয়নে:'), findsOneWidget);
    expect(find.text('MD PIYARUL ISLAM'), findsOneWidget);
    expect(find.text('প্রতিষ্ঠাতা ও মূল নির্মাতা'), findsOneWidget);
    expect(find.text('© 2026 OFFYNEXBD. All Rights Reserved.'), findsOneWidget);
  });
}
