import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/shop_controller.dart';
import '../../models/base_model.dart';
import '../../models/shop.dart';
import '../../models/user.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class SchemesView extends StatelessWidget {
  const SchemesView({super.key});

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopController>();
    final inv = context.watch<InventoryController>();
    final auth = context.watch<AuthController>();
    final list = shops.schemes;
    final canEdit = auth.can(Scr.schemes, PermAction.edit);
    return ShellPage(
      title: 'Schemes & Discounts',
      fab: auth.can(Scr.schemes, PermAction.add)
          ? FloatingActionButton(onPressed: () => _edit(context, null), child: const Icon(Icons.add_rounded))
          : null,
      body: list.isEmpty
          ? const EmptyState(icon: Icons.local_offer_outlined, text: 'No schemes', sub: 'Trade offers, free pieces and slab discounts')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = list[i];
                final color = s.type == SchemeType.free
                    ? AppColors.green
                    : s.type == SchemeType.slab
                        ? AppColors.purple
                        : AppColors.amber;
                return AppCard(
                  onTap: canEdit ? () => _edit(context, s) : null,
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.local_offer_rounded, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(s.description, style: const TextStyle(fontSize: 12)),
                        Text(s.productId.isEmpty ? 'All products' : inv.productName(s.productId),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ),
                    StatusChip(s.active ? 'active' : 'off', color: s.active ? AppColors.green : AppColors.muted),
                  ]),
                ).entrance(i);
              },
            ),
    );
  }

  Future<void> _edit(BuildContext context, Scheme? existing) async {
    final isNew = existing == null;
    final s = existing ?? Scheme(id: newId(), name: '');
    final inv = context.read<InventoryController>();
    final name = TextEditingController(text: s.name);
    final minQ = TextEditingController(text: s.minQty == 0 ? '' : '${s.minQty}');
    final freeQ = TextEditingController(text: s.freeQty == 0 ? '' : '${s.freeQty}');
    final pct = TextEditingController(text: s.percent == 0 ? '' : '${s.percent}');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(isNew ? 'New scheme' : 'Edit scheme', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Scheme name')),
            const Gap(),
            SegmentedButton<SchemeType>(
              segments: const [
                ButtonSegment(value: SchemeType.free, label: Text('Free pcs')),
                ButtonSegment(value: SchemeType.slab, label: Text('Slab %')),
                ButtonSegment(value: SchemeType.discount, label: Text('Discount %')),
              ],
              selected: {s.type},
              onSelectionChanged: (v) => set(() => s.type = v.first),
            ),
            const Gap(),
            DropdownButtonFormField<String>(
              value: s.productId,
              decoration: const InputDecoration(labelText: 'Product'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All products')),
                for (final p in inv.activeProducts) DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => set(() => s.productId = v ?? ''),
            ),
            const Gap(),
            if (s.type != SchemeType.discount) NumField(minQ, s.type == SchemeType.free ? 'Buy (pieces)' : 'Minimum pieces', decimal: false),
            if (s.type == SchemeType.free) ...[const Gap(), NumField(freeQ, 'Get free (pieces)', decimal: false)],
            if (s.type != SchemeType.free) ...[const Gap(), NumField(pct, 'Discount %')],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: s.active,
              onChanged: (v) => set(() => s.active = v),
            ),
            FilledButton(
              onPressed: () async {
                s.name = name.text.trim();
                s.minQty = int.tryParse(minQ.text) ?? 0;
                s.freeQty = int.tryParse(freeQ.text) ?? 0;
                s.percent = double.tryParse(pct.text) ?? 0;
                final err = await context.read<ShopController>().saveScheme(s, isNew: isNew);
                if (!c.mounted) return;
                if (handleResult(c, err)) Navigator.pop(c);
              },
              child: const Text('Save scheme'),
            ),
          ]),
        ),
      ),
    );
  }
}
