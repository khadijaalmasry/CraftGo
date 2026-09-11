import 'package:flutter/material.dart';

class AppPalette {
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldBrightLight = Color(0xFFFFEC8B);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color navy = Color(0xFF0D1B33);
  static const Color navyLight = Color(0xFF1B3A66);

  static Color background(bool isDark) =>
      isDark ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  static Color primaryText(bool isDark) =>
      isDark ? Colors.white : Colors.black87;

  static Color secondaryText(bool isDark) =>
      isDark ? Colors.white70 : Colors.black54;

  static Color topButtonBackground(bool isDark) =>
      isDark ? const Color(0xFF1C2431) : Colors.white;

  static Color topIconColor(bool isDark) =>
      isDark ? Colors.white : Colors.black87;

  static Color borderColor(bool isDark) =>
      isDark ? Colors.white12 : Colors.black12;

  static Color cardBorderColor(bool isDark) =>
      isDark ? Colors.white24 : Colors.black26;

  static Color loginButtonColor(bool isDark) => isDark ? goldBright : navy;

  static List<Color> signUpGradient(bool isDark) =>
      isDark ? [goldBrightLight, goldBright] : [navyLight, navy];

  static Color signUpTextColor(bool isDark) =>
      isDark ? Colors.black : Colors.white;

  static List<Color> logoShimmer(bool isDark) => isDark
      ? [goldBright, goldBrightLight, Colors.white, goldBrightLight, goldBright]
      : [goldDark, goldBright, Colors.white, goldBright, goldDark];

  static Color accent(bool isDark) => isDark ? goldBright : navy;

  // Common gradients used in the app
  static Gradient goldButtonGradient() => const LinearGradient(
        colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
      );

  // Input helpers
  static Color inputBackground(bool isDark) =>
      isDark ? const Color(0x0DFFFFFF) : Colors.white;
  static Color inputBorder(bool isDark) =>
      isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);
}
