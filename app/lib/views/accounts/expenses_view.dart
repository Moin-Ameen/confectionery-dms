import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../models/accounts.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class ExpensesView extends StatefulWidget {
  const ExpensesView({super.key});

  @override
  State<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends State<ExpensesView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    final auth = context.watch<AuthController>();
    final expIds = acc.expenseAccounts.map((a) => a.id).toSet();
    final list = acc.vouchers
        .where((v) =>
            v.date.year == _month.year &&
            v.date.month == _month.month &&
            v.lines.any((l) => expIds.contains(l.accountId) && l.debit > 0) &&
            (v.type == VoucherType.expense || v.type == VoucherType.cashPayment))
        .toList();
    final byHead = <String, double>{};
    for (final v in list) {
      for (final l in v.lines.where((l) => expIds.contains(l.accountId) && l.debit > 0)) {
        final n = acc.byId(l.accountId)?.name ?? '-';
        byHead[n] = (byHead[n] ?? 0) + l.debit;
      }
    }
    final total = byHead.values.fold(0.0, (s, v) => s + v);
    final colors = [AppColors.red, AppColors.amber, AppColors.purple, AppColors.teal, AppColors.green, AppColors.blue, AppColors.navy];

    return ShellPage(
      title: 'Expenses',
      fab: auth.can(Scr.expenses, PermAction.add)
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, acc),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Expense'),
            )
          : null,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
        MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
        const Gap(),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total expenses', style: TextStyle(color: AppColors.muted)),
            Text(money(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const Gap(12),
            if (total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(children: [
                  for (final (i, e) in byHead.entries.indexed)
                    Expanded(
                      flex: (e.value / total * 1000).round().clamp(1, 1000),
                      child: Container(height: 10, color: colors[i % colors.length]),
                    ),
                ]),
              ),
            const Gap(10),
            for (final (i, e) in byHead.entries.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key)),
                  Text(num0(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ).entrance(0),
        const SectionTitle('Entries'),
        if (list.isEmpty) const EmptyState(icon: Icons.money_off_outlined, text: 'No expenses this month'),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(children: [
                const Icon(Icons.receipt_rounded, color: AppColors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      list[i].lines.where((l) => l.debit > 0).map((l) => acc.byId(l.accountId)?.name ?? '-').join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('${dateTimeFmt(list[i].date)}${list[i].narration.isEmpty ? '' : ' · ${list[i].narration}'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                Text(num0(list[i].totalDebit), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ).entrance(i + 1),
          ),
      ]),
    );
  }

  Future<void> _add(BuildContext context, AccountsController acc) async {
    final heads = acc.expenseAccounts;
    final pay = acc.cashBankAccounts;
    String head = heads.isEmpty ? '' : heads.firstWhere((a) => a.sysKey == SysAcc.fuel, orElse: () => heads.first).id;
    String from = pay.isEmpty ? '' : pay.first.id;
    final amt = TextEditingController();
    final narr = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('New expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in heads)
                ChoiceChip(label: Text(h.name), selected: head == h.id, onSelected: (_) => set(() => head = h.id)),
            ]),
            const Gap(),
            TextField(
              controller: amt,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '${AppConfig.currency} '),
            ),
            const Gap(),
            DropdownButtonFormField<String>(
              value: from.isEmpty ? null : from,
              decoration: const InputDecoration(labelText: 'Paid from'),
              items: [for (final a in pay) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (v) => set(() => from = v ?? ''),
            ),
            const Gap(),
            TextField(controller: narr, decoration: const InputDecoration(labelText: 'Details (e.g. van KHI-1234 diesel)')),
            const Gap(16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save expense')),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final a = double.tryParse(amt.text) ?? 0;
    if (a <= 0 || head.isEmpty || from.isEmpty) {
      showSnack(context, 'Enter amount and select head', error: true);
      return;
    }
    await acc.expense(expenseAccountId: head, payFromAccountId: from, amount: a, narration: narr.text.trim());
    if (context.mounted) showSnack(context, 'Expense saved');
  }
}
