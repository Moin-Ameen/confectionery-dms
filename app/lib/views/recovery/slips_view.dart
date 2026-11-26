import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/recovery_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/recovery.dart';
import '../../models/user.dart';
import '../../services/bt_printer_service.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class SlipsView extends StatelessWidget {
  const SlipsView({super.key});

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RecoveryController>();
    final auth = context.watch<AuthController>();
    final me = auth.user!;
    var slips = rc.slips;
    if (me.role.isField) slips = slips.where((s) => s.salesmanId == me.id).toList();
    final tabs = [
      (SlipStatus.submitted, 'To approve'),
      (SlipStatus.open, 'Open'),
      (SlipStatus.approved, 'Approved'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: ShellPage(
        title: 'Daily Recovery Slips',
        bottom: TabBar(tabs: [for (final t in tabs) Tab(text: '${t.$2} (${slips.where((s) => s.status == t.$1).length})')]),
        body: TabBarView(children: [
          for (final t in tabs) _list(context, rc, slips.where((s) => s.status == t.$1).toList()),
        ]),
      ),
    );
  }

  Widget _list(BuildContext context, RecoveryController rc, List<RecoverySlip> list) {
    final users = context.watch<UserController>();
    if (list.isEmpty) return const EmptyState(icon: Icons.fact_check_outlined, text: 'No slips');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = list[i];
        final sum = rc.summary(s);
        final diff = sum.shortExcess;
        return AppCard(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SlipDetailView(slipId: s.id))),
          child: Column(children: [
            Row(children: [
              Avatar(users.byId(s.salesmanId)?.initials ?? '?', color: AppColors.teal, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(users.nameOf(s.salesmanId), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${dateFmt(DateTime.parse(s.day))} · ${sum.bills} bills', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              StatusChip(s.status),
            ]),
            const Gap(10),
            Row(children: [
              _cell('Bill amount', num0(sum.totalBill)),
              _cell('Recovered', num0(sum.totalRecovered)),
              _cell('Cash', s.status == SlipStatus.open ? '-' : num0(sum.cash)),
              _cell(
                diff >= 0 ? 'Short' : 'Excess',
                s.status == SlipStatus.open ? '-' : num0(diff.abs()),
                color: s.status != SlipStatus.open && diff.abs() > 0.5 ? AppColors.red : AppColors.green,
              ),
            ]),
          ]),
        ).entrance(i);
      },
    );
  }

  Widget _cell(String k, String v, {Color? color}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          Text(k, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      );
}

class SlipDetailView extends StatelessWidget {
  final String slipId;
  const SlipDetailView({super.key, required this.slipId});

  PrintDoc _doc(SlipSummary sum, UserController users, ShopController shops) {
    final s = sum.slip;
    return PrintDoc(
      title: 'BAZAR WASOOLI SLIP',
      number: s.day,
      date: s.submittedAt ?? DateTime.now(),
      partyLines: [
        'Salesman: ${users.nameOf(s.salesmanId)}',
        'Route: ${shops.routeName(users.byId(s.salesmanId)?.routeId ?? '')}',
        'Status: ${s.status.toUpperCase()}',
      ],
      headers: ['Shop', 'Bill No.', 'Khata No.', 'Bill Amount', 'Recovered', 'Status'],
      rows: [
        for (final r in sum.lines)
          [shops.shopName(r.shopId), '${r.billNo}', r.khataNo, num0(r.billAmount), num0(r.amount), r.status],
      ],
      totals: [
        MapEntry('Total (${sum.bills} bills)', money(sum.totalBill)),
        MapEntry('Recovered', money(sum.totalRecovered)),
        MapEntry('Pending', money(sum.pending)),
        if (s.status != SlipStatus.open) MapEntry('Cash handed', money(s.cashHanded)),
        if (s.status == SlipStatus.approved) MapEntry('Cash received', money(s.cashReceived)),
        if (s.status != SlipStatus.open)
          MapEntry(sum.shortExcess >= 0 ? 'Short' : 'Excess', money(sum.shortExcess.abs())),
        if (s.status == SlipStatus.approved) MapEntry('Approved by', users.nameOf(s.approvedBy)),
      ],
      note: s.note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RecoveryController>();
    final users = context.watch<UserController>();
    final shops = context.watch<ShopController>();
    final auth = context.watch<AuthController>();
    final s = rc.slip(slipId);
    if (s == null) return const Scaffold(body: EmptyState(text: 'Slip not found'));
    final sum = rc.summary(s);
    final canApprove = auth.can(Scr.slips, PermAction.approve) && s.status == SlipStatus.submitted;

    return Scaffold(
      appBar: AppBar(title: const Text('Wasooli Slip'), actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(_doc(sum, users, shops), 'wasooli_${s.day}.pdf'),
          onPrint: () => PdfService.instance.printDoc(_doc(sum, users, shops)),
          onBluetooth: () async {
            final err = await BtPrinterService.instance.printDoc(_doc(sum, users, shops));
            if (context.mounted) handleResult(context, err, success: 'Sent to printer');
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          gradient: AppColors.primaryGradient,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(users.nameOf(s.salesmanId), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Date ${dateFmt(DateTime.parse(s.day))}', style: const TextStyle(color: Colors.white70)),
            const Gap(8),
            StatusChip(s.status, color: Colors.white),
          ]),
        ).entrance(0),
        const Gap(),
        // Slip table
        AppCard(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingRowHeight: 38,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('Shop')),
                DataColumn(label: Text('Bill')),
                DataColumn(label: Text('Khata')),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Recovered'), numeric: true),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final r in sum.lines)
                  DataRow(cells: [
                    DataCell(Text(shops.shopName(r.shopId))),
                    DataCell(Text('${r.billNo}')),
                    DataCell(Text(r.khataNo)),
                    DataCell(Text(num0(r.billAmount))),
                    DataCell(Text(num0(r.amount))),
                    DataCell(StatusChip(r.status)),
                  ]),
                DataRow(
                  color: WidgetStatePropertyAll(AppColors.blue.withValues(alpha: 0.08)),
                  cells: [
                    DataCell(Text('Total (${sum.bills} bills)', style: const TextStyle(fontWeight: FontWeight.w700))),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(Text(num0(sum.totalBill), style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(num0(sum.totalRecovered), style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text('Pending ${num0(sum.pending)}', style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Gap(),
        AppCard(
          child: Column(children: [
            KV('Total recovered', money(sum.totalRecovered)),
            KV('Cash handed by salesman', s.status == SlipStatus.open ? '-' : money(s.cashHanded)),
            if (s.status == SlipStatus.approved) KV('Cash received (counted)', money(s.cashReceived)),
            if (s.status != SlipStatus.open)
              KV(sum.shortExcess >= 0 ? 'Short' : 'Excess', money(sum.shortExcess.abs()),
                  bold: true, color: sum.shortExcess.abs() < 0.5 ? AppColors.green : AppColors.red),
            if (s.status == SlipStatus.approved)
              KV('Approved by', '${users.nameOf(s.approvedBy)} · ${s.approvedAt == null ? '' : dateTimeFmt(s.approvedAt!)}'),
          ]),
        ),
        if (canApprove) ...[
          const Gap(20),
          FilledButton.icon(
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Count cash & approve'),
            onPressed: () async {
              final v = await promptText(context, 'Cash counted (${AppConfig.currency})',
                  initial: s.cashHanded.toStringAsFixed(0), number: true, required: true);
              if (v == null || !context.mounted) return;
              final received = double.tryParse(v) ?? 0;
              final diff = sum.totalRecovered - received;
              if (diff.abs() > 0.5) {
                final ok = await confirmDialog(context, diff > 0 ? 'Cash short' : 'Cash excess',
                    '${diff > 0 ? 'Short' : 'Excess'} of ${money(diff.abs())} will be recorded${diff > 0 ? ' against the salesman' : ''}. Approve?',
                    ok: 'Approve', color: AppColors.amber);
                if (!ok) return;
              }
              final err = await rc.approve(s, received);
              if (context.mounted) handleResult(context, err, success: 'Slip approved – khata updated');
            },
          ),
          const Gap(8),
          OutlinedButton(
            onPressed: () async {
              final err = await rc.reopen(s);
              if (context.mounted) handleResult(context, err, success: 'Slip sent back to salesman');
            },
            child: const Text('Send back for correction'),
          ),
        ],
      ]),
    );
  }
}
