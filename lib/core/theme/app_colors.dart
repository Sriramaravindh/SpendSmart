import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryLight = Color(0xFFC4B5FD);
  static const Color primaryDark = Color(0xFF7C3AED);

  static const Color income = Color(0xFF34D399);
  static const Color expense = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);

  static const Color darkBg = Color(0xFF1B1B2F);
  static const Color darkCard = Color(0xFF252547);
  static const Color darkElevated = Color(0xFF2D2D5A);
  static const Color darkBorder = Color(0xFF353560);
  static const Color darkTextPrimary = Color(0xFFF0F0F5);
  static const Color darkTextSecondary = Color(0xFF8888A8);

  static const Color lightBg = Color(0xFFF4F5F7);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E4E9);
  static const Color lightTextPrimary = Color(0xFF1B1B2F);
  static const Color lightTextSecondary = Color(0xFF6B6B8A);

  static const List<Color> accentGradient = [Color(0xFF8B5CF6), Color(0xFFC4B5FD)];
  static const List<Color> incomeGradient = [Color(0xFF34D399), Color(0xFF6EE7B7)];
  static const List<Color> expenseGradient = [Color(0xFFF87171), Color(0xFFFCA5A5)];

  static BoxDecoration premiumCardDecoration({
    required Brightness brightness,
    double borderRadius = 20,
  }) {
    final isLight = brightness == Brightness.light;
    return BoxDecoration(
      color: isLight ? lightCard : darkCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isLight ? lightBorder : darkBorder,
        width: 0.5,
      ),
    );
  }

  static const List<Color> categoryColors = [
    Color(0xFF8B5CF6),
    Color(0xFF60A5FA),
    Color(0xFFF87171),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFFF472B6),
    Color(0xFF00D1FF),
    Color(0xFF818CF8),
    Color(0xFFFB923C),
    Color(0xFF4ADE80),
    Color(0xFFC084FC),
    Color(0xFF38BDF8),
  ];

  static const List<Color> chartColors = [
    Color(0xFF8B5CF6),
    Color(0xFF60A5FA),
    Color(0xFFF87171),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFFF472B6),
    Color(0xFF00D1FF),
    Color(0xFF818CF8),
    Color(0xFFFB923C),
    Color(0xFF4ADE80),
  ];
}
