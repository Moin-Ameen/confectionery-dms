import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/base_model.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

const roleColors = {
  UserRole.owner: AppColors.navy,
  UserRole.manager: AppColors.purple,
  UserRole.accountant: AppColors.teal,
  UserRole.cashier: AppColors.green,
  UserRole.storekeeper: AppColors.amber,
  UserRole.booker: AppColors.blue,
  UserRole.salesman: AppColors.red,
};

class UsersView extends StatelessWidget {
  const UsersView({super.key});

  @override
  Widget build(BuildContext context) {
    final uc = context.watch<UserController>();
    final shops = context.watch<ShopController>();
    final auth = context.watch<AuthController>();
    final list = uc.users;
    return ShellPage(
      title: 'Users & Roles',
      fab: auth.can(Scr.users, PermAction.add)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserForm())),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('User'),
            )
          : null,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final u = list[i];
          return AppCard(
            onTap: auth.can(Scr.users, PermAction.edit)
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserForm(user: u)))
                : null,
            child: Row(children: [
              Avatar(u.initials, color: u.active ? roleColors[u.role]! : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '@${u.username}${u.routeId.isEmpty ? '' : ' · ${shops.routeName(u.routeId)}'}${u.vanName.isEmpty ? '' : ' · ${u.vanName}'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                StatusChip(u.role.label, color: roleColors[u.role]),
                if (!u.active) const Padding(padding: EdgeInsets.only(top: 4), child: StatusChip('disabled', color: AppColors.muted)),
                if (u.customPermissions)
                  const Padding(padding: EdgeInsets.only(top: 4), child: StatusChip('custom rights', color: AppColors.amber)),
              ]),
            ]),
          ).entrance(i);
        },
      ),
    );
  }
}

class UserForm extends StatefulWidget {
  final AppUser? user;
  const UserForm({super.key, this.user});

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  late final AppUser u;
  late final bool isNew;
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _van = TextEditingController();
  final _target = TextEditingController();
  final _cSale = TextEditingController();
  final _cRec = TextEditingController();

  @override
  void initState() {
    super.initState();
    isNew = widget.user == null;
    u = widget.user ?? AppUser(id: newId(), name: '', username: '', passwordHash: '', role: UserRole.booker);
    _name.text = u.name;
    _username.text = u.username;
    _phone.text = u.phone;
    _van.text = u.vanName;
    _target.text = u.monthlyTarget == 0 ? '' : u.monthlyTarget.toStringAsFixed(0);
    _cSale.text = u.commissionSalePct == 0 ? '' : '${u.commissionSalePct}';
    _cRec.text = u.commissionRecoveryPct == 0 ? '' : '${u.commissionRecoveryPct}';
    if (!u.customPermissions) u.permissions = defaultPermissions(u.role);
  }

  Future<void> _save() async {
    u.name = _name.text.trim();
    u.username = _username.text.trim();
    u.phone = _phone.text.trim();
    u.vanName = _van.text.trim();
    u.monthlyTarget = double.tryParse(_target.text) ?? 0;
    u.commissionSalePct = double.tryParse(_cSale.text) ?? 0;
    u.commissionRecoveryPct = double.tryParse(_cRec.text) ?? 0;
    // custom only if different from role defaults
    final def = defaultPermissions(u.role);
    u.customPermissions = !(u.permissions.length == def.length && u.permissions.containsAll(def));
    final err = await context.read<UserController>().save(u, password: _password.text, isNew: isNew);
    if (!mounted) return;
    if (handleResult(context, err, success: 'User saved')) {
      context.read<AuthController>().reloadUser();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final auth = context.watch<AuthController>();
    final isOwnerEditing = auth.user!.role == UserRole.owner;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New User' : 'Edit User'), actions: [
        if (!isNew && auth.can(Scr.users, PermAction.delete))
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Delete user', 'Delete ${u.name}? Use "Active" switch to just disable.',
                  ok: 'Delete', color: AppColors.red);
              if (!ok || !context.mounted) return;
              final err = await context.read<UserController>().delete(u);
              if (!context.mounted) return;
              if (handleResult(context, err, success: 'User deleted')) Navigator.pop(context);
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
        const Gap(),
        Row(children: [
          Expanded(child: TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username'))),
          const Gap(),
          Expanded(
            child: TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: isNew ? 'Password' : 'New password (optional)'),
            ),
          ),
        ]),
        const Gap(),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SectionTitle('Role'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in UserRole.values)
            if (r != UserRole.owner || isOwnerEditing)
              ChoiceChip(
                label: Text(r.label),
                selected: u.role == r,
                selectedColor: roleColors[r]!.withValues(alpha: 0.22),
                onSelected: (_) => setState(() {
                  u.role = r;
                  u.permissions = defaultPermissions(r);
                }),
              ),
        ]),
        if (u.role.isField) ...[
          const SectionTitle('Route, van & targets'),
          DropdownButtonFormField<String>(
            value: shops.routes.any((r) => r.id == u.routeId) ? u.routeId : '',
            decoration: const InputDecoration(labelText: 'Route'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All routes')),
              for (final r in shops.routes) DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setState(() => u.routeId = v ?? ''),
          ),
          if (u.role == UserRole.salesman) ...[
            const Gap(),
            TextField(controller: _van, decoration: const InputDecoration(labelText: 'Van no.')),
          ],
          const Gap(),
          NumField(_target, 'Monthly target (${AppConfig.currency})'),
          const Gap(),
          Row(children: [
            Expanded(child: NumField(_cSale, 'Commission on sale %')),
            const Gap(),
            Expanded(child: NumField(_cRec, 'Commission on recovery %')),
          ]),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active (can login)'),
          value: u.active,
          onChanged: (v) => setState(() => u.active = v),
        ),
        if (u.role != UserRole.owner) ...[
          SectionTitle(
            'Screen rights',
            trailing: TextButton(
              onPressed: () => setState(() => u.permissions = defaultPermissions(u.role)),
              child: const Text('Reset to role'),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 4, 8, 4),
                child: Row(children: [
                  Expanded(child: Text('Screen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  _H('View'),
                  _H('Add'),
                  _H('Edit'),
                  _H('Del'),
                  _H('Appr'),
                ]),
              ),
              for (final s in Scr.all.where((s) => s != Scr.dashboard))
                Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Row(children: [
                    Expanded(child: Text(Scr.titles[s]!, style: const TextStyle(fontSize: 12))),
                    for (final a in PermAction.all)
                      SizedBox(
                        width: 38,
                        child: Checkbox(
                          visualDensity: VisualDensity.compact,
                          value: u.permissions.contains('$s:$a'),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              u.permissions.add('$s:$a');
                              if (a != PermAction.view) u.permissions.add('$s:${PermAction.view}');
                            } else {
                              u.permissions.remove('$s:$a');
                              if (a == PermAction.view) u.permissions.removeWhere((p) => p.startsWith('$s:'));
                            }
                          }),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
        ],
        const Gap(20),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('Save user')),
      ]),
    );
  }
}

class _H extends StatelessWidget {
  final String t;
  const _H(this.t);
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 38, child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)));
}
