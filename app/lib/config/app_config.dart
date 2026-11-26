import 'package:flutter/material.dart';

/// Global app configuration. Change branding here.
class AppConfig {
  static const String appName = 'Confectionery Distribution';
  static const String poweredBy = 'Powered by CASHLIFYPOS';
  static const String currency = 'Rs';

  /// Server for online sync (built into the APK so staff never type it).
  /// Leave empty to run fully offline. Owner can change it in Settings → Advanced.
  static const String defaultApiBaseUrl = 'https://confectionery-dms-api.onrender.com';
  static const String defaultApiToken = 'VdyvbE09iY52eRpIc5A802uUHcY4ZeYRC/w8MYowpu0=';

  /// GPS ping interval while a booker / salesman is on duty.
  static const Duration gpsInterval = Duration(minutes: 2);

  /// Auto sync interval when online.
  static const Duration syncInterval = Duration(minutes: 5);

  /// Days before expiry to raise a near-expiry alert.
  static const int nearExpiryDays = 30;
}

class AppColors {
  static const Color navy = Color(0xFF0F3460);
  static const Color navyDark = Color(0xFF0A2444);
  static const Color blue = Color(0xFF71A2FF);
  static const Color red = Color(0xFFE02027);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF0EA5C9);
  static const Color bg = Color(0xFFF4F7FC);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF1B2A41);
  static const Color muted = Color(0xFF7A8AA3);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [navy, Color(0xFF1E5AA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient soft(Color c) => LinearGradient(
        colors: [c, Color.lerp(c, Colors.white, 0.25)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
