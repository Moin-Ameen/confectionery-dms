import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/permissions.dart';
import '../../models/base_model.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  String _q = '';
  String _cat = 'All';

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final auth = context.watch<AuthController>();
    final list = inv.products
        .where((p) =>
            (_cat == 'All' || p.category == _cat) &&
            (_q.isEmpty || p.name.toLowerCase().contains(_q) || inv.companyName(p.companyId).toLowerCase().contains(_q)))
        .toList();

    return ShellPage(
      title: 'Products',
      fab: auth.can(Scr.products, PermAction.add)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductForm())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Product'),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchField(hint: 'Search product or company', onChanged: (v) => setState(() => _q = v.toLowerCase())),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in ['All', ...productCategories])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _cat == c,
                    onSelected: (_) => setState(() => _cat = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.cookie_outlined, text: 'No products yet', sub: 'Add candies, chocolates, biscuits and gums')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final stock = inv.warehouseQty(p.id);
                    final low = p.lowStockPieces > 0 && stock <= p.lowStockPieces;
                    return AppCard(
                      onTap: auth.can(Scr.products, PermAction.edit)
                          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(product: p)))
                          : null,
                      child: Row(children: [
                        Avatar(p.name.isEmpty ? '?' : p.name[0].toUpperCase(), color: _catColor(p.category)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${inv.companyName(p.companyId)} · ${p.category} · ${p.piecesPerBox}×${p.boxesPerCarton}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            Text('TP ${num2(p.tp)} · RP ${num2(p.rp)}', style: const TextStyle(fontSize: 12)),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(p.packLabel(stock),
                              style: TextStyle(fontWeight: FontWeight.w700, color: low ? AppColors.red : null, fontSize: 12)),
                          const SizedBox(height: 4),
                          if (!p.active) const StatusChip('inactive', color: AppColors.muted),
                          if (low && p.active) const StatusChip('low stock', color: AppColors.red),
                        ]),
                      ]),
                    ).entrance(i);
                  },
                ),
        ),
      ]),
    );
  }

  Color _catColor(String c) => const {
        'Candy': AppColors.red,
        'Chocolate': Color(0xFF7B4A2E),
        'Biscuit': AppColors.amber,
        'Gum': AppColors.green,
      }[c] ??
      AppColors.navy;
}

class ProductForm extends StatefulWidget {
  final Product? product;
  const ProductForm({super.key, this.product});

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  late final Product p;
  late final bool isNew;
  final _name = TextEditingController();
  final _ppb = TextEditingController();
  final _bpc = TextEditingController();
  final _cost = TextEditingController();
  final _tp = TextEditingController();
  final _rp = TextEditingController();
  final _low = TextEditingController();

  @override
  void initState() {
    super.initState();
    isNew = widget.product == null;
    p = widget.product ?? Product(id: newId(), name: '', companyId: '');
    _name.text = p.name;
    _ppb.text = '${p.piecesPerBox}';
    _bpc.text = '${p.boxesPerCarton}';
    _cost.text = p.costPrice == 0 ? '' : num2(p.costPrice).replaceAll(',', '');
    _tp.text = p.tp == 0 ? '' : num2(p.tp).replaceAll(',', '');
    _rp.text = p.rp == 0 ? '' : num2(p.rp).replaceAll(',', '');
    _low.text = p.lowStockPieces == 0 ? '' : '${p.lowStockPieces}';
  }

  Future<void> _save() async {
    p.name = _name.text.trim();
    p.piecesPerBox = int.tryParse(_ppb.text) ?? 1;
    p.boxesPerCarton = int.tryParse(_bpc.text) ?? 1;
    if (p.piecesPerBox <= 0) p.piecesPerBox = 1;
    if (p.boxesPerCarton <= 0) p.boxesPerCarton = 1;
    p.costPrice = double.tryParse(_cost.text) ?? 0;
    p.tp = double.tryParse(_tp.text) ?? 0;
    p.rp = double.tryParse(_rp.text) ?? 0;
    p.lowStockPieces = int.tryParse(_low.text) ?? 0;
    final err = await context.read<InventoryController>().saveProduct(p, isNew: isNew);
    if (!mounted) return;
    if (handleResult(context, err, success: 'Product saved')) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final companies = inv.companies.where((c) => c.active || c.id == p.companyId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New Product' : 'Edit Product')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Product name')),
        const Gap(),
        DropdownButtonFormField<String>(
          value: companies.any((c) => c.id == p.companyId) ? p.companyId : null,
          decoration: const InputDecoration(labelText: 'Company'),
          items: [for (final c in companies) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (v) => setState(() => p.companyId = v ?? ''),
        ),
        if (companies.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Add a company first from Companies screen', style: TextStyle(color: AppColors.red, fontSize: 12)),
          ),
        const Gap(),
        DropdownButtonFormField<String>(
          value: p.category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in productCategories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => p.category = v ?? 'Candy'),
        ),
        const SectionTitle('Packing (carton → box → piece)'),
        Row(children: [
          Expanded(child: NumField(_ppb, 'Pieces in 1 box', decimal: false)),
          const Gap(),
          Expanded(child: NumField(_bpc, 'Boxes in 1 carton', decimal: false)),
        ]),
        const SectionTitle('Prices (per piece)'),
        Row(children: [
          Expanded(child: NumField(_cost, 'Cost price')),
          const Gap(),
          Expanded(child: NumField(_tp, 'TP (trade)')),
          const Gap(),
          Expanded(child: NumField(_rp, 'RP (retail)')),
        ]),
        const Gap(),
        NumField(_low, 'Low stock alert at (pieces)', decimal: false),
        const Gap(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          value: p.active,
          onChanged: (v) => setState(() => p.active = v),
        ),
        const Gap(20),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('Save product')),
        if (!isNew) ...[
          const Gap(),
          Text('Warehouse stock: ${p.packLabel(inv.warehouseQty(p.id))}  ·  Value ${AppConfig.currency} ${num0(inv.warehouseQty(p.id) * p.costPrice)}',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ]),
    );
  }
}
