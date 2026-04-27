import 'package:flutter/material.dart';

ThemeData buildKvizLightTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF063A6B),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF063A6B),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFD7E9FF),
        onPrimaryContainer: const Color(0xFF061B33),
        secondary: const Color(0xFFD71920),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFFFDFE0),
        onSecondaryContainer: const Color(0xFF4B0507),
        surface: Colors.white,
        onSurface: const Color(0xFF071A2F),
        onSurfaceVariant: const Color(0xFF435468),
        surfaceContainerHighest: const Color(0xFFE7F0FA),
        outline: const Color(0xFF7890A9),
        outlineVariant: const Color(0xFFC4D3E5),
        errorContainer: const Color(0xFFFFE2E0),
        onErrorContainer: const Color(0xFF7A1712),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF3F7FC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF3F7FC),
      foregroundColor: Color(0xFF071A2F),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFF063A6B),
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF062F5D),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFC7D4E3),
        disabledForegroundColor: const Color(0xFF68788C),
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: const Color(0x33062F5D),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF063A6B),
        side: const BorderSide(color: Color(0xFF89A3BF), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: Color(0xFF435468),
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(color: Color(0xFF6C7C90)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB8C9DC), width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF063A6B), width: 1.7),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFC4D3E5),
      thickness: 1,
    ),
  );
}

ThemeData buildKvizDarkTheme() {
  const navyBg = Color(0xFF061527);
  const navyCard = Color(0xFF0D2238);
  const accentBlue = Color(0xFF61C8FF);

  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accentBlue,
    onPrimary: navyBg,
    primaryContainer: const Color(0xFF123A5E),
    onPrimaryContainer: const Color(0xFFD5F0FF),
    secondary: const Color(0xFFFF5D66),
    onSecondary: const Color(0xFF2D0003),
    secondaryContainer: const Color(0xFF5E0B10),
    onSecondaryContainer: const Color(0xFFFFDCDD),
    tertiary: const Color(0xFF5EDC72),
    onTertiary: const Color(0xFF05280C),
    tertiaryContainer: const Color(0xFF163C1E),
    onTertiaryContainer: const Color(0xFFB9F6C1),
    error: const Color(0xFFFF6F6B),
    onError: const Color(0xFF350003),
    errorContainer: const Color(0xFF551213),
    onErrorContainer: const Color(0xFFFFD4D2),
    surface: navyCard,
    onSurface: Colors.white,
    surfaceContainerHighest: const Color(0xFF173350),
    outline: const Color(0xFF42617E),
    outlineVariant: const Color(0xFF24425F),
    inverseSurface: Colors.white,
    onInverseSurface: navyBg,
    inversePrimary: const Color(0xFF063A6B),
    shadow: Colors.black,
    scrim: Colors.black54,
    surfaceTint: accentBlue,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: navyBg,
    appBarTheme: AppBarTheme(
      backgroundColor: navyBg,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.05,
        color: Colors.white,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: Color(0xFFD7E8F8),
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: Color(0xFFC0D4E8),
      ),
      labelLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B5AA0),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF233C56),
        disabledForegroundColor: const Color(0xFF8AA2BA),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
        shadowColor: const Color(0x66000000),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD5F0FF),
        side: const BorderSide(color: Color(0xFF42617E), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0B1D31),
      labelStyle: const TextStyle(
        color: Color(0xFFC0D4E8),
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(color: Color(0xFF8AA2BA)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2D4F70), width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accentBlue, width: 1.7),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF24425F),
      thickness: 1,
    ),
  );
}
