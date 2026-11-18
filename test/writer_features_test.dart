import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart' hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/writer/writer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _writerTestApp(Widget home) => MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...FlutterQuillLocalizations.localizationsDelegates,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('Writer ribbon follows Bangla and English app language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();

    expect(find.text('নতুন ডকুমেন্ট'), findsOneWidget);
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    expect(find.text('ফাইল'), findsOneWidget);
    expect(find.text('লেআউট'), findsOneWidget);
    expect(find.text('রেফারেন্স'), findsOneWidget);
    expect(find.text('রিভিউ'), findsOneWidget);
    expect(find.text('ভিউ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: false)));
    await tester.pumpAndSettle();

    expect(find.text('New Document'), findsOneWidget);
    await tester.tap(find.text('New Document'));
    await tester.pumpAndSettle();
    expect(find.text('File'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('References'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('Writer header and footer settings persist with document metadata', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ফাইল'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('হেডার / ফুটার'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(1), 'OFFYNEXBD');
    await tester.enterText(fields.at(2), 'পৃষ্ঠা {page} / {pages}');
    await tester.tap(find.text('সংরক্ষণ').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offynex_writer_documents');
    expect(raw, isNotNull);
    expect(raw, contains('OFFYNEXBD'));
    expect(raw, contains('{page}'));
    expect(raw, contains('{pages}'));
  });
}
