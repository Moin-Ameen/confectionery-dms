import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/report_controller.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class CommissionView extends StatefulWidget {
  const CommissionView({super.key});

  @override
  State<CommissionView> createState() => _CommissionViewState();
}

class _CommissionViewState extends State<CommissionView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final rep = context.watch<ReportController>();
    final acc = context.watch<AccountsController>();
    final me = context.watch<AuthController>().user!;
    final rows = rep.commission(_month);
    final total = rows.fold(0.0, (s, r) => s + r.total);
    final label = DateFormat('MMMM yyyy').format(_month);

    PrintDoc doc() => PrintDoc(
          title: 'COMMISSION',
          number: label,
          headers: ['Name', 'Sale', 'Sale %', 'Recovery', 'Recovery %', 'Commission'],
          rows: [
            for (final r in rows)
              [
                r.user.name,
                num0(r.sale),
                num2(r.user.commissionSalePct),
                num0(r.recovery),
                num2(r.user.commissionRecoveryPct),
                num0(r.total),
              ]
          ],
          totals: [MapEntry('Total commission', money(total))],
        );

    return ShellPage(
      title: 'Commission',
      actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(doc(), 'commission.pdf'),
          onPrint: () => PdfService.instance.printDoc(doc()),
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        MonthBar(month: _month, onChanged: (m) => setState(() => _month = m)),
        const Gap(),
        AppCard(
          gradient: AppColors.soft(AppColors.purple),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total commission · $label', style: const TextStyle(color: Colors.white70)),
            Text(money(total), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          ]),
        ).entrance(0),
        const Gap(),
        if (rows.isEmpty) const EmptyState(text: 'No bookers / salesmen'),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(children: [
                Row(children: [
                  Avatar(rows[i].user.initials, color: AppColors.purple, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rows[i].user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(rows[i].user.role.label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                  Text(money(rows[i].total), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const Gap(8),
                KV('Sale ${num0(rows[i].sale)} × ${num2(rows[i].user.commissionSalePct)}%', num0(rows[i].saleCommission)),
                KV('Recovery ${num0(rows[i].recovery)} × ${num2(rows[i].user.commissionRecoveryPct)}%',
                    num0(rows[i].recoveryCommission)),
                if (me.role == UserRole.owner && rows[i].total > 0) ...[
                  const Gap(6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.payments_rounded, size: 18),
                      label: const Text('Pay from cash'),
                      onPressed: () async {
                        final ok = await confirmDialog(context, 'Pay commission',
                            'Pay ${money(rows[i].total)} to ${rows[i].user.name} for $label from cash?');
                        if (!ok) return;
                        await acc.postCommission(
                          salesmanId: rows[i].user.id,
                          amount: rows[i].total,
                          payFrom: acc.cashBankAccounts.first.id,
                          narration: 'Commission $label – ${rows[i].user.name}',
                        );
                        if (context.mounted) showSnack(context, 'Commission paid & posted');
                      },
                    ),
                  ),
                ],
              ]),
            ).entrance(i + 1),
          ),
        const Gap(),
        Text('Commission % is set per user in Users & Roles. Amounts in ${AppConfig.currency}.',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}
