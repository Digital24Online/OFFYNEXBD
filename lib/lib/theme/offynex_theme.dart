import 'package:material_ui/material_ui.dart';

/// Shared visual language for every OFFYNEXBD module.
class OFFYNEXTheme {
  OFFYNEXTheme._();

  static const Color ink = Color(0xFF172B4D);
  static const Color muted = Color(0xFF718096);
  static const Color canvas = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EAF2);
  static const Color blue = Color(0xFF246BCE);
  static const Color blueSoft = Color(0xFFEAF2FF);
  static const Color navy = Color(0xFF142C55);
  static const Color teal = Color(0xFF168C91);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      surface: surface,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
