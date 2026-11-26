import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/return_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/product.dart';
import '../../models/sale_return.dart';
import '../../models/shop.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

Color conditionColor(String c) => c == 'fresh'
    ? AppColors.green
    : c == 'damaged'
        ? AppColors.amber
        : AppColors.red;

class ReturnsView extends StatelessWidget {
  const ReturnsView({super.key});

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<ReturnController>();
    final auth = context.watch<AuthController>();
    final all = rc.visibleReturns;
    final tabs = [
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: ShellPage(
        title: 'Sales Returns',
        bottom: TabBar(tabs: [for (final t in tabs) Tab(text: '${t.$2} (${all.where((r) => r.status == t.$1).length})')]),
        fab: auth.can(Scr.returns, PermAction.add)
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnForm())),
                icon: const Icon(Icons.assignment_return_rounded),
                label: const Text('Return'),
              )
            : null,
        body: TabBarView(children: [
          for (final t in tabs) _list(context, all.where((r) => r.status == t.$1).toList()),
        ]),
      ),
    );
  }

  Widget _list(BuildContext context, List<SaleReturn> list) {
    final shops = context.watch<ShopController>();
    final users = context.watch<UserController>();
    if (list.isEmpty) return const EmptyState(icon: Icons.assignment_return_outlined, text: 'No returns');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = list[i];
        final conds = r.items.map((e) => e.condition).toSet();
        return AppCard(
          onTap: () => _detail(context, r),
          child: Column(children: [
            Row(children: [
              Text('#${r.no}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(width: 10),
              Expanded(child: Text(shops.shopName(r.shopId), style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(money(r.total), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const Gap(6),
            Row(children: [
              Expanded(
                child: Text('${dateTimeFmt(r.date)} · ${users.nameOf(r.userId)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              for (final c in conds) Padding(padding: const EdgeInsets.only(left: 4), child: StatusChip(c, color: conditionColor(c))),
            ]),
          ]),
        ).entrance(i);
      },
    );
  }

  void _detail(BuildContext context, SaleReturn r) {
    final inv = context.read<InventoryController>();
    final shops = context.read<ShopController>();
    final auth = context.read<AuthController>();
    final rc = context.read<ReturnController>();
    final canApprove = auth.can(Scr.returns, PermAction.approve) && r.status == 'pending';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Return #${r.no} · ${shops.shopName(r.shopId)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(dateTimeFmt(r.date), style: const TextStyle(color: AppColors.muted)),
          const Gap(),
          for (final i in r.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(inv.productName(i.productId)),
              subtitle: Text('${inv.product(i.productId)?.packLabel(i.qty) ?? i.qty} @ ${num2(i.rate)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                StatusChip(i.condition, color: conditionColor(i.condition)),
                const SizedBox(width: 8),
                Text(num0(i.amount)),
              ]),
            ),
          const Divider(),
          KV('Credit to shop khata', money(r.total), bold: true),
          if (r.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.note)),
          if (canApprove) ...[
            const Gap(16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                  onPressed: () async {
                    final reason = await promptText(c, 'Reject return', hint: 'Reason');
                    if (reason == null) return;
                    await rc.reject(r, reason);
                    if (c.mounted) Navigator.pop(c);
                  },
                  child: const Text('Reject'),
                ),
              ),
              const Gap(),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final err = await rc.approve(r);
                    if (!c.mounted) return;
                    if (handleResult(c, err)) Navigator.pop(c);
                  },
                  child: const Text('Approve'),
                ),
              ),
            ]),
            const Gap(8),
            const Text('Fresh items go back to warehouse stock; damaged / expired go to the damage store.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ]),
      ),
    );
  }
}

class ReturnForm extends StatefulWidget {
  const ReturnForm({super.key});

  @override
  State<ReturnForm> createState() => _ReturnFormState();
}

class _ReturnFormState extends State<ReturnForm> {
  String _shopId = '';
  final List<ReturnItem> _items = [];
  final _note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final inv = context.watch<InventoryController>();
    final auth = context.watch<AuthController>();
    final me = auth.user!;
    final total = _items.fold(0.0, (s, i) => s + i.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('New Sales Return')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          onTap: () async {
            var list = shops.activeShops;
            if (me.role.isField && me.routeId.isNotEmpty) {
              list = [...list.where((s) => s.routeId == me.routeId), ...list.where((s) => s.routeId != me.routeId)];
            }
            final s = await pickFromList<Shop>(context,
                title: 'Select shop', items: list, label: (s) => s.name, subtitle: (s) => '${s.khataNo} · ${s.area}');
            if (s != null) setState(() => _shopId = s.id);
          },
          child: Row(children: [
            const Icon(Icons.storefront_rounded, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_shopId.isEmpty ? 'Tap to select shop' : shops.shopName(_shopId),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.expand_more_rounded),
          ]),
        ),
        SectionTitle('Items (${_items.length})',
            trailing: TextButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
              onPressed: () async {
                final p = await pickFromList<Product>(context,
                    title: 'Returned product', items: inv.activeProducts, label: (x) => x.name, subtitle: (x) => 'TP ${num2(x.tp)}');
                if (p != null) setState(() => _items.add(ReturnItem(productId: p.id, qty: p.piecesPerBox, rate: p.tp)));
              },
            )),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(inv.productName(_items[i].productId), style: const TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  ),
                ]),
                Row(children: [
                  QtyStepper(value: _items[i].qty, onChanged: (v) => setState(() => _items[i].qty = v)),
                  const Spacer(),
                  Text(num0(_items[i].amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const Gap(8),
                Wrap(spacing: 6, children: [
                  for (final c in returnConditions)
                    ChoiceChip(
                      label: Text(c[0].toUpperCase() + c.substring(1)),
                      selected: _items[i].condition == c,
                      selectedColor: conditionColor(c).withValues(alpha: 0.25),
                      onSelected: (_) => setState(() => _items[i].condition = c),
                    ),
                ]),
              ]),
            ),
          ),
        const Gap(),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note')),
        const Gap(),
        AppCard(child: KV('Return value (${AppConfig.currency})', money(total), bold: true)),
        const Gap(20),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: const Text('Submit for approval'),
          onPressed: () async {
            final err = await context.read<ReturnController>().create(_shopId, _items, _note.text.trim());
            if (!context.mounted) return;
            if (handleResult(context, err, success: 'Return submitted for approval')) Navigator.pop(context);
          },
        ),
      ]),
    );
  }
}
