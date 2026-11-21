import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/theme/offynex_theme.dart';

void main() {
  group('OFFYNEXBD shared design system', () {
    test('defines a restrained accent for every first-party module', () {
      expect(
        OFFYNEXTheme.moduleAccents.keys,
        containsAll([
          'Writer',
          'Sheets',
          'Slides',
          'PDF',
          'Fonts',
          'AI Assistant',
          'Cloud',
          'Forms',
          'Scan',
          'Database',
        ]),
      );
      expect(OFFYNEXTheme.accentFor('Writer'), OFFYNEXTheme.moduleAccents['Writer']);
      expect(OFFYNEXTheme.accentFor('Unknown'), OFFYNEXTheme.blue);
    });

    test('uses consistent shared surfaces and accessible touch dimensions', () {
      final theme = OFFYNEXTheme.light;
      expect(theme.scaffoldBackgroundColor, OFFYNEXTheme.canvas);
      expect(theme.colorScheme.primary, OFFYNEXTheme.blue);
      expect(theme.colorScheme.secondary, OFFYNEXTheme.teal);
      expect(OFFYNEXTheme.minTouchTarget, greaterThanOrEqualTo(48));
      expect(OFFYNEXTheme.controlHeight, greaterThanOrEqualTo(44));
      expect(OFFYNEXTheme.space4, 16);
    });
  });
}
