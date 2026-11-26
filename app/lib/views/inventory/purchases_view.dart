import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/permissions.dart';
import '../../models/base_model.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../services/pdf_service.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class PurchasesView extends StatelessWidget {
  const PurchasesView({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final auth = context.watch<AuthController>();
    final list = inv.purchases;
    return ShellPage(
      title: 'Purchases',
      fab: auth.can(Scr.purchases, PermAction.add)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseForm())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Purchase'),
            )
          : null,
      body: list.isEmpty
          ? const EmptyState(icon: Icons.inventory_outlined, text: 'No purchases yet', sub: 'Stock comes in through purchases')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = list[i];
                return AppCard(
                  onTap: () => _show(context, inv, p),
                  child: Row(children: [
                    Avatar(p.isReturn ? 'R' : 'P', color: p.isReturn ? AppColors.red : AppColors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p.isReturn ? 'Return' : 'Purchase'} #${p.no} · ${inv.companyName(p.companyId)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${dateTimeFmt(p.date)} · ${p.items.length} items',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ),
                    Text(money(p.net), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ).entrance(i);
              },
            ),
    );
  }

  PrintDoc _doc(InventoryController inv, Purchase p) => PrintDoc(
        title: p.isReturn ? 'PURCHASE RETURN' : 'PURCHASE',
        number: '#${p.no}',
        date: p.date,
        partyLines: [inv.companyName(p.companyId)],
        headers: ['Item', 'Qty', 'Bonus', 'Rate', 'Batch', 'Amount'],
        rows: [
          for (final i in p.items)
            [
              inv.productName(i.productId),
              inv.product(i.productId)?.packLabel(i.qty) ?? '${i.qty}',
              '${i.bonus}',
              num2(i.rate),
              i.batchNo,
              num0(i.amount),
            ]
        ],
        totals: [
          MapEntry('Gross', money(p.gross)),
          if (p.discount > 0) MapEntry('Discount', money(p.discount)),
          MapEntry('Net', money(p.net)),
        ],
        note: p.note,
      );

  void _show(BuildContext context, InventoryController inv, Purchase p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.7,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Row(children: [
            Expanded(
              child: Text('${p.isReturn ? 'Purchase Return' : 'Purchase'} #${p.no}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            PrintMenu(
              onShare: () => PdfService.instance.share(_doc(inv, p), 'purchase_${p.no}.pdf'),
              onPrint: () => PdfService.instance.printDoc(_doc(inv, p)),
            ),
          ]),
          Text('${inv.companyName(p.companyId)} · ${dateTimeFmt(p.date)}', style: const TextStyle(color: AppColors.muted)),
          const Gap(),
          for (final i in p.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(inv.productName(i.productId)),
              subtitle: Text(
                  '${inv.product(i.productId)?.packLabel(i.qty) ?? i.qty}${i.bonus > 0 ? ' + ${i.bonus} bonus' : ''} @ ${num2(i.rate)}'
                  '${i.batchNo.isNotEmpty ? ' · Batch ${i.batchNo}' : ''}${i.expiry != null ? ' · Exp ${dateFmt(i.expiry!)}' : ''}'),
              trailing: Text(num0(i.amount)),
            ),
          const Divider(),
          KV('Gross', money(p.gross)),
          if (p.discount > 0) KV('Discount', money(p.discount)),
          KV('Net amount', money(p.net), bold: true),
        ]),
      ),
    );
  }
}

class PurchaseForm extends StatefulWidget {
  const PurchaseForm({super.key});

  @override
  State<PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<PurchaseForm> {
  final Purchase p = Purchase(id: newId(), no: 0, companyId: '');
  final _disc = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  Future<void> _addItem(InventoryController inv, [PurchaseItem? existing]) async {
    Product? prod = existing == null ? null : inv.product(existing.productId);
    if (prod == null) {
      final candidates = inv.activeProducts.where((x) => p.companyId.isEmpty || x.companyId == p.companyId).toList();
      prod = await pickFromList<Product>(
        context,
        title: 'Select product',
        items: candidates,
        label: (x) => x.name,
        subtitle: (x) => 'Stock ${x.packLabel(inv.warehouseQty(x.id))} · Cost ${num2(x.costPrice)}',
      );
    }
    if (prod == null || !mounted) return;
    final it = existing ?? PurchaseItem(productId: prod.id, rate: prod.costPrice);
    final ctn = TextEditingController(text: existing == null ? '' : '${it.qty ~/ prod.piecesPerCarton}');
    final pcs = TextEditingController(text: existing == null ? '' : '${it.qty % prod.piecesPerCarton}');
    final bonus = TextEditingController(text: it.bonus == 0 ? '' : '${it.bonus}');
    final rate = TextEditingController(text: it.rate == 0 ? '' : '${it.rate}');
    final batch = TextEditingController(text: it.batchNo);
    DateTime? expiry = it.expiry;
    final product = prod;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('1 carton = ${product.boxesPerCarton} box = ${product.piecesPerCarton} pcs',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const Gap(),
            Row(children: [
              Expanded(child: NumField(ctn, 'Cartons', decimal: false)),
              const Gap(),
              Expanded(child: NumField(pcs, 'Loose pieces', decimal: false)),
            ]),
            const Gap(),
            Row(children: [
              Expanded(child: NumField(bonus, 'Bonus / free pcs', decimal: false)),
              const Gap(),
              Expanded(child: NumField(rate, 'Rate per piece')),
            ]),
            if (!p.isReturn) ...[
              const Gap(),
              Row(children: [
                Expanded(child: TextField(controller: batch, decoration: const InputDecoration(labelText: 'Batch no.'))),
                const Gap(),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(expiry == null ? 'Expiry' : dateFmt(expiry!)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: c,
                        initialDate: expiry ?? DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (d != null) set(() => expiry = d);
                    },
                  ),
                ),
              ]),
            ],
            const Gap(16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add to purchase')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      it.qty = product.toPieces(cartons: int.tryParse(ctn.text) ?? 0, pieces: int.tryParse(pcs.text) ?? 0);
      it.bonus = int.tryParse(bonus.text) ?? 0;
      it.rate = double.tryParse(rate.text) ?? 0;
      it.batchNo = batch.text.trim();
      it.expiry = expiry;
      if (existing == null) p.items.add(it);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    p.discount = double.tryParse(_disc.text) ?? 0;
    p.note = _note.text.trim();
    final err = await context.read<InventoryController>().savePurchase(p);
    if (!mounted) return;
    setState(() => _saving = false);
    if (handleResult(context, err, success: p.isReturn ? 'Purchase return saved' : 'Purchase saved – stock updated')) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    p.discount = double.tryParse(_disc.text) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(p.isReturn ? 'Purchase Return' : 'New Purchase')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Purchase'), icon: Icon(Icons.download_rounded)),
            ButtonSegment(value: true, label: Text('Return to company'), icon: Icon(Icons.upload_rounded)),
          ],
          selected: {p.isReturn},
          onSelectionChanged: (s) => setState(() => p.isReturn = s.first),
        ),
        const Gap(),
        DropdownButtonFormField<String>(
          value: p.companyId.isEmpty ? null : p.companyId,
          decoration: const InputDecoration(labelText: 'Company / supplier'),
          items: [for (final c in inv.companies.where((c) => c.active)) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (v) => setState(() => p.companyId = v ?? ''),
        ),
        SectionTitle('Items (${p.items.length})',
            trailing: TextButton.icon(
                onPressed: () => _addItem(inv), icon: const Icon(Icons.add_rounded), label: const Text('Add item'))),
        if (p.items.isEmpty)
          const AppCard(child: Text('No items added yet', style: TextStyle(color: AppColors.muted))),
        for (var i = 0; i < p.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: ValueKey(p.items[i]),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              onDismissed: (_) => setState(() => p.items.removeAt(i)),
              child: AppCard(
                onTap: () => _addItem(inv, p.items[i]),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(inv.productName(p.items[i].productId), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${inv.product(p.items[i].productId)?.packLabel(p.items[i].qty)}'
                        '${p.items[i].bonus > 0 ? ' + ${p.items[i].bonus} bonus' : ''} @ ${num2(p.items[i].rate)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ]),
                  ),
                  Text(num0(p.items[i].amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        const Gap(),
        NumField(_disc, 'Discount (${AppConfig.currency})', onChanged: (_) => setState(() {})),
        const Gap(),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note / company bill no.')),
        const Gap(),
        AppCard(
          child: Column(children: [
            KV('Gross', money(p.gross)),
            KV('Discount', money(p.discount)),
            KV('Net payable', money(p.net), bold: true),
          ]),
        ),
        const Gap(20),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(p.isReturn ? 'Save return' : 'Save purchase'),
        ),
      ]),
    );
  }
}
