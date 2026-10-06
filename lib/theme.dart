import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — terminal-black + NSE-gold, taken 1:1 from the web app.
class C {
  static const bg = Color(0xFF0A0D11);
  static const panel = Color(0xFF12161C);
  static const panelHi = Color(0xFF171C23);
  static const border = Color(0xFF212832);
  static const text = Color(0xFFE9EDF2);
  static const muted = Color(0xFF7E8A98);
  static const dim = Color(0xFF4E5866);
  static const green = Color(0xFF17C68B);
  static const red = Color(0xFFF0465B);
  static const gold = Color(0xFFEFB70F);
  static const goldDim = Color(0xFF8A6C15);
  static const onGold = Color(0xFF1A1400);
  static const blue = Color(0xFF4EA1F7);
  static const amber = gold; // older screens
  static const accent = gold; // primary action colour

  static Color greenBg = green.withAlpha(31);
  static Color redBg = red.withAlpha(31);
  static Color goldBg = gold.withAlpha(31);
  static Color blueBg = blue.withAlpha(31);

  static Color pnl(num? v) {
    if (v == null || v == 0) return muted;
    return v > 0 ? green : red;
  }
}

/// Type ramp: Space Grotesk for display, Inter for body, IBM Plex Mono for numbers.
class T {
  static TextStyle disp(double size, {FontWeight w = FontWeight.w700, Color color = C.text, double? spacing}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: w, color: color, letterSpacing: spacing, height: 1.2);

  static TextStyle mono(double size, {FontWeight w = FontWeight.w600, Color color = C.text}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: w, color: color, height: 1.2);

  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color color = C.text, double? height}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: color, height: height);

  static TextStyle label(Color color) =>
      GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color, letterSpacing: .6);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: C.gold, brightness: Brightness.dark);
  final radius = BorderRadius.circular(12);
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: T.disp(18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.panelHi,
      labelStyle: const TextStyle(color: C.muted),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: C.gold)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.gold,
        foregroundColor: C.onGold,
        disabledBackgroundColor: C.panelHi,
        disabledForegroundColor: C.dim,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: T.disp(15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.text,
        side: const BorderSide(color: C.border),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: C.gold)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.gold),
    dividerColor: C.border,
  );
}
