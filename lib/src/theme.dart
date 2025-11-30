import 'package:flutter/material.dart';

class AppColors {
  static const Color brandYellow = Color(0xFFFFD400);
  static const Color brandDark = Color(0xFF333336);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.brandDark,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brandDark,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.brandYellow),
      titleTextStyle: TextStyle(
        color: AppColors.brandYellow,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: AppColors.brandDark,
      secondary: AppColors.brandYellow,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandYellow,
        foregroundColor: AppColors.brandDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
      ),
    ),
    chipTheme: const ChipThemeData(
      labelStyle: TextStyle(color: Colors.white),
    ),
  );
}
