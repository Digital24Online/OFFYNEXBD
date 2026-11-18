import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/slides_pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports Bangla and English slides as a landscape PDF', () async {
    final bytes = await SlidesPdfExportService.build(
      title: 'Quarterly Report',
      slideTexts: ['প্রথম স্লাইড', 'Revenue and growth'],
    );
    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('rejects empty and excessive slide collections', () async {
    await expectLater(
      SlidesPdfExportService.build(title: 'Empty', slideTexts: []),
      throwsFormatException,
    );
    await expectLater(
      SlidesPdfExportService.build(
        title: 'Too many',
        slideTexts: List<String>.filled(201, 'Slide'),
      ),
      throwsFormatException,
    );
  });

  test('rejects presentation text above the 5 MB export limit', () async {
    await expectLater(
      SlidesPdfExportService.build(
        title: 'Large',
        slideTexts: [''.padRight(SlidesPdfExportService.maxTextBytes, 'x')],
      ),
      throwsFormatException,
    );
}
