import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'config/theme.dart';
import 'controllers/auth_controller.dart';
import 'services/settings_service.dart';
import 'views/auth/login_view.dart';
import 'views/shell/home_shell.dart';

/// Lets the settings screen flip dark mode instantly.
final themeMode = ValueNotifier<ThemeMode>(SettingsService.instance.darkMode ? ThemeMode.dark : ThemeMode.light);

class DistributionApp extends StatelessWidget {
  const DistributionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: Consumer<AuthController>(
          builder: (_, auth, __) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            child: auth.loggedIn ? const HomeShell(key: ValueKey('home')) : const LoginView(key: ValueKey('login')),
          ),
        ),
      ),
    );
  }
}
