import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/sync_controller.dart';
import '../../controllers/tracking_controller.dart';
import '../../models/user.dart';
import '../widgets/common.dart';
import '../widgets/update_sheet.dart';
import 'screen_registry.dart';
import 'shell_page.dart';

/// Current screen of the shell; any view can switch it with `openScreen(key)`.
final currentScreen = ValueNotifier<String>(Scr.dashboard);

void openScreen(String key) => currentScreen.value = key;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    currentScreen.value = Scr.dashboard;
    // check for a new app version shortly after login
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    if (user == null) return const Scaffold(); // logging out (during transition)
    final allowed = screens.where((s) => auth.can(s.key)).toList();
    final quick = quickScreens(user.role).where((k) => auth.can(k)).toList();

    return ValueListenableBuilder<String>(
      valueListenable: currentScreen,
      builder: (context, key, _) {
        if (!allowed.any((s) => s.key == key)) key = Scr.dashboard;
        final def = screenOf(key);
        final navIndex = quick.indexOf(key);
        return PopScope(
          canPop: key == Scr.dashboard,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) openScreen(Scr.dashboard);
          },
          child: Scaffold(
            key: shellScaffoldKey,
            drawer: _Drawer(allowed: allowed, current: key),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(key), child: def.builder()),
            ),
            bottomNavigationBar: quick.length < 2
                ? null
                : NavigationBar(
                    height: 68,
                    selectedIndex: navIndex < 0 ? quick.length : navIndex,
                    indicatorColor: AppColors.blue.withValues(alpha: 0.22),
                    onDestinationSelected: (i) {
                      if (i == quick.length) {
                        shellScaffoldKey.currentState?.openDrawer();
                      } else {
                        openScreen(quick[i]);
                      }
                    },
                    destinations: [
                      for (final k in quick)
                        NavigationDestination(
                          icon: Icon(screenOf(k).icon),
                          label: _short(screenOf(k).title),
                        ),
                      const NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'More'),
                    ],
                  ),
          ),
        );
      },
    );
  }

  String _short(String t) => t.split(' ').first.replaceAll('&', '').trim();
}

class _Drawer extends StatelessWidget {
  final List<ScreenDef> allowed;
  final String current;
  const _Drawer({required this.allowed, required this.current});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final sync = context.watch<SyncController>();
    final user = auth.user!;
    final groups = <String, List<ScreenDef>>{};
    for (final s in allowed) {
      groups.putIfAbsent(s.group, () => []).add(s);
    }

    return Drawer(
      width: 300,
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 18),
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(user.initials, color: AppColors.blue, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                  Text(user.role.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Icon(
                sync.configured ? (sync.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded) : Icons.phone_android_rounded,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sync.configured
                      ? (sync.online ? 'Online · ${sync.pendingChanges} to sync' : 'Offline · ${sync.pendingChanges} pending')
                      : 'Offline mode (this phone)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ]),
            if (user.role.isField) const _DutySwitch(),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 16, 4),
                  child: Text(g.key.toUpperCase(),
                      style: const TextStyle(fontSize: 11, letterSpacing: 0.8, color: AppColors.muted, fontWeight: FontWeight.w700)),
                ),
                for (final s in g.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ListTile(
                      dense: true,
                      selected: s.key == current,
                      selectedTileColor: AppColors.blue.withValues(alpha: 0.14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(s.icon, size: 22),
                      title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        openScreen(s.key);
                      },
                    ),
                  ),
              ],
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.red),
                  title: const Text('Logout', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () async {
                    final ok = await confirmDialog(context, 'Logout', 'Do you want to logout?', ok: 'Logout');
                    if (!ok || !context.mounted) return;
                    context.read<TrackingController>().stop();
                    await context.read<AuthController>().logout();
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(AppConfig.poweredBy, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _DutySwitch extends StatelessWidget {
  const _DutySwitch();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackingController>();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(t.onDuty ? Icons.gps_fixed_rounded : Icons.gps_off_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(t.onDuty ? 'On duty · GPS on' : 'Off duty',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        Switch(
          value: t.onDuty,
          activeColor: AppColors.green,
          onChanged: (v) async {
            final err = await t.setDuty(v);
            if (err != null && context.mounted) showSnack(context, err, error: true);
          },
        ),
      ]),
    );
  }
}
