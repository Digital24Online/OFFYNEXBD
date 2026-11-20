import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/workspace/slides_editor_screen.dart';
import 'package:offynexbd/lib/modules/workspace/slides_content_codec.dart';

void main() {
  testWidgets('slide editor adds, duplicates and saves slides in legacy format',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('Host')),
    ));

    final resultFuture = navigatorKey.currentState!.push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => const SlidesEditorScreen(
          title: 'Project',
          content: 'Opening\nSummary',
          isBangla: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Opening'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-slide')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('slide-content-input')), 'Next steps');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Next steps'), findsOneWidget);
    final menus = find.byType(PopupMenuButton<String>);
    await tester.tap(menus.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-slides')));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result, {
      'title': 'Project',
      'content': SlidesContentCodec.encode(['Opening', 'Summary', 'Next steps', 'Next steps']),
    });
  });

  testWidgets('slide editor requires a title and slide content', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SlidesEditorScreen(title: '', content: '', isBangla: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-slides')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a presentation title.'), findsOneWidget);
    expect(find.byType(SlidesEditorScreen), findsOneWidget);
  });
}
