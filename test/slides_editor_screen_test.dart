import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/workspace/slides_document_codec.dart';
import 'package:offynexbd/lib/modules/workspace/slides_editor_screen.dart';

void main() {
  testWidgets('Slides editor adds and duplicates slides and saves in order', (tester) async {
    Map<String, String>? saved;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              saved = await Navigator.push<Map<String, String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SlidesEditorScreen(
                    isBangla: false,
                    title: 'Quarterly plan',
                    content: 'Opening\nSummary',
                  ),
                ),
              );
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add slide'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));

    await tester.enterText(find.byType(TextField).at(1), 'Updated opening');
    await tester.enterText(find.byType(TextField).at(2), 'Summary');
    await tester.enterText(find.byType(TextField).at(3), 'Next steps');
    await tester.tap(find.byTooltip('Duplicate slide').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved?['title'], 'Quarterly plan');
    expect(
      SlidesDocumentCodec.decode(saved?['content'] ?? ''),
      ['Updated opening', 'Updated opening', 'Summary', 'Next steps'],
    );
  });
}
