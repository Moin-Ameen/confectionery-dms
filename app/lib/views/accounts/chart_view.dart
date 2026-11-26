import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../models/accounts.dart';
import '../../models/base_model.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'ledgers_view.dart';

class ChartView extends StatelessWidget {
  const ChartView({super.key});

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    final auth = context.watch<AuthController>();
    final colors = {
      AccountType.asset: AppColors.teal,
      AccountType.liability: AppColors.amber,
      AccountType.equity: AppColors.purple,
      AccountType.income: AppColors.green,
      AccountType.expense: AppColors.red,
    };
    return ShellPage(
      title: 'Chart of Accounts',
      fab: auth.can(Scr.chartAccounts, PermAction.add)
          ? FloatingActionButton(onPressed: () => _edit(context, acc, null), child: const Icon(Icons.add_rounded))
          : null,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
        for (final t in AccountType.values) ...[
          SectionTitle(t.label),
          for (final (i, a) in acc.accounts.where((a) => a.type == t).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountLedgerPage(accountId: a.id))),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colors[t]!.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(a.code, style: TextStyle(fontWeight: FontWeight.w700, color: colors[t], fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (a.sysKey.isNotEmpty)
                        const Text('System account', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ]),
                  ),
                  Text(num0(acc.balance(a.id)), style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (auth.can(Scr.chartAccounts, PermAction.edit) && a.sysKey.isEmpty)
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _edit(context, acc, a)),
                ]),
              ).entrance(i),
            ),
        ],
        Center(child: Text('Balances in ${AppConfig.currency}', style: const TextStyle(fontSize: 11, color: AppColors.muted))),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, AccountsController acc, Account? existing) async {
    final isNew = existing == null;
    final a = existing ?? Account(id: newId(), code: '', name: '', type: AccountType.expense);
    final code = TextEditingController(text: a.code);
    final name = TextEditingController(text: a.name);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(isNew ? 'New account' : 'Edit account', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(),
            Row(children: [
              SizedBox(width: 100, child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Code'))),
              const Gap(),
              Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: 'Account name'))),
            ]),
            const Gap(),
            DropdownButtonFormField<AccountType>(
              value: a.type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in AccountType.values) DropdownMenuItem(value: t, child: Text(t.label))],
              onChanged: (v) => set(() => a.type = v ?? AccountType.expense),
            ),
            if (a.type == AccountType.asset)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('This is a bank account'),
                value: a.isBank,
                onChanged: (v) => set(() => a.isBank = v),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: a.active,
              onChanged: (v) => set(() => a.active = v),
            ),
            FilledButton(
              onPressed: () async {
                a.code = code.text.trim();
                a.name = name.text.trim();
                final err = await acc.saveAccount(a, isNew: isNew);
                if (!c.mounted) return;
                if (handleResult(c, err)) Navigator.pop(c);
              },
              child: const Text('Save account'),
            ),
          ]),
        ),
      ),
    );
  }
}
