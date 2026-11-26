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
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'orders_view.dart';

class LoadSheetsView extends StatelessWidget {
  const LoadSheetsView({super.key});

  @override
  Widget build(BuildContext context) {
    final oc = context.watch<OrderController>();
    final users = context.watch<UserController>();
    final shops = context.watch<ShopController>();
    final auth = context.watch<AuthController>();
    final list = oc.loadSheets;
    final approved = oc.byStatus(OrderStatus.approved).length;
    return ShellPage(
      title: 'Load Sheets & Dispatch',
      fab: auth.can(Scr.loadSheets, PermAction.add)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewLoadSheetView())),
              icon: const Icon(Icons.local_shipping_rounded),
              label: Text('New ($approved ready)'),
            )
          : null,
      body: list.isEmpty
          ? const EmptyState(icon: Icons.local_shipping_outlined, text: 'No load sheets yet', sub: 'Approved orders are loaded on vans here')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final ls = list[i];
                return AppCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoadSheetDetailView(id: ls.id))),
                  child: Row(children: [
                    Avatar('#${ls.no}', color: ls.status == 'closed' ? AppColors.green : AppColors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(users.nameOf(ls.salesmanId), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${dateFmt(ls.date)} · ${ls.orderIds.length} orders · ${shops.routeName(ls.routeId)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ),
                    StatusChip(ls.status),
                  ]),
                ).entrance(i);
              },
            ),
    );
  }
}

class NewLoadSheetView extends StatefulWidget {
  const NewLoadSheetView({super.key});

  @override
  State<NewLoadSheetView> createState() => _NewLoadSheetViewState();
}

class _NewLoadSheetViewState extends State<NewLoadSheetView> {
  String _salesman = '';
  String? _route;
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final oc = context.watch<OrderController>();
    final inv = context.watch<InventoryController>();
    final shops = context.watch<ShopController>();
    final users = context.watch<UserController>();
    final approved = oc.byStatus(OrderStatus.approved).where((o) => _route == null || o.routeId == _route).toList();
    final chosen = approved.where((o) => _selected.contains(o.id)).toList();
    final agg = oc.aggregate(chosen);
    final total = chosen.fold(0.0, (s, o) => s + o.net);

    return Scaffold(
      appBar: AppBar(title: const Text('New Load Sheet')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          value: _salesman.isEmpty ? null : _salesman,
          decoration: const InputDecoration(labelText: 'Salesman (van)'),
          items: [
            for (final s in users.salesmen)
              DropdownMenuItem(value: s.id, child: Text('${s.name}${s.vanName.isEmpty ? '' : ' · ${s.vanName}'}')),
          ],
          onChanged: (v) => setState(() {
            _salesman = v ?? '';
            final u = users.byId(_salesman);
            if (u != null && u.routeId.isNotEmpty) _route = u.routeId;
          }),
        ),
        const Gap(),
        DropdownButtonFormField<String?>(
          value: _route,
          decoration: const InputDecoration(labelText: 'Route'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All routes')),
            for (final r in shops.routes) DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
          ],
          onChanged: (v) => setState(() => _route = v),
        ),
        SectionTitle(
          'Approved orders (${approved.length})',
          trailing: approved.isEmpty
              ? null
              : TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == approved.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(approved.map((o) => o.id));
                    }
                  }),
                  child: Text(_selected.length == approved.length ? 'Clear' : 'Select all'),
                ),
        ),
        if (approved.isEmpty) const AppCard(child: Text('No approved orders on this route', style: TextStyle(color: AppColors.muted))),
        for (final o in approved)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              onTap: () => setState(() => _selected.contains(o.id) ? _selected.remove(o.id) : _selected.add(o.id)),
              child: Row(children: [
                Checkbox(
                  value: _selected.contains(o.id),
                  onChanged: (v) => setState(() => v == true ? _selected.add(o.id) : _selected.remove(o.id)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${o.no} ${shops.shopName(o.shopId)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${o.items.length} items · ${users.nameOf(o.bookerId)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                Padding(padding: const EdgeInsets.only(right: 8), child: Text(num0(o.net), style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        if (agg.isNotEmpty) ...[
          const SectionTitle('Load summary'),
          AppCard(
            child: Column(children: [
              for (final e in agg.entries)
                Builder(builder: (_) {
                  final p = inv.product(e.key);
                  final have = inv.warehouseQty(e.key);
                  final short = have < e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(short ? Icons.error_rounded : Icons.check_circle_rounded,
                          size: 18, color: short ? AppColors.red : AppColors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(inv.productName(e.key))),
                      Text(p?.packLabel(e.value) ?? '${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  );
                }),
              const Divider(),
              KV('Orders value', money(total), bold: true),
            ]),
          ),
        ],
        const Gap(20),
        FilledButton.icon(
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.local_shipping_rounded),
          label: Text('Load on van (${chosen.length} orders)'),
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final err = await oc.createLoadSheet(_salesman, chosen, routeId: _route ?? '');
                  if (!context.mounted) return;
                  setState(() => _saving = false);
                  if (handleResult(context, err, success: 'Stock issued to van')) Navigator.pop(context);
                },
        ),
      ]),
    );
  }
}

class LoadSheetDetailView extends StatelessWidget {
  final String id;
  const LoadSheetDetailView({super.key, required this.id});

  PrintDoc _doc(OrderController oc, InventoryController inv, UserController users, ShopController shops, LoadSheet ls) => PrintDoc(
        title: 'LOAD SHEET',
        number: '#${ls.no}',
        date: ls.date,
        partyLines: [
          'Salesman: ${users.nameOf(ls.salesmanId)}',
          'Van: ${users.byId(ls.salesmanId)?.vanName ?? '-'}',
          'Route: ${shops.routeName(ls.routeId)}',
          'Orders: ${ls.orderIds.map((id) => '#${oc.byId(id)?.no ?? ''}').join(', ')}',
        ],
        headers: ['Product', 'Cartons / boxes / pcs', 'Total pcs'],
        rows: [
          for (final e in ls.items.entries) [inv.productName(e.key), inv.product(e.key)?.packLabel(e.value) ?? '', '${e.value}'],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final oc = context.watch<OrderController>();
    final inv = context.watch<InventoryController>();
    final users = context.watch<UserController>();
    final shops = context.watch<ShopController>();
    final auth = context.watch<AuthController>();
    final ls = oc.loadSheet(id);
    if (ls == null) return const Scaffold(body: EmptyState(text: 'Not found'));
    final orders = ls.orderIds.map(oc.byId).whereType<SaleOrder>().toList();

    return Scaffold(
      appBar: AppBar(title: Text('Load Sheet #${ls.no}'), actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(_doc(oc, inv, users, shops, ls), 'load_sheet_${ls.no}.pdf'),
          onPrint: () => PdfService.instance.printDoc(_doc(oc, inv, users, shops, ls)),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          gradient: AppColors.soft(AppColors.teal),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(users.nameOf(ls.salesmanId), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${dateTimeFmt(ls.date)} · ${shops.routeName(ls.routeId)}', style: const TextStyle(color: Colors.white70)),
            const Gap(8),
            StatusChip(ls.status, color: Colors.white),
          ]),
        ).entrance(0),
        const SectionTitle('Stock loaded'),
        AppCard(
          child: Column(children: [
            for (final e in ls.items.entries)
              KV(inv.productName(e.key), inv.product(e.key)?.packLabel(e.value) ?? '${e.value}'),
          ]),
        ),
        SectionTitle('Orders (${orders.length})'),
        for (var i = 0; i < orders.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: OrderCard(order: orders[i]).entrance(i)),
        if (ls.status != 'closed' && auth.can(Scr.loadSheets, PermAction.edit)) ...[
          const Gap(16),
          FilledButton.icon(
            icon: const Icon(Icons.move_down_rounded),
            label: const Text('Close sheet & load-in remaining stock'),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Close load sheet',
                  'All remaining stock on ${users.nameOf(ls.salesmanId)}\'s van will be returned to the warehouse.');
              if (!ok) return;
              final err = await oc.closeLoadSheet(ls);
              if (context.mounted) handleResult(context, err, success: 'Load sheet closed');
            },
          ),
          const Gap(8),
          Text('Remaining on van: ${inv.vanStock(ls.salesmanId).length} items · ${AppConfig.currency} '
              '${num0(inv.vanStock(ls.salesmanId).entries.fold(0.0, (s, e) => s + e.value * (inv.product(e.key)?.tp ?? 0)))}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ]),
    );
  }
}
