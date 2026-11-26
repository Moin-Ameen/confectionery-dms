import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../widgets/common.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  Future<void> _login() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      showSnack(context, 'Enter username and password', error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AuthController>().login(_user.text, _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showSnack(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(children: [
        // decorative circles
        Positioned(
          top: -80,
          right: -60,
          child: _circle(220, AppColors.blue.withValues(alpha: 0.25)),
        ),
        Positioned(
          top: h * 0.18,
          left: -70,
          child: _circle(160, Colors.white.withValues(alpha: 0.06)),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: h * 0.08),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 40),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 22),
              const Text('Welcome back',
                      style: TextStyle(color: Colors.white70, fontSize: 16))
                  .animate()
                  .fadeIn(delay: 100.ms),
              const Text(AppConfig.appName,
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2))
                  .animate()
                  .fadeIn(delay: 180.ms)
                  .slideX(begin: -0.05),
              SizedBox(height: h * 0.05),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 14))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Sign in', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Use the username given by your admin', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _user,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _busy
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Text('Login'),
                    ),
                  ),
                  if (auth.isFreshInstall) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'First time? Login with  admin / 1234  and change the password from Settings.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ]),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.12, curve: Curves.easeOutCubic),
              const SizedBox(height: 26),
              const Center(child: Text(AppConfig.poweredBy, style: TextStyle(color: Colors.white54, fontSize: 12))),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _circle(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
