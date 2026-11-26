import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/shop.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

/// Booker order booking (also used to edit a pending order).
class BookOrderView extends StatefulWidget {
  final String? shopId;
  final SaleOrder? editOrder;
  const BookOrderView({super.key, this.shopId, this.editOrder});

  @override
  State<BookOrderView> createState() => _BookOrderViewState();
}

enum _Unit { pcs, box, ctn }

class _BookOrderViewState extends State<BookOrderView> {
  String _shopId = '';
  final Map<String, int> _cart = {}; // productId -> pieces
  String _q = '';
  _Unit _unit = _Unit.box;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _shopId = widget.editOrder?.shopId ?? widget.shopId ?? '';
    if (widget.editOrder != null) {
      for (final i in widget.editOrder!.items) {
        _cart[i.productId] = i.qty;
      }
      _notes.text = widget.editOrder!.notes;
    }
  }

  int _step(Product p) => switch (_unit) { _Unit.pcs => 1, _Unit.box => p.piecesPerBox, _Unit.ctn => p.piecesPerCarton };

  List<OrderItem> _items(OrderController oc, InventoryController inv) {
    final out = <OrderItem>[];
    _cart.forEach((pid, q) {
      final p = inv.product(pid);
      if (p != null && q > 0) out.add(oc.buildItem(p, q));
    });
    return out;
  }

  Future<void> _pickShop(ShopController shops) async {
    final me = context.read<AuthController>().user!;
    var list = shops.activeShops;
    if (me.role.isField && me.routeId.isNotEmpty) {
      // own route first
      list = [...list.where((s) => s.routeId == me.routeId), ...list.where((s) => s.routeId != me.routeId)];
    }
    final s = await pickFromList<Shop>(
      context,
      title: 'Select shop',
      items: list,
      label: (s) => s.name,
      subtitle: (s) => '${s.khataNo} · ${s.area} · ${shops.routeName(s.routeId)}',
      leading: (s) => Avatar(s.name.isEmpty ? '?' : s.name[0].toUpperCase(), size: 36),
    );
    if (s != null) setState(() => _shopId = s.id);
  }

  Future<void> _submit(OrderController oc, InventoryController inv, ShopController shops) async {
    final items = _items(oc, inv);
    if (_shopId.isEmpty) {
      showSnack(context, 'Select a shop first', error: true);
      return;
    }
    if (items.isEmpty) {
      showSnack(context, 'Add at least one item', error: true);
      return;
    }
    setState(() => _saving = true);
    String? err;
    if (widget.editOrder != null) {
      err = await oc.updatePending(widget.editOrder!, items, notes: _notes.text.trim());
    } else {
      err = await oc.book(shopId: _shopId, items: items, notes: _notes.text.trim());
      if (err == 'CREDIT_LIMIT' && mounted) {
        final cc = shops.creditCheck(_shopId, items.fold(0.0, (s, i) => s + i.amount));
        final send = await confirmDialog(
          context,
          'Credit limit crossed',
          'Outstanding ${money(cc.outstanding)} + this order ${money(cc.orderAmount)} = ${money(cc.afterOrder)}\n'
              'Limit: ${money(cc.limit)}\n\nThe order is blocked. Send it to admin for credit limit override?',
          ok: 'Send for override',
          color: AppColors.amber,
        );
        if (!send) {
          setState(() => _saving = false);
          return;
        }
        err = await oc.book(shopId: _shopId, items: items, notes: _notes.text.trim(), requestOverride: true);
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (handleResult(context, err, success: widget.editOrder != null ? 'Order updated' : 'Order booked – sent for approval')) {
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      } else {
        setState(() {
          _cart.clear();
          _notes.clear();
          _shopId = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final shops = context.watch<ShopController>();
    final oc = context.watch<OrderController>();
    final shop = _shopId.isEmpty ? null : shops.shop(_shopId);
    final items = _items(oc, inv);
    final total = items.fold(0.0, (s, i) => s + i.amount);
    final cc = shop == null ? null : shops.creditCheck(shop.id, total);
    final products = inv.activeProducts.where((p) => _q.isEmpty || p.name.toLowerCase().contains(_q)).toList();

    return ShellPage(
      title: widget.editOrder != null ? 'Edit Order #${widget.editOrder!.no}' : 'Book Order',
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
            // ---- Shop card ----
            AppCard(
              onTap: widget.editOrder != null ? null : () => _pickShop(shops),
              gradient: shop == null ? null : AppColors.primaryGradient,
              child: (shop == null || cc == null)
                  ? const Row(children: [
                      Icon(Icons.storefront_rounded, color: AppColors.blue),
                      SizedBox(width: 12),
                      Expanded(child: Text('Tap to select shop', style: TextStyle(fontWeight: FontWeight.w600))),
                      Icon(Icons.expand_more_rounded),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.storefront_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(shop.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        if (widget.editOrder == null) const Icon(Icons.swap_horiz_rounded, color: Colors.white70),
                      ]),
                      const Gap(8),
                      Text('Khata ${shop.khataNo} · ${shops.routeName(shop.routeId)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const Gap(10),
                      Row(children: [
                        _mini('Outstanding', money(cc.outstanding)),
                        _mini('Limit', cc.hasLimit ? money(cc.limit) : 'None'),
                        _mini('After order', money(cc.afterOrder)),
                      ]),
                      if (cc.exceeds || cc.nearLimit) ...[
                        const Gap(10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (cc.exceeds ? AppColors.red : AppColors.amber),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cc.exceeds ? 'Credit limit will be crossed – needs admin override' : 'Near credit limit',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ).animate().shake(hz: 3, duration: 400.ms),
                      ],
                    ]),
            ),
            const Gap(),
            Row(children: [
              Expanded(child: SearchField(hint: 'Search product', onChanged: (v) => setState(() => _q = v.toLowerCase()))),
              const SizedBox(width: 8),
              SegmentedButton<_Unit>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: _Unit.pcs, label: Text('Pc')),
                  ButtonSegment(value: _Unit.box, label: Text('Box')),
                  ButtonSegment(value: _Unit.ctn, label: Text('Ctn')),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
            ]),
            const Gap(),
            if (products.isEmpty) const EmptyState(text: 'No products'),
            for (var i = 0; i < products.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _productRow(products[i], inv, oc, shops).entrance(i),
              ),
          ]),
        ),
        // ---- Bottom cart bar ----
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, -4))],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (items.isNotEmpty)
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(hintText: 'Notes (optional)', isDense: true, prefixIcon: Icon(Icons.notes_rounded)),
                ),
              if (items.isNotEmpty) const Gap(10),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('${items.length} items · ${items.fold(0, (s, i) => s + i.qty + i.freeQty)} pcs',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: total),
                      duration: const Duration(milliseconds: 350),
                      builder: (_, v, __) => Text(money(v), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _submit(oc, inv, shops),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(widget.editOrder != null ? 'Update' : 'Book order'),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _mini(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          FittedBox(child: Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _productRow(Product p, InventoryController inv, OrderController oc, ShopController shops) {
    final q = _cart[p.id] ?? 0;
    final item = q > 0 ? oc.buildItem(p, q) : null;
    final stock = inv.warehouseQty(p.id);
    final hasScheme = shops.schemes.any((s) => s.active && (s.productId.isEmpty || s.productId == p.id));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: q > 0 ? AppColors.blue : Colors.transparent, width: 1.5),
      ),
      child: AppCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (hasScheme) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.local_offer_rounded, size: 14, color: AppColors.green),
                ],
              ]),
              Text('TP ${num2(p.tp)} · Stock ${p.packLabel(stock)}',
                  style: TextStyle(fontSize: 12, color: stock <= 0 ? AppColors.red : AppColors.muted)),
              if (item != null)
                Text(
                  '${p.packLabel(q)}${item.freeQty > 0 ? ' + ${item.freeQty} free' : ''}'
                  '${item.discountPct > 0 ? ' · ${num2(item.discountPct)}% off' : ''} = ${AppConfig.currency} ${num0(item.amount)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.navy, fontWeight: FontWeight.w600),
                ),
            ]),
          ),
          QtyStepper(
            value: q,
            step: _step(p),
            onChanged: (v) => setState(() {
              if (v <= 0) {
                _cart.remove(p.id);
              } else {
                _cart[p.id] = v;
              }
            }),
          ),
        ]),
      ),
    );
  }
}
