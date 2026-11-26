import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../models/accounts.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'vouchers_view.dart';

class CashBookView extends StatefulWidget {
  const CashBookView({super.key});

  @override
  State<CashBookView> createState() => _CashBookViewState();
}

class _CashBookViewState extends State<CashBookView> {
  DateTime _day = DateTime.now();
  String _accountId = '';

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AccountsController>();
    final auth = context.watch<AuthController>();
    final cashAccounts = acc.cashBankAccounts;
    if (_accountId.isEmpty && cashAccounts.isNotEmpty) _accountId = cashAccounts.first.id;
    final start = DateTime(_day.year, _day.month, _day.day);
    final end = start.add(const Duration(days: 1));
    final rows = acc.ledger(accountId: _accountId, from: start, to: end);
    final opening = rows.isEmpty ? 0.0 : rows.first.balance;
    final entries = rows.skip(1).toList();
    final receipts = entries.fold(0.0, (s, r) => s + r.debit);
    final payments = entries.fold(0.0, (s, r) => s + r.credit);
    final closing = opening + receipts - payments;
    final accName = acc.byId(_accountId)?.name ?? 'Cash';

    PrintDoc doc() => PrintDoc(
          title: 'CASH BOOK',
          number: dateFmt(_day),
          date: _day,
          partyLines: [accName],
          headers: ['Time', 'Voucher', 'Narration', 'Receipt', 'Payment', 'Balance'],
          rows: [
            ['', '', 'Opening balance', '', '', num0(opening)],
            for (final r in entries)
              [timeFmt(r.date), '${r.voucherType} #${r.voucherNo}', r.narration, r.debit == 0 ? '' : num0(r.debit),
                r.credit == 0 ? '' : num0(r.credit), num0(r.balance)],
          ],
          totals: [
            MapEntry('Opening', money(opening)),
            MapEntry('Receipts', money(receipts)),
            MapEntry('Payments', money(payments)),
            MapEntry('Closing', money(closing)),
          ],
        );

    return ShellPage(
      title: 'Cash Book',
      actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(doc(), 'cashbook_${dateFmt(_day)}.pdf'),
          onPrint: () => PdfService.instance.printDoc(doc()),
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
        const Gap(),
        if (cashAccounts.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<String>(
              segments: [for (final a in cashAccounts) ButtonSegment(value: a.id, label: Text(a.name, overflow: TextOverflow.ellipsis))],
              selected: {_accountId},
              onSelectionChanged: (s) => setState(() => _accountId = s.first),
            ),
          ),
        AppCard(
          gradient: AppColors.primaryGradient,
          child: Column(children: [
            Row(children: [
              _big('Opening', opening),
              _big('Closing', closing),
            ]),
            const Gap(12),
            Row(children: [
              _small('Receipts', receipts, AppColors.green),
              _small('Payments', payments, AppColors.red),
            ]),
          ]),
        ).entrance(0),
        if (auth.can(Scr.cashbook, PermAction.add)) ...[
          const Gap(),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                icon: const Icon(Icons.south_west_rounded),
                label: const Text('Cash in'),
                onPressed: () => _quick(context, acc, true),
              ),
            ),
            const Gap(),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                icon: const Icon(Icons.north_east_rounded),
                label: const Text('Cash out'),
                onPressed: () => _quick(context, acc, false),
              ),
            ),
          ]),
        ],
        const SectionTitle('Entries'),
        if (entries.isEmpty) const EmptyState(icon: Icons.menu_book_outlined, text: 'No cash entries on this day'),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(entries[i].debit > 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                    color: entries[i].debit > 0 ? AppColors.green : AppColors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entries[i].narration.isEmpty ? entries[i].voucherType : entries[i].narration,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${timeFmt(entries[i].date)} · ${entries[i].voucherType} #${entries[i].voucherNo}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
                Text(num0(entries[i].debit > 0 ? entries[i].debit : entries[i].credit),
                    style: TextStyle(fontWeight: FontWeight.w700, color: entries[i].debit > 0 ? AppColors.green : AppColors.red)),
              ]),
            ).entrance(i + 1),
          ),
        const Gap(),
        TextButton.icon(
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Full voucher entry'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherForm(type: VoucherType.cashPayment))),
        ),
      ]),
    );
  }

  Widget _big(String k, double v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          FittedBox(child: Text(money(v), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _small(String k, double v, Color c) => Expanded(
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$k ${num0(v)}', style: const TextStyle(color: Colors.white)),
        ]),
      );

  /// Quick cash in / out: the other side is any non-cash account.
  Future<void> _quick(BuildContext context, AccountsController acc, bool cashIn) async {
    final others = acc.accounts.where((a) => a.id != _accountId && a.active && a.sysKey != SysAcc.receivable && a.sysKey != SysAcc.payable && a.sysKey != SysAcc.salesmanRecv).toList();
    String other = '';
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
            Text(cashIn ? 'Cash in' : 'Cash out', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
              isExpanded: true,
              decoration: InputDecoration(labelText: cashIn ? 'Received from (account)' : 'Paid for (account)'),
              items: [for (final a in others) DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.name}'))],
              onChanged: (v) => set(() => other = v ?? ''),
            ),
            const Gap(),
            TextField(controller: narr, decoration: const InputDecoration(labelText: 'Narration')),
            const Gap(16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
            const Gap(6),
            const Text('For shop / company / salesman payments use "Full voucher entry" to select the party.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final a = double.tryParse(amt.text) ?? 0;
    if (a <= 0 || other.isEmpty) {
      showSnack(context, 'Enter amount and account', error: true);
      return;
    }
    await acc.post(
      type: cashIn ? VoucherType.cashReceipt : VoucherType.cashPayment,
      narration: narr.text.trim(),
      date: DateTime(_day.year, _day.month, _day.day, DateTime.now().hour, DateTime.now().minute),
      auto: false,
      lines: [
        VoucherLine(accountId: cashIn ? _accountId : other, debit: a),
        VoucherLine(accountId: cashIn ? other : _accountId, credit: a),
      ],
    );
    await acc.log('created', cashIn ? 'Cash Receipt' : 'Cash Payment', details: '${narr.text} ${a.toStringAsFixed(0)}');
    acc.changed();
    if (context.mounted) showSnack(context, 'Saved');
  }
}
