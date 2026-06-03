import 'package:flutter/material.dart';

/// Matches Kotlin Theme.kt exactly — same hex color values for Light & Dark schemes.

const _lightMedals = MedalColors(
  gold: Color(0xFFFFD700),
  goldText: Color(0xFF1A1C1E),
  silver: Color(0xFFC0C0C0),
  silverText: Color(0xFF1A1C1E),
  bronze: Color(0xFFCD7F32),
  bronzeText: Color(0xFFFFFFFF),
);

const _darkMedals = MedalColors(
  // Slightly brighter than light-mode so they read on the dark surface
  // while still feeling "metallic". Text colour stays dark because the
  // medal fills are still bright enough to warrant a dark label.
  gold: Color(0xFFFFE55C),
  goldText: Color(0xFF1A1C1E),
  silver: Color(0xFFD8D8D8),
  silverText: Color(0xFF1A1C1E),
  bronze: Color(0xFFE0975C),
  bronzeText: Color(0xFF1A1C1E),
);

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
  // M3 default adds a slight primary-tinted overlay on elevated surfaces;
  // we strip it so cards/dialogs feel flat against the background.
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFFFDFBFF),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFDFBFF),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 1,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFFFDFBFF),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFFFDFBFF),
    surfaceTintColor: Colors.transparent,
    indicatorColor: Color(0xFFDDE1F9),
  ),
  extensions: const [_lightMedals],
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
  // In dark mode, lifting a card by tinting it with the primary blue
  // looks out of place. We use surfaceContainerLow for a subtle, neutral
  // elevation that doesn't introduce a colour cast.
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFF211F26),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A1C1E),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 1,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF2B2930),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFF1A1C1E),
    surfaceTintColor: Colors.transparent,
    indicatorColor: Color(0xFF3B4664),
  ),
  extensions: const [_darkMedals],
);

/// Theme extension for the gold / silver / bronze medal colours used in
/// the rankings screen. Defined as a [ThemeExtension] so light and dark
/// variants stay in sync with the rest of the theme — no more hardcoded
/// `Color(0xFFFFD700)` in the screen.
@immutable
class MedalColors extends ThemeExtension<MedalColors> {
  final Color gold;
  final Color goldText;
  final Color silver;
  final Color silverText;
  final Color bronze;
  final Color bronzeText;

  const MedalColors({
    required this.gold,
    required this.goldText,
    required this.silver,
    required this.silverText,
    required this.bronze,
    required this.bronzeText,
  });

  @override
  MedalColors copyWith({
    Color? gold,
    Color? goldText,
    Color? silver,
    Color? silverText,
    Color? bronze,
    Color? bronzeText,
  }) {
    return MedalColors(
      gold: gold ?? this.gold,
      goldText: goldText ?? this.goldText,
      silver: silver ?? this.silver,
      silverText: silverText ?? this.silverText,
      bronze: bronze ?? this.bronze,
      bronzeText: bronzeText ?? this.bronzeText,
    );
  }

  @override
  MedalColors lerp(ThemeExtension<MedalColors>? other, double t) {
    if (other is! MedalColors) return this;
    return MedalColors(
      gold: Color.lerp(gold, other.gold, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      silverText: Color.lerp(silverText, other.silverText, t)!,
      bronze: Color.lerp(bronze, other.bronze, t)!,
      bronzeText: Color.lerp(bronzeText, other.bronzeText, t)!,
    );
  }
}
