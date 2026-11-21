import 'package:material_ui/material_ui.dart';

/// Shared visual language and reusable design tokens for every OFFYNEXBD module.
class OFFYNEXTheme {
  OFFYNEXTheme._();

  // Brand and semantic surfaces.
  static const Color ink = Color(0xFF172B4D);
  static const Color muted = Color(0xFF718096);
  static const Color canvas = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EAF2);
  static const Color blue = Color(0xFF246BCE);
  static const Color blueSoft = Color(0xFFEAF2FF);
  static const Color navy = Color(0xFF142C55);
  static const Color teal = Color(0xFF168C91);
  static const Color success = Color(0xFF16845B);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFC43D4B);
  static const Color info = Color(0xFF2878B8);

  // Module accents are limited to icons and small active-state markers.
  // Shared surfaces, controls and typography must remain consistent.
  static const Color writerAccent = Color(0xFF2878DB);
  static const Color sheetsAccent = Color(0xFF159B68);
  static const Color slidesAccent = Color(0xFFE58A28);
  static const Color pdfAccent = Color(0xFFE34B50);
  static const Color fontsAccent = Color(0xFF8055D9);
  static const Color aiAccent = Color(0xFF0C9CA6);
  static const Color cloudAccent = Color(0xFF4386D9);
  static const Color formsAccent = Color(0xFFCB7B35);
  static const Color scanAccent = Color(0xFF347F9D);
  static const Color databaseAccent = Color(0xFF6875B8);

  static const Map<String, Color> moduleAccents = {
    'Writer': writerAccent,
    'Sheets': sheetsAccent,
    'Slides': slidesAccent,
    'PDF': pdfAccent,
    'Fonts': fontsAccent,
    'AI Assistant': aiAccent,
    'Cloud': cloudAccent,
    'Forms': formsAccent,
    'Scan': scanAccent,
    'Database': databaseAccent,
  };

  static Color accentFor(String module) => moduleAccents[module] ?? blue;

  // Four-point spacing scale.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  // Shared corner and touch-target dimensions.
  static const double radiusCompact = 8;
  static const double radiusControl = 12;
  static const double radiusPanel = 16;
  static const double radiusCard = 20;
  static const double minTouchTarget = 48;
  static const double controlHeight = 48;

  // Shared UI type scale. Document formatting remains user-controlled.
  static const TextStyle caption = TextStyle(
    color: muted,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle body = TextStyle(
    color: ink,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle sectionTitle = TextStyle(
    color: ink,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle pageTitle = TextStyle(
    color: ink,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(
      primary: blue,
      onPrimary: Colors.white,
      secondary: teal,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      error: danger,
      onError: Colors.white,
      outline: border,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, controlHeight),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, controlHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, controlHeight),
          foregroundColor: blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      ),
    );
  }
}
