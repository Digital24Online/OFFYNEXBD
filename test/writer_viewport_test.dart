import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/writer/writer_viewport.dart';

void main() {
  group('WriterViewportLayout', () {
    test('Full Page fits the complete paper inside a phone viewport', () {
      final layout = WriterViewportLayout.calculate(
        pageWidth: 794,
        pageHeight: 1122,
        viewportWidth: 400,
        viewportHeight: 700,
        viewFit: 'Page',
      );

      expect(layout.availableWidth, 392);
      expect(layout.scale, closeTo(392 / 794, 0.001));
      expect(794 * layout.scale, lessThanOrEqualTo(392.01));
      expect(1122 * layout.scale, lessThanOrEqualTo(700.01));
    });

    test('Page Width fits paper width and permits vertical scrolling', () {
      final layout = WriterViewportLayout.calculate(
        pageWidth: 794,
        pageHeight: 1122,
        viewportWidth: 400,
        viewportHeight: 400,
        viewFit: 'Width',
      );

      expect(794 * layout.scale, closeTo(376, 0.001));
      expect(1122 * layout.scale, greaterThan(400));
    });

    test('Actual mode represents one-to-one 100 percent paper scale', () {
      final layout = WriterViewportLayout.calculate(
        pageWidth: 794,
        pageHeight: 1122,
        viewportWidth: 400,
        viewportHeight: 700,
        viewFit: 'Actual',
      );

      expect(layout.scale, 1);
    });

    test('zoom multiplier is bounded and applied to all view modes', () {
      final base = WriterViewportLayout.calculate(
        pageWidth: 794,
        pageHeight: 1122,
        viewportWidth: 400,
        viewportHeight: 700,
        viewFit: 'Page',
      );
      final zoomed = WriterViewportLayout.calculate(
        pageWidth: 794,
        pageHeight: 1122,
        viewportWidth: 400,
        viewportHeight: 700,
        viewFit: 'Page',
        zoom: 2,
      );
      final minimum = WriterViewportLayout.calculate(
        pageWidth: 794,
        pageHeight: 1122,
        viewportWidth: 400,
        viewportHeight: 700,
        viewFit: 'Page',
        zoom: 0.1,
      );
      final maximum = WriterViewportLayout.calculate(
        pageWidth: 794,
        pageHeight: 1122,
        viewportWidth: 400,
        viewportHeight: 700,
        viewFit: 'Page',
        zoom: 5,
      );

      expect(zoomed.scale, closeTo(base.scale * 2, 0.001));
      expect(minimum.scale, closeTo(base.scale * 0.5, 0.001));
      expect(maximum.scale, lessThanOrEqualTo(3));
    });

    test('invalid page dimensions are rejected', () {
      expect(
        () => WriterViewportLayout.calculate(
          pageWidth: 0,
          pageHeight: 1122,
          viewportWidth: 400,
          viewportHeight: 700,
          viewFit: 'Page',
        ),
        throwsArgumentError,
      );
    });
  });
}
