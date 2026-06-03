import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF7C3AED),
        secondary: Color(0xFF10B981),
        surface: Color(0xFF15151D),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A10),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
