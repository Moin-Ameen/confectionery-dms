import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/base_controller.dart';
import '../../controllers/recovery_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../models/recovery.dart';
import '../../models/shop.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'slips_view.dart';

/// Salesman: bill-wise recovery entry → today's digital wasooli slip.
class RecoveryView extends StatefulWidget {
  const RecoveryView({super.key});

  @override
  State<RecoveryView> createState() => _RecoveryViewState();
}

class _RecoveryViewState extends State<RecoveryView> {
  RecoverySlip? _slip;

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  Future<void> _ensure() async {
    final s = await context.read<RecoveryController>().todaySlip(Session.userId);
    if (mounted) setState(() => _slip = s);
  }

  Future<void> _add(ShopController shops, RecoveryController rc) async {
    final me = context.read<AuthController>().user!;
    var list = shops.activeShops;
    if (me.routeId.isNotEmpty) {
      list = [...list.where((s) => s.routeId == me.routeId), ...list.where((s) => s.routeId != me.routeId)];
    }
    final balances = rc.accounts.allShopBalances();
    final shop = await pickFromList<Shop>(
      context,
      title: 'Recovery from shop',
      items: list,
      label: (s) => s.name,
      subtitle: (s) => '${s.khataNo} · balance ${num0(balances[s.id] ?? 0)}',
    );
    if (shop == null || !mounted) return;
    final bills = shops.pendingBills(shop.id);
    if (bills.isEmpty) {
      showSnack(context, 'No pending bills for ${shop.name}', error: true);
      return;
    }
    final bill = await pickFromList<PendingBill>(
      context,
      title: '${shop.name} – pending bills',
      items: bills,
      label: (b) => 'Bill #${b.order.invoiceNo}  ·  ${money(b.pending)}',
      subtitle: (b) => '${dateFmt(b.order.invoicedAt ?? b.order.date)} · ${b.ageDays} days old · bill ${num0(b.order.net)}',
    );
    if (bill == null || !mounted) return;
    final amt = TextEditingController(text: bill.pending.toStringAsFixed(0));
    final res = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${shop.name} · Bill #${bill.order.invoiceNo}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          Text('Khata ${shop.khataNo} · pending ${money(bill.pending)}', style: const TextStyle(color: AppColors.muted)),
          const Gap(),
          TextField(
            controller: amt,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(labelText: 'Amount recovered', prefixText: '${AppConfig.currency} '),
          ),
          const Gap(),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, 0.0), child: const Text('Nil'))),
            const Gap(),
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, bill.pending), child: const Text('Full'))),
            const Gap(),
            Expanded(
              child: FilledButton(onPressed: () => Navigator.pop(c, double.tryParse(amt.text) ?? -1), child: const Text('Add')),
            ),
          ]),
        ]),
      ),
    );
    if (res == null || !mounted) return;
    if (res < 0) {
      showSnack(context, 'Enter a valid amount', error: true);
      return;
    }
    final err = await rc.add(
      shopId: shop.id,
      orderId: bill.order.id,
      billNo: bill.order.invoiceNo,
      billAmount: bill.pending,
      amount: res,
    );
    if (mounted) handleResult(context, err, success: 'Added to today\'s slip');
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RecoveryController>();
    final shops = context.watch<ShopController>();
    final slip = _slip == null ? null : rc.slip(_slip!.id);
    if (slip == null) return const ShellPage(title: 'Recovery', body: Center(child: CircularProgressIndicator()));
    final sum = rc.summary(slip);
    final open = slip.status == SlipStatus.open;

    return ShellPage(
      title: 'Recovery Entry',
      fab: open
          ? FloatingActionButton.extended(
              onPressed: () => _add(shops, rc),
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Add recovery'),
            )
          : null,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        AppCard(
          gradient: AppColors.soft(open ? AppColors.green : (slip.status == SlipStatus.submitted ? AppColors.amber : AppColors.teal)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Today\'s Wasooli Slip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              StatusChip(slip.status, color: Colors.white),
            ]),
            const Gap(14),
            Row(children: [
              _stat('Bills', '${sum.bills}'),
              _stat('Bill amount', num0(sum.totalBill)),
              _stat('Recovered', num0(sum.totalRecovered)),
              _stat('Pending', num0(sum.pending)),
            ]),
          ]),
        ).entrance(0),
        const Gap(),
        if (sum.lines.isEmpty)
          const EmptyState(icon: Icons.payments_outlined, text: 'No recovery yet today', sub: 'Tap "Add recovery" at each shop'),
        for (var i = 0; i < sum.lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _line(context, sum.lines[i], shops, rc, open).entrance(i + 1),
          ),
        if (sum.lines.isNotEmpty && open) ...[
          const Gap(10),
          FilledButton.icon(
            icon: const Icon(Icons.outbox_rounded),
            label: const Text('Hand over cash & submit slip'),
            onPressed: () async {
              final v = await promptText(context, 'Cash handed to cashier',
                  initial: sum.totalRecovered.toStringAsFixed(0), number: true, required: true);
              if (v == null) return;
              final err = await rc.submit(slip, double.tryParse(v) ?? 0);
              if (context.mounted) handleResult(context, err, success: 'Slip submitted for approval');
            },
          ),
        ],
        if (!open) ...[
          const Gap(10),
          AppCard(
            child: Column(children: [
              KV('Cash handed', money(slip.cashHanded)),
              if (slip.status == SlipStatus.approved) KV('Cash received by cashier', money(slip.cashReceived)),
              KV(
                sum.shortExcess >= 0 ? 'Short' : 'Excess',
                money(sum.shortExcess.abs()),
                bold: true,
                color: sum.shortExcess.abs() < 0.5 ? AppColors.green : AppColors.red,
              ),
              const Gap(6),
              Text(
                slip.status == SlipStatus.submitted ? 'Waiting for cashier / admin approval' : 'Approved – shop khata updated',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ]),
          ).animate().fadeIn(),
        ],
        const Gap(),
        TextButton.icon(
          icon: const Icon(Icons.print_rounded),
          label: const Text('View / print slip'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SlipDetailView(slipId: slip.id))),
        ),
      ]),
    );
  }

  Widget _stat(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          Text(k, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );

  Widget _line(BuildContext context, Recovery r, ShopController shops, RecoveryController rc, bool open) {
    return AppCard(
      child: Row(children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: statusColor(r.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('#${r.billNo}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: statusColor(r.status))),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(shops.shopName(r.shopId), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Khata ${r.khataNo} · bill ${num0(r.billAmount)} · ${timeFmt(r.date)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(num0(r.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
          StatusChip(r.status),
        ]),
        if (open)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 20),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Remove entry', 'Remove bill #${r.billNo} from today\'s slip?');
              if (!ok) return;
              final err = await rc.remove(r);
              if (context.mounted) handleResult(context, err);
            },
          ),
      ]),
    );
  }
}
