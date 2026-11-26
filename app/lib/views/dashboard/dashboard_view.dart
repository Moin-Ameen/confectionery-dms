import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/permissions.dart';
import '../../controllers/report_controller.dart';
import '../../controllers/shop_controller.dart';
import '../../controllers/sync_controller.dart';
import '../../models/user.dart';
import '../../services/settings_service.dart';
import '../shell/home_shell.dart';
import '../shell/shell_page.dart';
import '../widgets/common.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final rep = context.watch<ReportController>();
    final sync = context.watch<SyncController>();
    final shops = context.watch<ShopController>();
    final u = auth.user!;
    final d = rep.dashboard();
    final isField = u.role.isField;
    final seeMoney = auth.can(Scr.finReports) || u.role == UserRole.owner;

    final todayRoutes = shops.routes.where((r) => r.isToday()).toList();
    final myRouteShops = u.routeId.isEmpty ? 0 : shops.shopsOnRoute(u.routeId).length;

    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => sync.syncNow(),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 26),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
                  ),
                  const Spacer(),
                  _SyncPill(sync: sync),
                ]),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$greet,', style: const TextStyle(color: Colors.white70)),
                    Text(u.name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${SettingsService.instance.businessName} · ${DateFormat('EEEE, dd MMM').format(DateTime.now())}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _HeroStat(label: 'Today\'s sale', value: money(d.todaySale), icon: Icons.trending_up_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _HeroStat(label: 'Today\'s recovery', value: money(d.todayRecovery), icon: Icons.payments_rounded)),
                ]).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.list(children: [
              if (!isField) ...[
                const SectionTitle('Business overview'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    StatCard(
                        title: 'Stock value',
                        value: money(d.stockValue),
                        icon: Icons.warehouse_rounded,
                        color: AppColors.purple,
                        onTap: auth.can(Scr.stock) ? () => openScreen(Scr.stock) : null),
                    StatCard(
                        title: 'Market outstanding',
                        value: money(d.outstanding),
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.amber,
                        onTap: auth.can(Scr.outstanding) ? () => openScreen(Scr.outstanding) : null),
                    if (seeMoney)
                      StatCard(
                          title: 'Today\'s profit',
                          value: money(d.todayProfit),
                          icon: Icons.savings_rounded,
                          color: d.todayProfit >= 0 ? AppColors.green : AppColors.red),
                    if (seeMoney)
                      StatCard(
                          title: 'This month profit',
                          value: money(d.monthProfit),
                          icon: Icons.insights_rounded,
                          color: d.monthProfit >= 0 ? AppColors.teal : AppColors.red,
                          onTap: auth.can(Scr.finReports) ? () => openScreen(Scr.finReports) : null),
                  ].asMap().entries.map((e) => e.value.entrance(e.key)).toList(),
                ),
              ],
              if (isField) ...[
                const SectionTitle('My day'),
                AppCard(
                  child: Column(children: [
                    KV('My route', u.routeId.isEmpty ? 'All routes' : shops.routeName(u.routeId)),
                    KV('Shops on my route', '$myRouteShops'),
                    if (u.vanName.isNotEmpty) KV('Van', u.vanName),
                    KV('Today\'s routes', todayRoutes.isEmpty ? '-' : todayRoutes.map((r) => r.name).join(', ')),
                  ]),
                ).entrance(0),
              ],
              _PendingTiles(d: d),
              const SectionTitle('Sales – last 7 days'),
              AppCard(child: _BarChart(data: d.last7DaysSales)).entrance(3),
              const SectionTitle('Quick actions'),
              _QuickActions(role: u.role),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

class _SyncPill extends StatelessWidget {
  final SyncController sync;
  const _SyncPill({required this.sync});

  @override
  Widget build(BuildContext context) {
    final txt = !sync.configured
        ? 'Offline mode'
        : sync.syncing
            ? 'Syncing...'
            : sync.online
                ? (sync.pendingChanges == 0 ? 'All synced' : '${sync.pendingChanges} to sync')
                : 'Offline · ${sync.pendingChanges}';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openScreen(Scr.settings),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (sync.syncing)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            Icon(sync.online && sync.configured ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(txt, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _PendingTiles extends StatelessWidget {
  final DashboardData d;
  const _PendingTiles({required this.d});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final tiles = <Widget>[];
    void add(String key, String label, int count, IconData icon, Color c) {
      if (count <= 0 || !auth.can(key)) return;
      tiles.add(AppCard(
        onTap: () => openScreen(key),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ));
    }

    final canApproveOrders = auth.can(Scr.orders, 'approve');
    if (canApproveOrders) add(Scr.orders, 'Orders waiting approval', d.pendingOrders, Icons.receipt_long_rounded, AppColors.amber);
    if (auth.can(Scr.slips, 'approve')) add(Scr.slips, 'Recovery slips to approve', d.pendingSlips, Icons.fact_check_rounded, AppColors.teal);
    if (auth.can(Scr.returns, 'approve')) add(Scr.returns, 'Returns to approve', d.pendingReturns, Icons.assignment_return_rounded, AppColors.purple);
    add(Scr.alerts, 'Low stock items', d.lowStock, Icons.inventory_2_rounded, AppColors.red);
    add(Scr.alerts, 'Near expiry batches', d.nearExpiry, Icons.event_busy_rounded, AppColors.red);
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Needs attention'),
      for (var i = 0; i < tiles.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: tiles[i].entrance(i)),
    ]);
  }
}

class _BarChart extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final max = data.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (data[i].value > 0)
                  FittedBox(
                    child: Text(_compact(data[i].value), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: max <= 0 ? 0.02 : (data[i].value / max).clamp(0.02, 1.0)),
                  duration: Duration(milliseconds: 600 + i * 60),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Container(
                    height: 110 * v,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: i == data.length - 1
                            ? [AppColors.navy, AppColors.blue]
                            : [AppColors.blue.withValues(alpha: 0.55), AppColors.blue.withValues(alpha: 0.25)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(DateFormat('EEE').format(DateTime.parse(data[i].key)),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == data.length - 1 ? FontWeight.w700 : FontWeight.w400,
                        color: i == data.length - 1 ? null : AppColors.muted)),
              ]),
            ),
        ],
      ),
    );
  }

  String _compact(double v) => v >= 100000
      ? '${(v / 100000).toStringAsFixed(1)}L'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}K'
          : v.toStringAsFixed(0);
}

class _QuickActions extends StatelessWidget {
  final UserRole role;
  const _QuickActions({required this.role});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final items = <(String, IconData, Color)>[
      (Scr.booking, Icons.add_shopping_cart_rounded, AppColors.navy),
      (Scr.delivery, Icons.delivery_dining_rounded, AppColors.teal),
      (Scr.recovery, Icons.payments_rounded, AppColors.green),
      (Scr.returns, Icons.assignment_return_rounded, AppColors.purple),
      (Scr.purchases, Icons.inventory_rounded, AppColors.amber),
      (Scr.loadSheets, Icons.local_shipping_rounded, AppColors.blue),
      (Scr.expenses, Icons.money_off_rounded, AppColors.red),
      (Scr.salesmanReport, Icons.assignment_ind_rounded, AppColors.teal),
      (Scr.liveMap, Icons.my_location_rounded, AppColors.green),
      (Scr.shops, Icons.storefront_rounded, AppColors.navy),
      (Scr.products, Icons.cookie_rounded, AppColors.amber),
      (Scr.cashbook, Icons.menu_book_rounded, AppColors.purple),
    ].where((e) => auth.can(e.$1)).take(8).toList();

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.82,
      children: [
        for (var i = 0; i < items.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => openScreen(items[i].$1),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(gradient: AppColors.soft(items[i].$3), borderRadius: BorderRadius.circular(18)),
                child: Icon(items[i].$2, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(Scr.titles[items[i].$1]!.split(' ').first,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), maxLines: 1),
            ]),
          ).entrance(i),
      ],
    );
  }
}
