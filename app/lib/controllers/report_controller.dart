import '../models/base_model.dart';
import '../models/order.dart';
import '../models/recovery.dart';
import '../models/user.dart';
import 'accounts_controller.dart';
import 'base_controller.dart';
import 'inventory_controller.dart';
import 'order_controller.dart';
import 'recovery_controller.dart';
import 'return_controller.dart';
import 'shop_controller.dart';
import 'user_controller.dart';

class DashboardData {
  final double todaySale;
  final double todayRecovery;
  final double stockValue;
  final double outstanding;
  final double todayProfit;
  final double monthProfit;
  final int pendingOrders;
  final int pendingReturns;
  final int pendingSlips;
  final int lowStock;
  final int nearExpiry;
  final List<MapEntry<String, double>> last7DaysSales;

  DashboardData({
    required this.todaySale,
    required this.todayRecovery,
    required this.stockValue,
    required this.outstanding,
    required this.todayProfit,
    required this.monthProfit,
    required this.pendingOrders,
    required this.pendingReturns,
    required this.pendingSlips,
    required this.lowStock,
    required this.nearExpiry,
    required this.last7DaysSales,
  });
}

class SalesmanDay {
  final AppUser user;
  final int invoices;
  final double sale;
  final double recovery;
  final double returns;
  final double cashHanded;
  final double shortExcess; // + short, - excess
  final String slipStatus;
  SalesmanDay(this.user, this.invoices, this.sale, this.recovery, this.returns, this.cashHanded, this.shortExcess, this.slipStatus);
}

class PerfRow {
  final AppUser user;
  final double target;
  final double achieved;
  final int orders;
  final int productiveShops;
  final int totalShops;
  final double recovery;
  PerfRow(this.user, this.target, this.achieved, this.orders, this.productiveShops, this.totalShops, this.recovery);

  double get pct => target > 0 ? achieved / target * 100 : 0;
}

class CommissionRow {
  final AppUser user;
  final double sale;
  final double recovery;
  CommissionRow(this.user, this.sale, this.recovery);
  double get saleCommission => sale * user.commissionSalePct / 100;
  double get recoveryCommission => recovery * user.commissionRecoveryPct / 100;
  double get total => saleCommission + recoveryCommission;
}

class ReportController extends BaseController {
  final OrderController orders;
  final RecoveryController recovery;
  final ReturnController returns;
  final InventoryController inv;
  final AccountsController accounts;
  final ShopController shops;
  final UserController users;

  ReportController(this.orders, this.recovery, this.returns, this.inv, this.accounts, this.shops, this.users);

  DashboardData dashboard() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final u = Session.user;
    final sid = (u != null && u.role == UserRole.salesman) ? u.id : null;

    final last7 = <MapEntry<String, double>>[];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final v = orders.invoicesOn(d, salesmanId: sid).fold(0.0, (s, o) => s + o.net);
      last7.add(MapEntry(dayKey(d), v));
    }
    final balances = accounts.allShopBalances().values.fold(0.0, (s, v) => s + v);
    return DashboardData(
      todaySale: orders.invoicesOn(today, salesmanId: sid).fold(0.0, (s, o) => s + o.net),
      todayRecovery: recovery.recoveredOn(today, salesmanId: sid),
      stockValue: inv.stockValue,
      outstanding: balances,
      todayProfit: accounts.profitLoss(from: today, to: today.add(const Duration(days: 1))).netProfit,
      monthProfit: accounts.profitLoss(from: DateTime(now.year, now.month, 1)).netProfit,
      pendingOrders: orders.byStatus(OrderStatus.pending).length,
      pendingReturns: returns.pending.length,
      pendingSlips: recovery.slips.where((s) => s.status == SlipStatus.submitted).length,
      lowStock: inv.lowStock.length,
      nearExpiry: inv.nearExpiry.length,
      last7DaysSales: last7,
    );
  }

  SalesmanDay salesmanDay(AppUser s, DateTime day) {
    final inv = orders.invoicesOn(day, salesmanId: s.id);
    final slip = recovery.slipFor(s.id, day);
    final sum = slip == null ? null : recovery.summary(slip);
    return SalesmanDay(
      s,
      inv.length,
      inv.fold(0.0, (a, o) => a + o.net),
      recovery.recoveredOn(day, salesmanId: s.id),
      returns.totalOn(day, userId: s.id),
      sum?.cash ?? 0,
      (sum == null || slip!.status == SlipStatus.open) ? 0 : sum.shortExcess,
      slip?.status ?? '-',
    );
  }

  bool _inMonth(DateTime d, DateTime month) => d.year == month.year && d.month == month.month;

  List<PerfRow> performance(DateTime month) {
    final rows = <PerfRow>[];
    final all = orders.orders;
    for (final u in users.fieldUsers) {
      final isBooker = u.role == UserRole.booker;
      final mine = all.where((o) =>
          (isBooker ? o.bookerId == u.id : o.salesmanId == u.id) &&
          o.status != OrderStatus.rejected &&
          o.status != OrderStatus.cancelled &&
          _inMonth(o.date, month));
      final achieved = isBooker
          ? mine.fold(0.0, (s, o) => s + o.net)
          : mine.where((o) => o.status == OrderStatus.delivered).fold(0.0, (s, o) => s + o.net);
      final productive = mine.map((o) => o.shopId).toSet().length;
      final total = u.routeId.isEmpty ? shops.activeShops.length : shops.shopsOnRoute(u.routeId).length;
      final rec = recovery.recoveries
          .where((r) => r.salesmanId == u.id && _inMonth(r.date, month))
          .fold(0.0, (s, r) => s + r.amount);
      rows.add(PerfRow(u, u.monthlyTarget, achieved, mine.length, productive, total, rec));
    }
    rows.sort((a, b) => b.achieved.compareTo(a.achieved));
    return rows;
  }

  List<CommissionRow> commission(DateTime month) {
    final rows = <CommissionRow>[];
    for (final u in users.fieldUsers) {
      final isBooker = u.role == UserRole.booker;
      final sale = orders.orders
          .where((o) =>
              o.status == OrderStatus.delivered &&
              (isBooker ? o.bookerId == u.id : o.salesmanId == u.id) &&
              _inMonth(o.invoicedAt ?? o.date, month))
          .fold(0.0, (s, o) => s + o.net);
      final rec = recovery.recoveries
          .where((r) => r.salesmanId == u.id && _inMonth(r.date, month))
          .fold(0.0, (s, r) => s + r.amount);
      rows.add(CommissionRow(u, sale, rec));
    }
    return rows;
  }
}
