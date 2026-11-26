import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../booking/book_order_view.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'order_docs.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  static const _tabs = [
    (OrderStatus.pending, 'Pending'),
    (OrderStatus.approved, 'Approved'),
    (OrderStatus.loaded, 'On van'),
    (OrderStatus.delivered, 'Invoiced'),
    ('closed', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    final oc = context.watch<OrderController>();
    final orders = oc.visibleOrders;
    List<SaleOrder> of(String s) => s == 'closed'
        ? orders.where((o) => o.status == OrderStatus.rejected || o.status == OrderStatus.cancelled).toList()
        : orders.where((o) => o.status == s).toList();

    return DefaultTabController(
      length: _tabs.length,
      child: ShellPage(
        title: 'Orders & Approval',
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in _tabs) Tab(text: '${t.$2} (${of(t.$1).length})')],
        ),
        body: TabBarView(children: [
          for (final t in _tabs) _OrderList(list: of(t.$1)),
        ]),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<SaleOrder> list;
  const _OrderList({required this.list});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, text: 'No orders here');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => OrderCard(order: list[i]).entrance(i),
    );
  }
}

class OrderCard extends StatelessWidget {
  final SaleOrder order;
  final VoidCallback? onTap;
  const OrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final users = context.watch<UserController>();
    final o = order;
    return AppCard(
      onTap: onTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailView(orderId: o.id))),
      child: Column(children: [
        Row(children: [
          Text('#${o.no}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(width: 10),
          Expanded(child: Text(shops.shopName(o.shopId), style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          StatusChip(o.status),
        ]),
        const Gap(6),
        Row(children: [
          Expanded(
            child: Text(
              '${dateTimeFmt(o.date)} · ${users.nameOf(o.bookerId)} · ${o.items.length} items',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Text(money(o.net), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        if (o.creditHold || o.creditOverridden || o.editLog.isNotEmpty) ...[
          const Gap(6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (o.creditHold) const StatusChip('credit limit – override needed', color: AppColors.red),
              if (o.creditOverridden) const StatusChip('limit overridden', color: AppColors.purple),
              if (o.editLog.isNotEmpty) const StatusChip('edited at delivery', color: AppColors.amber),
            ]),
          ),
        ],
      ]),
    );
  }
}

class OrderDetailView extends StatelessWidget {
  final String orderId;
  const OrderDetailView({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final oc = context.watch<OrderController>();
    final inv = context.watch<InventoryController>();
    final shops = context.watch<ShopController>();
    final users = context.watch<UserController>();
    final auth = context.watch<AuthController>();
    final o = oc.byId(orderId);
    if (o == null) return const Scaffold(body: EmptyState(text: 'Order not found'));
    final cc = shops.creditCheck(o.shopId, o.status == OrderStatus.pending ? o.net : 0);
    final canApprove = auth.can(Scr.orders, PermAction.approve) && o.status == OrderStatus.pending;
    final me = auth.user!;
    final canEdit = o.status == OrderStatus.pending &&
        auth.can(Scr.orders, PermAction.edit) &&
        (me.role != UserRole.booker || o.bookerId == me.id);

    return Scaffold(
      appBar: AppBar(title: Text('Order #${o.no}'), actions: [
        PrintMenu(
          onShare: () => shareOrder(context, o),
          onPrint: () => printOrder(context, o),
          onBluetooth: () => btPrintOrder(context, o),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          gradient: AppColors.primaryGradient,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(shops.shopName(o.shopId),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              StatusChip(o.status, color: Colors.white),
            ]),
            const Gap(6),
            Text('Booked ${dateTimeFmt(o.date)} by ${users.nameOf(o.bookerId)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (o.salesmanId.isNotEmpty)
              Text('Salesman: ${users.nameOf(o.salesmanId)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (o.invoicedAt != null)
              Text('Invoice #${o.invoiceNo} · ${dateTimeFmt(o.invoicedAt!)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (o.lat != null)
              Text('GPS: ${o.lat!.toStringAsFixed(5)}, ${o.lng!.toStringAsFixed(5)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Gap(12),
            Text(money(o.net), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          ]),
        ).entrance(0),
        if (o.status == OrderStatus.pending) ...[
          const Gap(),
          AppCard(
            color: cc.exceeds ? AppColors.red.withValues(alpha: 0.08) : null,
            child: Column(children: [
              KV('Shop outstanding', money(cc.outstanding)),
              KV('Credit limit', cc.hasLimit ? money(cc.limit) : 'No limit'),
              KV('After this order', money(cc.afterOrder), bold: true, color: cc.exceeds ? AppColors.red : null),
              if (cc.exceeds)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Credit limit crossed – approving will be recorded as an admin override.',
                      style: TextStyle(color: AppColors.red, fontSize: 12)),
                ),
            ]),
          ).entrance(1),
        ],
        const SectionTitle('Items'),
        for (final i in o.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv.productName(i.productId), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${inv.product(i.productId)?.packLabel(i.qty) ?? i.qty}'
                      '${i.freeQty > 0 ? ' + ${i.freeQty} free' : ''} @ ${num2(i.rate)}'
                      '${i.discountPct > 0 ? ' · ${num2(i.discountPct)}% off' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ]),
                ),
                Text(num0(i.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        AppCard(
          child: Column(children: [
            KV('Gross', money(o.gross)),
            if (o.itemDiscount > 0) KV('Scheme discount', '- ${money(o.itemDiscount)}'),
            if (o.extraDiscount > 0) KV('Extra discount', '- ${money(o.extraDiscount)}'),
            KV('Net amount', money(o.net), bold: true),
          ]),
        ),
        if (o.notes.isNotEmpty) ...[const SectionTitle('Notes'), AppCard(child: Text(o.notes))],
        if (o.editLog.isNotEmpty) ...[
          const SectionTitle('Change log (before invoice)'),
          for (final e in o.editLog)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_note_rounded, color: AppColors.amber),
              title: Text(e.text, style: const TextStyle(fontSize: 13)),
              subtitle: Text('${users.nameOf(e.userId)} · ${dateTimeFmt(e.time)}'),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Originally booked items', style: TextStyle(fontSize: 14)),
            children: [
              for (final b in o.bookedItems)
                ListTile(
                  dense: true,
                  title: Text(inv.productName(b.productId)),
                  trailing: Text('${b.qty} pcs · ${num0(b.amount)}'),
                ),
            ],
          ),
        ],
        const Gap(20),
        if (canEdit)
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit order'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookOrderView(editOrder: o))),
          ),
        if (canApprove) ...[
          const Gap(),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject'),
                onPressed: () async {
                  final r = await promptText(context, 'Reject order', hint: 'Reason');
                  if (r == null) return;
                  await oc.reject(o, r);
                  if (context.mounted) showSnack(context, 'Order rejected');
                },
              ),
            ),
            const Gap(),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: Text(cc.exceeds ? 'Approve (override)' : 'Approve'),
                onPressed: () async {
                  var override = false;
                  if (cc.exceeds) {
                    override = await confirmDialog(context, 'Override credit limit?',
                        'This shop will cross its credit limit by ${money(cc.afterOrder - cc.limit)}. Approve anyway?',
                        ok: 'Override & approve', color: AppColors.amber);
                    if (!override) return;
                  }
                  final err = await oc.approve(o, override: override);
                  if (context.mounted) handleResult(context, err, success: 'Order #${o.no} approved');
                },
              ),
            ),
          ]),
        ],
        const Gap(20),
        Center(
          child: Text('${AppConfig.currency} values include scheme discounts',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ),
      ]),
    );
  }
}
