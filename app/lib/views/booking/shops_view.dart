import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/accounts_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/shop_controller.dart';
import '../../models/accounts.dart';
import '../../models/base_model.dart';
import '../../models/shop.dart';
import '../../models/user.dart';
import '../../services/gps_service.dart';
import '../accounts/ledgers_view.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';
import 'book_order_view.dart';

class ShopsView extends StatefulWidget {
  const ShopsView({super.key});

  @override
  State<ShopsView> createState() => _ShopsViewState();
}

class _ShopsViewState extends State<ShopsView> {
  String _q = '';
  String? _route; // null = all
  bool _init = false;

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final acc = context.watch<AccountsController>();
    final auth = context.watch<AuthController>();
    final me = auth.user!;
    if (!_init) {
      _init = true;
      if (me.role.isField && me.routeId.isNotEmpty) _route = me.routeId;
    }
    final balances = acc.allShopBalances();
    final list = shops.shops
        .where((s) =>
            (_route == null || s.routeId == _route) &&
            (_q.isEmpty ||
                s.name.toLowerCase().contains(_q) ||
                s.khataNo.toLowerCase().contains(_q) ||
                s.owner.toLowerCase().contains(_q) ||
                s.area.toLowerCase().contains(_q)))
        .toList();

    return ShellPage(
      title: 'Shops & Credit Limits',
      fab: auth.can(Scr.shops, PermAction.add)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopForm())),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Shop'),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchField(hint: 'Search name, khata no, area', onChanged: (v) => setState(() => _q = v.toLowerCase())),
        ),
        SizedBox(
          height: 42,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: const Text('All routes'), selected: _route == null, onSelected: (_) => setState(() => _route = null)),
            ),
            for (final r in shops.routes)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(r.name + (r.isToday() ? ' • today' : '')),
                  selected: _route == r.id,
                  onSelected: (_) => setState(() => _route = r.id),
                ),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.storefront_outlined, text: 'No shops found')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final bal = balances[s.id] ?? 0;
                    return ShopTile(shop: s, balance: bal, routeName: shops.routeName(s.routeId),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailView(shopId: s.id))))
                        .entrance(i);
                  },
                ),
        ),
      ]),
    );
  }
}

class ShopTile extends StatelessWidget {
  final Shop shop;
  final double balance;
  final String routeName;
  final VoidCallback? onTap;
  const ShopTile({super.key, required this.shop, required this.balance, required this.routeName, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasLimit = shop.creditLimit > 0;
    final ratio = hasLimit ? (balance / shop.creditLimit).clamp(0.0, 1.0) : 0.0;
    final color = !hasLimit
        ? AppColors.blue
        : ratio >= 1
            ? AppColors.red
            : ratio > 0.85
                ? AppColors.amber
                : AppColors.green;
    return AppCard(
      onTap: onTap,
      child: Column(children: [
        Row(children: [
          Avatar(shop.name.isEmpty ? '?' : shop.name[0].toUpperCase(), color: shop.active ? AppColors.navy : AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${shop.khataNo.isEmpty ? '' : '${shop.khataNo} · '}${shop.owner.isEmpty ? '' : '${shop.owner} · '}$routeName',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(balance), style: TextStyle(fontWeight: FontWeight.w700, color: balance > 0 ? null : AppColors.green)),
            Text(hasLimit ? 'of ${num0(shop.creditLimit)}' : 'no limit', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ]),
        if (hasLimit) ...[
          const Gap(10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class ShopDetailView extends StatelessWidget {
  final String shopId;
  const ShopDetailView({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final auth = context.watch<AuthController>();
    final s = shops.shop(shopId);
    if (s == null) return const Scaffold(body: EmptyState(text: 'Shop not found'));
    final cc = shops.creditCheck(s.id, 0);
    final bills = shops.pendingBills(s.id);
    return Scaffold(
      appBar: AppBar(title: Text(s.name), actions: [
        if (auth.can(Scr.shops, PermAction.edit))
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopForm(shop: s))),
          ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ShopTile(shop: s, balance: cc.outstanding, routeName: shops.routeName(s.routeId)).entrance(0),
        const Gap(),
        AppCard(
          child: Column(children: [
            KV('Owner', s.owner.isEmpty ? '-' : s.owner),
            KV('Phone', s.phone.isEmpty ? '-' : s.phone),
            KV('Area', s.area.isEmpty ? '-' : s.area),
            KV('Khata no.', s.khataNo.isEmpty ? '-' : s.khataNo),
            KV('Credit limit', s.creditLimit > 0 ? money(s.creditLimit) : 'No limit'),
            KV('Available credit', cc.hasLimit ? money(cc.available) : 'Unlimited', bold: true),
            KV('GPS location', s.lat == null ? 'Not saved' : '${s.lat!.toStringAsFixed(5)}, ${s.lng!.toStringAsFixed(5)}'),
          ]),
        ).entrance(1),
        const Gap(),
        Row(children: [
          if (auth.can(Scr.booking, PermAction.add))
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Book order'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookOrderView(shopId: s.id))),
              ),
            ),
          if (auth.can(Scr.booking, PermAction.add)) const Gap(),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Khata'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PartyLedgerPage(partyType: PartyType.shop, partyId: s.id, title: '${s.name} – Khata')),
              ),
            ),
          ),
        ]),
        if (auth.can(Scr.shops, PermAction.edit)) ...[
          const Gap(),
          OutlinedButton.icon(
            icon: const Icon(Icons.my_location_rounded),
            label: Text(s.lat == null ? 'Save shop GPS location (I am at shop)' : 'Update shop GPS location'),
            onPressed: () async {
              final pos = await GpsService.instance.current();
              if (!context.mounted) return;
              if (pos == null) {
                showSnack(context, 'Could not get location. Turn on GPS.', error: true);
                return;
              }
              s.lat = pos.latitude;
              s.lng = pos.longitude;
              final err = await shops.saveShop(s);
              if (context.mounted) handleResult(context, err, success: 'Location saved');
            },
          ),
        ],
        SectionTitle('Pending bills (${bills.length})'),
        if (bills.isEmpty) const AppCard(child: Text('No pending bills', style: TextStyle(color: AppColors.muted))),
        for (final b in bills)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bill #${b.order.invoiceNo}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${dateFmt(b.order.invoicedAt ?? b.order.date)} · ${b.ageDays} days · bill ${num0(b.order.net)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                Text(money(b.pending), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.red)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class ShopForm extends StatefulWidget {
  final Shop? shop;
  const ShopForm({super.key, this.shop});

  @override
  State<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopForm> {
  late final Shop s;
  late final bool isNew;
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _khata = TextEditingController();
  final _limit = TextEditingController();

  @override
  void initState() {
    super.initState();
    isNew = widget.shop == null;
    s = widget.shop ?? Shop(id: newId(), name: '');
    _name.text = s.name;
    _owner.text = s.owner;
    _phone.text = s.phone;
    _area.text = s.area;
    _khata.text = s.khataNo;
    _limit.text = s.creditLimit == 0 ? '' : s.creditLimit.toStringAsFixed(0);
    if (isNew) {
      final me = context.read<AuthController>().user;
      if (me != null && me.routeId.isNotEmpty) s.routeId = me.routeId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final auth = context.watch<AuthController>();
    // only admin-level users may change the credit limit
    final canLimit = auth.user!.role.isAdminLevel || auth.user!.role == UserRole.accountant;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New Shop' : 'Edit Shop')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Shop name')),
        const Gap(),
        TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner name')),
        const Gap(),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        const Gap(),
        Row(children: [
          Expanded(child: TextField(controller: _area, decoration: const InputDecoration(labelText: 'Area'))),
          const Gap(),
          Expanded(child: TextField(controller: _khata, decoration: const InputDecoration(labelText: 'Khata no.'))),
        ]),
        const Gap(),
        DropdownButtonFormField<String>(
          value: shops.routes.any((r) => r.id == s.routeId) ? s.routeId : null,
          decoration: const InputDecoration(labelText: 'Route'),
          items: [for (final r in shops.routes) DropdownMenuItem(value: r.id, child: Text(r.name))],
          onChanged: (v) => setState(() => s.routeId = v ?? ''),
        ),
        const Gap(),
        TextField(
          controller: _limit,
          enabled: canLimit,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Credit limit (${AppConfig.currency}) – 0 = no limit',
            helperText: canLimit ? 'Orders above this limit are blocked / sent for admin override' : 'Only admin can change the limit',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          value: s.active,
          onChanged: (v) => setState(() => s.active = v),
        ),
        const Gap(20),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded),
          label: const Text('Save shop'),
          onPressed: () async {
            s.name = _name.text.trim();
            s.owner = _owner.text.trim();
            s.phone = _phone.text.trim();
            s.area = _area.text.trim();
            s.khataNo = _khata.text.trim();
            if (canLimit) s.creditLimit = double.tryParse(_limit.text) ?? 0;
            final err = await shops.saveShop(s, isNew: isNew);
            if (!context.mounted) return;
            if (handleResult(context, err, success: 'Shop saved')) Navigator.pop(context);
          },
        ),
      ]),
    );
  }
}
