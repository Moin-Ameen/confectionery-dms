import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/report_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class SalesmanReportView extends StatefulWidget {
  const SalesmanReportView({super.key});

  @override
  State<SalesmanReportView> createState() => _SalesmanReportViewState();
}

class _SalesmanReportViewState extends State<SalesmanReportView> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final rep = context.watch<ReportController>();
    final users = context.watch<UserController>();
    final me = context.watch<AuthController>().user!;
    final list = me.role == UserRole.salesman ? [me] : users.salesmen;
    final rows = list.map((u) => rep.salesmanDay(u, _day)).toList();
    double t(double Function(SalesmanDay) f) => rows.fold(0.0, (s, r) => s + f(r));

    PrintDoc doc() => PrintDoc(
          title: 'DAILY SALESMAN REPORT',
          number: dateFmt(_day),
          date: _day,
          headers: ['Salesman', 'Invoices', 'Sale', 'Recovery', 'Returns', 'Cash handed', 'Short/Excess'],
          rows: [
            for (final r in rows)
              [
                r.user.name,
                '${r.invoices}',
                num0(r.sale),
                num0(r.recovery),
                num0(r.returns),
                num0(r.cashHanded),
                r.shortExcess.abs() < 0.5 ? '-' : '${r.shortExcess > 0 ? 'Short' : 'Excess'} ${num0(r.shortExcess.abs())}',
              ]
          ],
          totals: [
            MapEntry('Total sale', money(t((r) => r.sale))),
            MapEntry('Total recovery', money(t((r) => r.recovery))),
            MapEntry('Total returns', money(t((r) => r.returns))),
            MapEntry('Cash handed over', money(t((r) => r.cashHanded))),
          ],
        );

    return ShellPage(
      title: 'Salesman Daily Report',
      actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(doc(), 'salesman_report_${dateFmt(_day)}.pdf', landscape: true),
          onPrint: () => PdfService.instance.printDoc(doc(), landscape: true),
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
        const Gap(),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            StatCard(title: 'Sale', value: money(t((r) => r.sale)), icon: Icons.trending_up_rounded, color: AppColors.navy),
            StatCard(title: 'Recovery', value: money(t((r) => r.recovery)), icon: Icons.payments_rounded, color: AppColors.green),
            StatCard(title: 'Returns', value: money(t((r) => r.returns)), icon: Icons.assignment_return_rounded, color: AppColors.purple),
            StatCard(title: 'Cash handed', value: money(t((r) => r.cashHanded)), icon: Icons.account_balance_wallet_rounded, color: AppColors.teal),
          ].asMap().entries.map((e) => e.value.entrance(e.key)).toList(),
        ),
        const SectionTitle('By salesman'),
        if (rows.isEmpty) const EmptyState(text: 'No salesmen'),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(children: [
                Row(children: [
                  Avatar(rows[i].user.initials, color: AppColors.teal, size: 38),
                  const SizedBox(width: 10),
                  Expanded(child: Text(rows[i].user.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  StatusChip(rows[i].slipStatus == '-' ? 'no slip' : rows[i].slipStatus),
                ]),
                const Gap(10),
                KV('Invoices', '${rows[i].invoices}'),
                KV('Sale', money(rows[i].sale)),
                KV('Recovery', money(rows[i].recovery)),
                KV('Returns', money(rows[i].returns)),
                KV('Cash handed over', money(rows[i].cashHanded)),
                KV(
                  rows[i].shortExcess >= 0 ? 'Short' : 'Excess',
                  money(rows[i].shortExcess.abs()),
                  bold: true,
                  color: rows[i].shortExcess.abs() < 0.5 ? AppColors.green : AppColors.red,
                ),
              ]),
            ).entrance(i + 4),
          ),
        Center(child: Text('Amounts in ${AppConfig.currency}', style: const TextStyle(fontSize: 11, color: AppColors.muted))),
      ]),
    );
  }
}
