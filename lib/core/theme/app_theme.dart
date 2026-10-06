import 'package:flutter/material.dart';

class AppTheme {
  static const _textTheme = TextTheme(
    headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2),
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.2),
    headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.3),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3),
    titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.4),
    titleSmall: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.4),
    bodyLarge: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.5),
    bodyMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.1, height: 1.5),
    bodySmall: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 0.2, height: 1.4, fontSize: 12),
    labelLarge: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.8, height: 1.4),
    labelMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 1.0, height: 1.3),
    labelSmall: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 1.0, height: 1.3, fontSize: 11),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7C3AED),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDDD6FE),
      onPrimaryContainer: Color(0xFF4C1D95),
      secondary: Color(0xFF6B6B8A),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE2E4E9),
      onSecondaryContainer: Color(0xFF1B1B2F),
      tertiary: Color(0xFF34D399),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD1FAE5),
      onTertiaryContainer: Color(0xFF064E3B),
      error: Color(0xFFF87171),
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: Color(0xFFF4F5F7),
      onSurface: Color(0xFF1B1B2F),
      onSurfaceVariant: Color(0xFF6B6B8A),
      outline: Color(0xFFE2E4E9),
      outlineVariant: Color(0xFFECEDF1),
      shadow: Color(0xFF1B1B2F),
      surfaceContainerLow: Color(0xFFECEDF1),
      surfaceContainerHighest: Color(0xFFE2E4E9),
      inverseSurface: Color(0xFF1B1B2F),
      onInverseSurface: Color(0xFFF4F5F7),
    ),
    fontFamily: 'Roboto',
    textTheme: _textTheme,
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E4E9), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Color(0xFF1B1B2F),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 68,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xFF7C3AED).withOpacity(0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: Color(0xFF7C3AED), letterSpacing: 0.5,
          );
        }
        return const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w400,
          color: Color(0xFF6B6B8A), letterSpacing: 0.5,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF7C3AED), size: 22);
        }
        return const IconThemeData(color: Color(0xFF6B6B8A), size: 22);
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      backgroundColor: const Color(0xFF7C3AED),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFECEDF1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E4E9), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E4E9), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      backgroundColor: const Color(0xFF1B1B2F),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 0.5,
      color: Color(0xFFE2E4E9),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF8B5CF6),
      onPrimary: Color(0xFF1B1B2F),
      primaryContainer: Color(0xFF3B1F7E),
      onPrimaryContainer: Color(0xFFC4B5FD),
      secondary: Color(0xFF8888A8),
      onSecondary: Color(0xFF1B1B2F),
      secondaryContainer: Color(0xFF353560),
      onSecondaryContainer: Color(0xFFD0D0E0),
      tertiary: Color(0xFF34D399),
      onTertiary: Color(0xFF1B1B2F),
      tertiaryContainer: Color(0xFF064E3B),
      onTertiaryContainer: Color(0xFF6EE7B7),
      error: Color(0xFFF87171),
      onError: Color(0xFF1B1B2F),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFCA5A5),
      surface: Color(0xFF1B1B2F),
      onSurface: Color(0xFFF0F0F5),
      onSurfaceVariant: Color(0xFF8888A8),
      outline: Color(0xFF353560),
      outlineVariant: Color(0xFF2D2D5A),
      shadow: Colors.black,
      surfaceContainerLow: Color(0xFF252547),
      surfaceContainerHighest: Color(0xFF2D2D5A),
      inverseSurface: Color(0xFFF0F0F5),
      onInverseSurface: Color(0xFF1B1B2F),
    ),
    fontFamily: 'Roboto',
    textTheme: _textTheme,
    cardTheme: CardTheme(
      elevation: 0,
      color: const Color(0xFF252547),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF353560), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Color(0xFFF0F0F5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 68,
      backgroundColor: const Color(0xFF1B1B2F),
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xFF8B5CF6).withOpacity(0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: Color(0xFF8B5CF6), letterSpacing: 0.5,
          );
        }
        return const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w400,
          color: Color(0xFF8888A8), letterSpacing: 0.5,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF8B5CF6), size: 22);
        }
        return const IconThemeData(color: Color(0xFF8888A8), size: 22);
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      backgroundColor: const Color(0xFF8B5CF6),
      foregroundColor: const Color(0xFF1B1B2F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF252547),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF353560), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF353560), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF252547),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      backgroundColor: const Color(0xFF2D2D5A),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 0.5,
      color: Color(0xFF353560),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
