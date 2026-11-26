import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/inventory_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/product.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class AlertsView extends StatelessWidget {
  const AlertsView({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryController>();
    final users = context.watch<UserController>();
    final low = inv.lowStock;
    final exp = inv.nearExpiry;
    return DefaultTabController(
      length: 2,
      child: ShellPage(
        title: 'Stock Alerts',
        bottom: TabBar(tabs: [
          Tab(text: 'Low stock (${low.length})'),
          Tab(text: 'Near expiry (${exp.length})'),
        ]),
        body: TabBarView(children: [
          low.isEmpty
              ? const EmptyState(icon: Icons.check_circle_outline, text: 'All stock levels are fine')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: low.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = low[i];
                    return AppCard(
                      child: Row(children: [
                        const Icon(Icons.inventory_2_outlined, color: AppColors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Alert level ${p.packLabel(p.lowStockPieces)} · ${inv.companyName(p.companyId)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                        Text(p.packLabel(inv.warehouseQty(p.id)),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.red)),
                      ]),
                    ).entrance(i);
                  },
                ),
          exp.isEmpty
              ? const EmptyState(icon: Icons.event_available_outlined, text: 'No batch is near expiry')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: exp.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = exp[i];
                    final days = a.batch.daysToExpiry ?? 0;
                    final loc = a.location == StockLoc.warehouse
                        ? 'Warehouse'
                        : 'Van – ${users.nameOf(StockLoc.vanUser(a.location))}';
                    return AppCard(
                      child: Row(children: [
                        Container(
                          width: 54,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: (days < 0 ? AppColors.red : AppColors.amber).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            Text('$days', style: TextStyle(fontWeight: FontWeight.w800, color: days < 0 ? AppColors.red : AppColors.amber)),
                            const Text('days', style: TextStyle(fontSize: 10)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Batch ${a.batch.batchNo.isEmpty ? '-' : a.batch.batchNo} · Exp ${dateFmt(a.batch.expiry!)} · $loc',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                        Text(a.product.packLabel(a.batch.qty), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ).entrance(i);
                  },
                ),
        ]),
      ),
    );
  }
}
