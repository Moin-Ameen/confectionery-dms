import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'order_docs.dart';
import 'orders_view.dart';

class DeliveryView extends StatefulWidget {
  const DeliveryView({super.key});

  @override
  State<DeliveryView> createState() => _DeliveryViewState();
}

class _DeliveryViewState extends State<DeliveryView> {
  String _salesman = '';

  @override
  Widget build(BuildContext context) {
    final oc = context.watch<OrderController>();
    final users = context.watch<UserController>();
    final auth = context.watch<AuthController>();
    final me = auth.user!;
    final isSalesman = me.role == UserRole.salesman;
    if (isSalesman) _salesman = me.id;
    if (_salesman.isEmpty && users.salesmen.isNotEmpty) _salesman = users.salesmen.first.id;
    final pending = _salesman.isEmpty ? <SaleOrder>[] : oc.deliveriesFor(_salesman);
    final today = _salesman.isEmpty ? <SaleOrder>[] : oc.invoicesOn(DateTime.now(), salesmanId: _salesman);

    return ShellPage(
      title: 'Delivery & Invoice',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (!isSalesman)
          DropdownButtonFormField<String>(
            value: _salesman.isEmpty ? null : _salesman,
            decoration: const InputDecoration(labelText: 'Salesman'),
            items: [for (final s in users.salesmen) DropdownMenuItem(value: s.id, child: Text(s.name))],
            onChanged: (v) => setState(() => _salesman = v ?? ''),
          ),
        const Gap(),
        Row(children: [
          Expanded(
            child: StatCard(
                title: 'To deliver', value: '${pending.length}', icon: Icons.delivery_dining_rounded, color: AppColors.teal),
          ),
          const Gap(),
          Expanded(
            child: StatCard(
                title: 'Invoiced today',
                value: money(today.fold(0.0, (s, o) => s + o.net)),
                icon: Icons.receipt_rounded,
                color: AppColors.green),
          ),
        ]).entrance(0),
        SectionTitle('Orders on van (${pending.length})'),
        if (pending.isEmpty)
          const EmptyState(icon: Icons.local_shipping_outlined, text: 'Nothing to deliver', sub: 'Orders appear here after the load sheet'),
        for (var i = 0; i < pending.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrderCard(
              order: pending[i],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryEditView(orderId: pending[i].id))),
            ).entrance(i + 1),
          ),
        if (today.isNotEmpty) ...[
          SectionTitle('Invoiced today (${today.length})'),
          for (final o in today) Padding(padding: const EdgeInsets.only(bottom: 10), child: OrderCard(order: o)),
        ],
      ]),
    );
  }
}

/// Salesman edits quantity / removes items at the shop, then generates the final invoice.
class DeliveryEditView extends StatefulWidget {
  final String orderId;
  const DeliveryEditView({super.key, required this.orderId});

  @override
  State<DeliveryEditView> createState() => _DeliveryEditViewState();
}

class _DeliveryEditViewState extends State<DeliveryEditView> {
  SaleOrder? _o;
  final Map<String, int> _qty = {};
  final _reason = TextEditingController();
  final _disc = TextEditingController();
  bool _busy = false;

  void _load(OrderController oc) {
    _o = oc.byId(widget.orderId);
    _qty.clear();
    for (final i in _o?.items ?? <OrderItem>[]) {
      _qty[i.productId] = i.qty;
    }
  }

  bool get _changed {
    final o = _o;
    if (o == null) return false;
    for (final i in o.items) {
      if ((_qty[i.productId] ?? 0) != i.qty) return true;
    }
    return false;
  }

  List<OrderItem> _newItems(OrderController oc, InventoryController inv) {
    final out = <OrderItem>[];
    _qty.forEach((pid, q) {
      if (q <= 0) return;
      final orig = _o!.items.firstWhere((i) => i.productId == pid);
      if (q == orig.qty) {
        out.add(orig.copy());
      } else {
        final p = inv.product(pid);
        final it = p == null ? orig.copy() : oc.buildItem(p, q);
        it.rate = orig.rate; // keep booked rate
        if (q != orig.qty && p == null) it.qty = q;
        out.add(it);
      }
    });
    return out;
  }

  Future<void> _saveChanges(OrderController oc, InventoryController inv) async {
    if (_reason.text.trim().isEmpty) {
      final r = await promptText(context, 'Reason for change', hint: 'e.g. shop refused, short stock', required: true);
      if (r == null) return;
      _reason.text = r;
    }
    final err = await oc.deliveryEdit(_o!, _newItems(oc, inv), _reason.text.trim());
    if (!mounted) return;
    if (handleResult(context, err, success: 'Changes saved & logged')) {
      setState(() => _load(oc));
    }
  }

  Future<void> _invoice(OrderController oc, InventoryController inv) async {
    setState(() => _busy = true);
    if (_changed) {
      await _saveChanges(oc, inv);
      if (_changed) {
        setState(() => _busy = false);
        return;
      }
    }
    final o = oc.byId(widget.orderId)!;
    final err = await oc.invoice(o, extraDiscount: double.tryParse(_disc.text) ?? 0);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!handleResult(context, err)) return;
    final done = oc.byId(widget.orderId)!;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 64).animate().scale(curve: Curves.easeOutBack),
          const Gap(),
          Text('Invoice #${done.invoiceNo} created', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(money(done.net), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const Text('Posted to shop khata', style: TextStyle(color: AppColors.muted)),
          const Gap(18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bluetooth_rounded),
                label: const Text('Print'),
                onPressed: () => btPrintOrder(context, done),
              ),
            ),
            const Gap(),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('WhatsApp'),
                onPressed: () => shareOrder(context, done),
              ),
            ),
          ]),
          const Gap(8),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
        ]),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.watch<OrderController>();
    final inv = context.watch<InventoryController>();
    final shops = context.watch<ShopController>();
    if (_o == null) _load(oc);
    final o = _o;
    if (o == null) return const Scaffold(body: EmptyState(text: 'Order not found'));
    if (o.status != OrderStatus.loaded) {
      return Scaffold(appBar: AppBar(), body: EmptyState(text: 'Order is ${o.status}'));
    }
    final preview = _newItems(oc, inv);
    final net = preview.fold(0.0, (s, i) => s + i.amount) - (double.tryParse(_disc.text) ?? 0);

    return Scaffold(
      appBar: AppBar(title: Text('Deliver #${o.no}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          gradient: AppColors.primaryGradient,
          child: Row(children: [
            const Icon(Icons.storefront_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shops.shopName(o.shopId), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Outstanding ${money(shops.outstanding(o.shopId))}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ]),
        ).entrance(0),
        const SectionTitle('Items – change qty if shop refuses / short stock'),
        for (final i in o.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              color: (_qty[i.productId] ?? 0) != i.qty ? AppColors.amber.withValues(alpha: 0.10) : null,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv.productName(i.productId),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: (_qty[i.productId] ?? 0) == 0 ? TextDecoration.lineThrough : null,
                        )),
                    Text('Booked ${inv.product(i.productId)?.packLabel(i.qty) ?? i.qty} @ ${num2(i.rate)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                QtyStepper(
                  value: _qty[i.productId] ?? 0,
                  step: inv.product(i.productId)?.piecesPerBox ?? 1,
                  onChanged: (v) => setState(() => _qty[i.productId] = v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                  onPressed: () => setState(() => _qty[i.productId] = 0),
                ),
              ]),
            ),
          ),
        if (_changed) ...[
          const Gap(),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason for change (logged)')),
        ],
        const Gap(),
        NumField(_disc, 'Extra discount (${AppConfig.currency})', onChanged: (_) => setState(() {})),
        const Gap(),
        AppCard(
          child: Column(children: [
            KV('Booked amount', money(o.net)),
            KV('Final invoice amount', money(net), bold: true, color: _changed ? AppColors.amber : null),
          ]),
        ),
        if (o.editLog.isNotEmpty) ...[
          const SectionTitle('Change log'),
          for (final e in o.editLog) Text('• ${e.text} (${timeFmt(e.time)})', style: const TextStyle(fontSize: 12)),
        ],
        const Gap(20),
        if (_changed)
          OutlinedButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save changes'),
            onPressed: () => _saveChanges(oc, inv),
          ),
        const Gap(),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.receipt_long_rounded),
          label: const Text('Generate final invoice'),
          onPressed: _busy || preview.isEmpty ? null : () => _invoice(oc, inv),
        ),
        const Gap(),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          icon: const Icon(Icons.block_rounded),
          label: const Text('Shop refused whole order'),
          onPressed: () async {
            final r = await promptText(context, 'Cancel delivery', hint: 'Reason', required: true);
            if (r == null) return;
            await oc.cancelDelivery(o, r);
            if (context.mounted) {
              showSnack(context, 'Order cancelled – stock stays on van');
              Navigator.pop(context);
            }
          },
        ),
      ]),
    );
  }
}
