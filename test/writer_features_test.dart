import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart' hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offynexbd/lib/modules/writer/writer_screen.dart';
import 'package:offynexbd/lib/modules/writer/writer_viewport.dart';
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
  testWidgets('Writer table editor follows Bangla and English language settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ইনসার্ট'));
    await tester.tap(find.text('ইনসার্ট'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('টেবিল'));
    await tester.pumpAndSettle();

    expect(find.text('টেবিল তৈরি করুন'), findsOneWidget);
    expect(find.text('সারি যোগ'), findsOneWidget);
    expect(find.text('কলাম যোগ'), findsOneWidget);
    expect(find.text('টেবিল প্রয়োগ'), findsOneWidget);
    await tester.tap(find.text('বাতিল'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Document'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Insert'));
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();

    expect(find.text('Create Table'), findsOneWidget);
    expect(find.text('Add Row'), findsOneWidget);
    expect(find.text('Add Column'), findsOneWidget);
    expect(find.text('Apply Table'), findsOneWidget);
  });

  testWidgets('Writer ribbon follows Bangla and English app language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();

    expect(find.text('নতুন ডকুমেন্ট'), findsOneWidget);
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    expect(find.text('ফাইল'), findsOneWidget);
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('ইনসার্ট'), findsOneWidget);
    expect(find.text('লেআউট'), findsOneWidget);
    expect(find.text('রেফারেন্স'), findsOneWidget);
    expect(find.text('রিভিউ'), findsOneWidget);
    expect(find.text('ভিউ'), findsOneWidget);
    expect(find.text('ডিজাইন'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: false)));
    await tester.pumpAndSettle();

    expect(find.text('New Document'), findsOneWidget);
    await tester.tap(find.text('New Document'));
    await tester.pumpAndSettle();
    expect(find.text('File'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Insert'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('References'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Design'), findsNothing);
  });

  testWidgets('Writer page layout controls follow the selected language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('লেআউট'));
    await tester.tap(find.text('লেআউট'));
    await tester.pumpAndSettle();

    expect(find.text('পৃষ্ঠার আকার'), findsOneWidget);
    expect(find.text('দিকনির্দেশ'), findsOneWidget);
    expect(find.text('মার্জিন'), findsOneWidget);
    expect(find.text('স্বাভাবিক'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Document'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Layout'));
    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();

    expect(find.text('Page Size'), findsOneWidget);
    expect(find.text('Orientation'), findsOneWidget);
    expect(find.text('Margins'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
  });

  testWidgets('Writer View ribbon exposes page fit, zoom and pinch canvas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ভিউ'));
    await tester.tap(find.text('ভিউ'));
    await tester.pumpAndSettle();

    final pageFitLabel = find.text('সম্পূর্ণ পৃষ্ঠা').first;
    final pageWidthLabel = find.text('পৃষ্ঠার প্রস্থ').first;
    expect(find.text('সম্পূর্ণ পৃষ্ঠা'), findsAtLeastNWidgets(1));
    expect(find.text('পৃষ্ঠার প্রস্থ'), findsAtLeastNWidgets(1));
    // The editor also has a compact bottom zoom slider; both controls are valid.
    expect(find.byType(Slider), findsAtLeastNWidgets(1));
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(pageWidthLabel);
    await tester.pumpAndSettle();
    final widthChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: pageWidthLabel,
        matching: find.byType(ChoiceChip),
      ).first,
    );
    expect(widthChip.selected, isTrue);

    await tester.tap(pageFitLabel);
    await tester.pumpAndSettle();
    final pageChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: pageFitLabel,
        matching: find.byType(ChoiceChip),
      ).first,
    );
    expect(pageChip.selected, isTrue);
  });

  testWidgets('Writer Insert ribbon offers an explicit page break', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ইনসার্ট'));
    await tester.tap(find.text('ইনসার্ট'));
    await tester.pumpAndSettle();
    expect(find.text('পৃষ্ঠা বিরতি'), findsOneWidget);
    await tester.tap(find.text('পৃষ্ঠা বিরতি'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE BREAK'), findsOneWidget);
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

  testWidgets('Writer View ribbon has direct zoom controls within supported zoom bounds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ভিউ'));
    await tester.tap(find.text('ভিউ'));
    await tester.pumpAndSettle();

    final sliderFinder = find.byKey(const ValueKey('writer-zoom-slider'));
    expect(sliderFinder, findsOneWidget);
    var slider = tester.widget<Slider>(sliderFinder);
    expect(slider.min, WriterViewportLayout.minimumZoom);
    expect(slider.max, WriterViewportLayout.maximumZoom);
    expect(slider.value, 1.0);

    await tester.tap(find.byKey(const ValueKey('writer-zoom-in')));
    await tester.pumpAndSettle();
    slider = tester.widget<Slider>(sliderFinder);
    expect(slider.value, closeTo(1.1, 0.001));

    await tester.tap(find.byKey(const ValueKey('writer-zoom-out')));
    await tester.pumpAndSettle();
    slider = tester.widget<Slider>(sliderFinder);
    expect(slider.value, closeTo(1.0, 0.001));
  });

  testWidgets('Writer opens with page width filling the mobile editor viewport', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();

    final page = tester.getSize(find.byKey(const ValueKey('writer-page-canvas')));
    expect(page.width, greaterThanOrEqualTo(380));
  });

  testWidgets('Writer Home exposes working undo, redo, paragraph alignment and list controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_writerTestApp(const WriterScreen(isBangla: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('নতুন ডকুমেন্ট'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('হোম'));
    await tester.tap(find.text('হোম'));
    await tester.pumpAndSettle();

    const controlKeys = [
      'writer-home-undo',
      'writer-home-redo',
      'writer-home-align-left',
      'writer-home-align-center',
      'writer-home-align-right',
      'writer-home-align-justify',
      'writer-home-bullets',
      'writer-home-numbering',
    ];
    for (final key in controlKeys) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: 'Missing Home control: $key');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    // Each Home action must be rendered once, not repeated in the
    // secondary Quill toolbar beneath the ribbon.
    for (final icon in [
      Icons.undo,
      Icons.redo,
      Icons.format_align_left,
      Icons.format_align_center,
      Icons.format_align_right,
      Icons.format_align_justify,
      Icons.format_list_bulleted,
      Icons.format_list_numbered,
    ]) {
      expect(
        find.byIcon(icon),
        findsOneWidget,
        reason: 'Duplicate Home option detected for $icon',
      );
    }
  });
}
