import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

/// Colors aligned with the web dictionary (`common.css` + logo.svg).
abstract final class PunzhColors {
  /// Top bar on the website (`.navbar-dark`).
  static const Color navbar = Color(0xFF333333);

  /// Brand brown from logo / `.text-rus`.
  static const Color brand = Color(0xFF82551E);

  /// Darker brown used in logo strokes.
  static const Color brandDark = Color(0xFF554400);

  /// Bootstrap 4 primary (links / outline buttons on the site).
  static const Color link = Color(0xFF007BFF);

  static const Color surface = Color(0xFFF8F9FA);
}

/// Status / navigation icons over **dark** chrome (AppBar, drawer header).
/// Tied to our paint, not to OS light/dark mode.
const SystemUiOverlayStyle punzhStatusOnDark = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// Status icons over **light** chrome (drawer about panes, etc.).
const SystemUiOverlayStyle punzhStatusOnLight = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.dark,
);

ThemeData buildPunzhTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PunzhColors.brand,
    primary: PunzhColors.brand,
    secondary: PunzhColors.link,
    surface: PunzhColors.surface,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: PunzhColors.navbar,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: punzhStatusOnDark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PunzhColors.brand,
        foregroundColor: Colors.white,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: PunzhColors.brand.withValues(alpha: 0.22),
      disabledColor: const Color(0xFFF1F3F5),
      checkmarkColor: PunzhColors.brand,
      // Unselected labels must stay dark — M3 defaults wash out on white.
      labelStyle: const TextStyle(
        color: PunzhColors.navbar,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        color: PunzhColors.brandDark,
        fontWeight: FontWeight.w700,
      ),
      side: const BorderSide(color: Color(0xFFADB5BD)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: const Color(0xFFDEE2E6),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
    ),
  );
}
