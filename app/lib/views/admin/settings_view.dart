import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/demo_seeder.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../models/user.dart';
import '../../services/bt_printer_service.dart';
import '../../services/settings_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final s = SettingsService.instance;
  late final _name = TextEditingController(text: s.businessName);
  late final _addr = TextEditingController(text: s.businessAddress);
  late final _phone = TextEditingController(text: s.businessPhone);
  late final _footer = TextEditingController(text: s.invoiceFooter);
  late final _url = TextEditingController(text: s.apiBaseUrl);
  late final _token = TextEditingController(text: s.apiToken);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final sync = context.watch<SyncController>();
    final me = auth.user!;
    final isOwner = me.role == UserRole.owner;
    final canEdit = isOwner || me.role == UserRole.manager;

    return ShellPage(
      title: 'Settings & Sync',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        // ---- Profile ----
        AppCard(
          gradient: AppColors.primaryGradient,
          child: Row(children: [
            Avatar(me.initials, color: AppColors.blue, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text('@${me.username} · ${me.role.label}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            TextButton(
              onPressed: () => _changePassword(context, auth),
              child: const Text('Password', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ).entrance(0),

        // ---- Sync ----
        const SectionTitle('Online sync'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(
                !sync.configured ? Icons.phone_android_rounded : (sync.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded),
                color: sync.online && sync.configured ? AppColors.green : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(!sync.configured ? 'Offline mode (data on this phone)' : (sync.online ? 'Online' : 'No internet'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${sync.pendingChanges} changes waiting · last sync ${sync.lastSyncAt == null ? 'never' : dateTimeFmt(sync.lastSyncAt!)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  if (sync.lastMessage.isNotEmpty) Text(sync.lastMessage, style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ]),
            const Gap(),
            FilledButton.icon(
              icon: sync.syncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_rounded),
              label: const Text('Sync now'),
              onPressed: sync.syncing ? null : () => sync.syncNow(),
            ),
            const Gap(8),
            const Text(
              'Data saves on the phone and syncs automatically whenever internet is available.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            // Server details are built into the app; only the owner can see / change them.
            if (isOwner)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced (server)', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  children: [
                    TextField(controller: _url, decoration: const InputDecoration(labelText: 'Server URL')),
                    const Gap(),
                    TextField(controller: _token, obscureText: true, decoration: const InputDecoration(labelText: 'API token')),
                    const Gap(),
                    OutlinedButton(
                      onPressed: () {
                        sync.saveServer(_url.text, _token.text);
                        showSnack(context, 'Server saved');
                      },
                      child: const Text('Save server'),
                    ),
                  ],
                ),
              ),
          ]),
        ),

        // ---- Business ----
        if (canEdit) ...[
          const SectionTitle('Business details (on invoices)'),
          AppCard(
            child: Column(children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Business name')),
              const Gap(),
              TextField(controller: _addr, decoration: const InputDecoration(labelText: 'Address')),
              const Gap(),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
              const Gap(),
              TextField(controller: _footer, decoration: const InputDecoration(labelText: 'Invoice footer')),
              const Gap(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    s.businessName = _name.text.trim();
                    s.businessAddress = _addr.text.trim();
                    s.businessPhone = _phone.text.trim();
                    s.invoiceFooter = _footer.text.trim();
                    showSnack(context, 'Business details saved');
                    setState(() {});
                  },
                  child: const Text('Save details'),
                ),
              ),
            ]),
          ),
        ],

        // ---- Printer ----
        const SectionTitle('Bluetooth printer'),
        AppCard(
          onTap: () => _pickPrinter(context),
          child: Row(children: [
            const Icon(Icons.print_rounded, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.printerName.isEmpty ? 'No printer selected' : s.printerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Text('Pair the printer in phone Bluetooth settings first', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),

        // ---- Appearance ----
        const SectionTitle('Appearance'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SwitchListTile(
            title: const Text('Dark mode'),
            secondary: const Icon(Icons.dark_mode_rounded),
            value: s.darkMode,
            onChanged: (v) {
              s.darkMode = v;
              themeMode.value = v ? ThemeMode.dark : ThemeMode.light;
              setState(() {});
            },
          ),
        ),

        // ---- Demo ----
        if (isOwner) ...[
          const SectionTitle('Demo data'),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text(
                'Loads sample routes, shops, products, stock and one user for every role (password 1234: manager, accountant, cashier, store, booker, salesman).',
                style: TextStyle(fontSize: 12),
              ),
              const Gap(),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Load demo data'),
                onPressed: () async {
                  final ok = await confirmDialog(context, 'Load demo data', 'Only use this on a fresh install. Continue?');
                  if (!ok || !context.mounted) return;
                  final err = await DemoSeeder(context.read<InventoryController>(), context.read<ShopController>()).run();
                  if (context.mounted) handleResult(context, err, success: 'Demo data loaded');
                },
              ),
            ]),
          ),
        ],
        const Gap(24),
        const Center(child: Text('${AppConfig.appName} v1.0.0', style: TextStyle(color: AppColors.muted, fontSize: 12))),
        const Center(child: Text(AppConfig.poweredBy, style: TextStyle(color: AppColors.muted, fontSize: 11))),
      ]),
    );
  }

  Future<void> _pickPrinter(BuildContext context) async {
    final list = await BtPrinterService.instance.pairedDevices();
    if (!context.mounted) return;
    if (list.isEmpty) {
      showSnack(context, 'No paired Bluetooth printers. Turn on Bluetooth and pair the printer.', error: true);
      return;
    }
    final d = await pickFromList<BtDevice>(context, title: 'Select printer', items: list, label: (d) => d.name, subtitle: (d) => d.mac);
    if (d == null) return;
    s.printerMac = d.mac;
    s.printerName = d.name;
    setState(() {});
  }

  Future<void> _changePassword(BuildContext context, AuthController auth) async {
    final oldP = TextEditingController();
    final newP = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: oldP, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          const Gap(),
          TextField(controller: newP, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Change')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await auth.changePassword(oldP.text, newP.text);
    if (context.mounted) handleResult(context, err, success: 'Password changed');
  }
}
