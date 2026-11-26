import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/user_controller.dart';
import '../../models/base_model.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

void showBatches(BuildContext context, InventoryController inv, Product p, String location) {
  final batches = inv.batches(p.id, location);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text('Batches & expiry', style: const TextStyle(color: AppColors.muted)),
        const Gap(),
        if (batches.isEmpty) const Text('No batch stock'),
        for (final b in batches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.qr_code_2_rounded,
                color: (b.daysToExpiry ?? 999) <= AppConfig.nearExpiryDays ? AppColors.red : AppColors.blue),
            title: Text(b.batchNo.isEmpty ? 'No batch' : 'Batch ${b.batchNo}'),
            subtitle: Text(b.expiry == null ? 'No expiry' : 'Expiry ${dateFmt(b.expiry!)} (${b.daysToExpiry} days)'),
            trailing: Text(p.packLabel(b.qty), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ]),
    ),
  );
}

class StockView extends StatefulWidget {
  const StockView({super.key});

  @override
  State<StockView> createState() => _StockViewState();
}

class _StockViewState extends State<StockView> {
  String _q = '';

  PrintDoc _doc(InventoryController inv) => PrintDoc(
        title: 'STOCK REPORT',
        headers: ['Product', 'Company', 'Warehouse', 'On vans', 'Cost', 'Value'],
        rows: [
          for (final p in inv.activeProducts)
            [
              p.name,
              inv.companyName(p.companyId),
              p.packLabel(inv.warehouseQty(p.id)),
              p.packLabel(inv.totalQty(p.id) - inv.warehouseQty(p.id)),
              num2(p.costPrice),
              num0(inv.totalQty(p.id) * p.costPrice),
            ]
        ],
        totals: [MapEntry('Total stock value', money(inv.stockValue))],
      );

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final list = inv.activeProducts.where((p) => _q.isEmpty || p.name.toLowerCase().contains(_q)).toList();
    return ShellPage(
      title: 'Warehouse Stock',
      actions: [
        PrintMenu(
          onShare: () => PdfService.instance.share(_doc(inv), 'stock_report.pdf', landscape: true),
          onPrint: () => PdfService.instance.printDoc(_doc(inv), landscape: true),
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        AppCard(
          gradient: AppColors.primaryGradient,
          child: Row(children: [
            const Icon(Icons.warehouse_rounded, color: Colors.white, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total stock value (warehouse + vans)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(money(inv.stockValue),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ).entrance(0),
        const Gap(),
        SearchField(onChanged: (v) => setState(() => _q = v.toLowerCase())),
        const Gap(),
        if (list.isEmpty) const EmptyState(text: 'No products'),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _row(context, inv, list[i]).entrance(i + 1),
          ),
      ]),
    );
  }

  Widget _row(BuildContext context, InventoryController inv, Product p) {
    final wh = inv.warehouseQty(p.id);
    final onVans = inv.totalQty(p.id) - wh;
    final low = p.lowStockPieces > 0 && wh <= p.lowStockPieces;
    return AppCard(
      onTap: () => showBatches(context, inv, p, StockLoc.warehouse),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('On vans: ${p.packLabel(onVans)} · Value ${num0(inv.totalQty(p.id) * p.costPrice)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(p.packLabel(wh), style: TextStyle(fontWeight: FontWeight.w700, color: low ? AppColors.red : null)),
          Text('$wh pcs', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}

class VanStockView extends StatefulWidget {
  const VanStockView({super.key});

  @override
  State<VanStockView> createState() => _VanStockViewState();
}

class _VanStockViewState extends State<VanStockView> {
  String _salesmanId = '';

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final users = context.watch<UserController>();
    final auth = context.watch<AuthController>();
    final me = auth.user!;
    final isSalesman = me.role == UserRole.salesman;
    final salesmen = users.salesmen;
    if (isSalesman) _salesmanId = me.id;
    if (_salesmanId.isEmpty && salesmen.isNotEmpty) _salesmanId = salesmen.first.id;
    final stock = _salesmanId.isEmpty ? <String, int>{} : inv.vanStock(_salesmanId);
    final value = stock.entries.fold(0.0, (s, e) => s + e.value * (inv.product(e.key)?.costPrice ?? 0));
    final tpValue = stock.entries.fold(0.0, (s, e) => s + e.value * (inv.product(e.key)?.tp ?? 0));

    return ShellPage(
      title: 'Van Stock',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (!isSalesman)
          DropdownButtonFormField<String>(
            value: _salesmanId.isEmpty ? null : _salesmanId,
            decoration: const InputDecoration(labelText: 'Salesman / van'),
            items: [
              for (final s in salesmen)
                DropdownMenuItem(value: s.id, child: Text('${s.name}${s.vanName.isEmpty ? '' : ' · ${s.vanName}'}')),
            ],
            onChanged: (v) => setState(() => _salesmanId = v ?? ''),
          ),
        const Gap(),
        AppCard(
          gradient: AppColors.soft(AppColors.teal),
          child: Row(children: [
            const Icon(Icons.airport_shuttle_rounded, color: Colors.white, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${stock.length} items on van', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(money(tpValue), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Text('at TP · cost ${money(value)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
          ]),
        ).entrance(0),
        const Gap(),
        if (stock.isEmpty) const EmptyState(icon: Icons.airport_shuttle_outlined, text: 'Van is empty', sub: 'Stock is loaded through Load Sheets'),
        for (final e in stock.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () {
                final p = inv.product(e.key);
                if (p != null) showBatches(context, inv, p, StockLoc.van(_salesmanId));
              },
              child: Row(children: [
                Expanded(child: Text(inv.productName(e.key), style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(inv.product(e.key)?.packLabel(e.value) ?? '${e.value}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: e.value < 0 ? AppColors.red : null)),
              ]),
            ),
          ),
        if (!isSalesman && stock.isNotEmpty && auth.can(Scr.vanStock, PermAction.add)) ...[
          const Gap(),
          OutlinedButton.icon(
            icon: const Icon(Icons.move_down_rounded),
            label: const Text('Load-in: return all van stock to warehouse'),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Load-in', 'Move all remaining van stock back to the warehouse?');
              if (!ok) return;
              await inv.loadIn(_salesmanId, newId());
              inv.changed();
              if (context.mounted) showSnack(context, 'Van stock returned to warehouse');
            },
          ),
        ],
      ]),
    );
  }
}

class AdjustView extends StatefulWidget {
  const AdjustView({super.key});

  @override
  State<AdjustView> createState() => _AdjustViewState();
}

class _AdjustViewState extends State<AdjustView> {
  Product? _p;
  String _loc = StockLoc.warehouse;
  bool _count = true; // true = stock count, false = damage / short
  final _ctn = TextEditingController();
  final _pcs = TextEditingController();
  final _reason = TextEditingController(text: 'Damage');

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final users = context.watch<UserController>();
    final p = _p;
    final current = p == null ? 0 : inv.qty(p.id, _loc);
    return ShellPage(
      title: 'Stock Count / Adjust',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Stock count'), icon: Icon(Icons.fact_check_outlined)),
            ButtonSegment(value: false, label: Text('Damage / short'), icon: Icon(Icons.broken_image_outlined)),
          ],
          selected: {_count},
          onSelectionChanged: (s) => setState(() => _count = s.first),
        ),
        const Gap(),
        AppCard(
          onTap: () async {
            final r = await pickFromList<Product>(context,
                title: 'Select product', items: inv.activeProducts, label: (x) => x.name,
                subtitle: (x) => x.packLabel(inv.warehouseQty(x.id)));
            if (r != null) setState(() => _p = r);
          },
          child: Row(children: [
            const Icon(Icons.cookie_outlined, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text(p?.name ?? 'Tap to select product', style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.expand_more_rounded),
          ]),
        ),
        const Gap(),
        DropdownButtonFormField<String>(
          value: _loc,
          decoration: const InputDecoration(labelText: 'Location'),
          items: [
            const DropdownMenuItem(value: StockLoc.warehouse, child: Text('Main warehouse')),
            for (final s in users.salesmen) DropdownMenuItem(value: StockLoc.van(s.id), child: Text('Van – ${s.name}')),
          ],
          onChanged: (v) => setState(() => _loc = v ?? StockLoc.warehouse),
        ),
        if (p != null) ...[
          const Gap(),
          AppCard(child: KV('Current stock', '${p.packLabel(current)} ($current pcs)', bold: true)),
          const Gap(),
          Text(_count ? 'Physically counted quantity' : 'Damaged / short quantity',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Gap(8),
          Row(children: [
            Expanded(child: NumField(_ctn, 'Cartons', decimal: false)),
            const Gap(),
            Expanded(child: NumField(_pcs, 'Pieces', decimal: false)),
          ]),
          if (!_count) ...[
            const Gap(),
            Wrap(spacing: 8, children: [
              for (final r in ['Damage', 'Short', 'Expired', 'Sample'])
                ChoiceChip(
                  label: Text(r),
                  selected: _reason.text == r,
                  onSelected: (_) => setState(() => _reason.text = r),
                ),
            ]),
            const Gap(),
            TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason')),
          ],
          const Gap(20),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: Text(_count ? 'Save stock count' : 'Record damage / short'),
            onPressed: () async {
              final q = p.toPieces(cartons: int.tryParse(_ctn.text) ?? 0, pieces: int.tryParse(_pcs.text) ?? 0);
              final err = _count
                  ? await inv.stockCount(p.id, _loc, q)
                  : await inv.adjust(p.id, _loc, -q, _reason.text.trim().isEmpty ? 'Damage' : _reason.text.trim());
              if (!context.mounted) return;
              if (handleResult(context, err, success: 'Stock updated')) {
                _ctn.clear();
                _pcs.clear();
              }
            },
          ),
          const Gap(),
          const Text('Adjustments are posted to accounts as stock damage / short and recorded in the activity log.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ]),
    );
  }
}
