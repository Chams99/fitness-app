import 'package:flutter/material.dart';

class AppTheme {
  // Define static color properties for consistent usage
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.blueAccent;
  static const Color accentColor = Colors.orange;

  // Warning colors for light and dark themes
  static const Color warningColorLight = Colors.red;
  static const Color warningColorDark = Color(
    0xFFFF5252,
  ); // Lighter red for dark mode
  static const Color warningBackgroundLight = Color(
    0xFFFFEBEE,
  ); // Light red background
  static const Color warningBackgroundDark = Color(
    0xFF2C1515,
  ); // Darker red background for dark mode

  // AI Card colors for light and dark themes
  static const Color aiCardBackgroundLight = Color(
    0xFFE3F2FD,
  ); // Light blue background
  static const Color aiCardBackgroundDark = Color(
    0xFF1A2327,
  ); // Dark blue-grey background
  static const Color aiCardAccentLight = Color(
    0xFF1976D2,
  ); // Blue accent for light mode
  static const Color aiCardAccentDark = Color(
    0xFF64B5F6,
  ); // Lighter blue for dark mode

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
    ),
    extensions: [
      ThemeColors(
        warningColor: warningColorLight,
        warningBackground: warningBackgroundLight,
      ),
    ],
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[900],
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
    ),
    extensions: [
      ThemeColors(
        warningColor: warningColorDark,
        warningBackground: warningBackgroundDark,
      ),
    ],
  );
}

// Theme extension for custom colors
class ThemeColors extends ThemeExtension<ThemeColors> {
  final Color warningColor;
  final Color warningBackground;

  const ThemeColors({
    required this.warningColor,
    required this.warningBackground,
  });

  @override
  ThemeExtension<ThemeColors> copyWith({
    Color? warningColor,
    Color? warningBackground,
  }) {
    return ThemeColors(
      warningColor: warningColor ?? this.warningColor,
      warningBackground: warningBackground ?? this.warningBackground,
    );
  }

  @override
  ThemeExtension<ThemeColors> lerp(
    ThemeExtension<ThemeColors>? other,
    double t,
  ) {
    if (other is! ThemeColors) {
      return this;
    }
    return ThemeColors(
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      warningBackground:
          Color.lerp(warningBackground, other.warningBackground, t)!,
    );
  }
}
