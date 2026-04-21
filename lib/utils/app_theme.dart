import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF1F71A8);
  static const secondary = Color(0xFF6CA8FF);
  static const surface = Color(0xFFF3F6FF);
  static const background = Color(0xFFF6F8FF);

  static final Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1F71A8), Color(0xFF4EA1FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, surface: surface),
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
        bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEFF4FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
    );
  }

  static InputDecoration formInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primary),
      labelStyle: const TextStyle(color: Color(0xFF344054), fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );
  }
}
