import 'package:flutter/material.dart';

/// Matches Kotlin Theme.kt exactly — same hex color values for Light & Dark schemes.

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF005AC1),
    secondary: Color(0xFF525E7D),
    tertiary: Color(0xFF0061A4),
    surface: Color(0xFFFDFBFF),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1C1E),
    onSurfaceVariant: Color(0xFF44474E),
    outline: Color(0xFF74777F),
    outlineVariant: Color(0xFFC4C6D0),
    tertiaryContainer: Color(0xFFE6F4EA),
    onTertiaryContainer: Color(0xFF137333),
    primaryContainer: Color(0xFFD6E3FF),
    secondaryContainer: Color(0xFFDDE1F9),
    errorContainer: Color(0xFFFFDAD6),
    error: Color(0xFFBA1A1A),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFA8C7FA),
    secondary: Color(0xFFBAC6EA),
    tertiary: Color(0xFFD8E2FF),
    surface: Color(0xFF1A1C1E),
    onPrimary: Color(0xFF003062),
    onSurface: Color(0xFFE3E2E6),
    onSurfaceVariant: Color(0xFFC4C6D0),
    outline: Color(0xFF8D9199),
    outlineVariant: Color(0xFF44474E),
    tertiaryContainer: Color(0xFF0F5223),
    onTertiaryContainer: Color(0xFF6DD58C),
    primaryContainer: Color(0xFF004A99),
    secondaryContainer: Color(0xFF3B4664),
    errorContainer: Color(0xFF93000A),
    error: Color(0xFFFFB4AB),
  ),
);
