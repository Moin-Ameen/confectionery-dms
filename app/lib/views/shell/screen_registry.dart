import 'package:flutter/material.dart';

import '../../controllers/permissions.dart';
import '../../models/user.dart';
import '../accounts/cashbook_view.dart';
import '../accounts/chart_view.dart';
import '../accounts/expenses_view.dart';
import '../accounts/fin_reports_view.dart';
import '../accounts/ledgers_view.dart';
import '../accounts/vouchers_view.dart';
import '../admin/activity_log_view.dart';
import '../admin/settings_view.dart';
import '../admin/users_view.dart';
import '../booking/book_order_view.dart';
import '../booking/routes_view.dart';
import '../booking/schemes_view.dart';
import '../booking/shops_view.dart';
import '../dashboard/dashboard_view.dart';
import '../dispatch/delivery_view.dart';
import '../dispatch/load_sheets_view.dart';
import '../dispatch/orders_view.dart';
import '../gps/live_map_view.dart';
import '../gps/route_history_view.dart';
import '../inventory/alerts_view.dart';
import '../inventory/companies_view.dart';
import '../inventory/products_view.dart';
import '../inventory/purchases_view.dart';
import '../inventory/stock_view.dart';
import '../recovery/outstanding_view.dart';
import '../recovery/recovery_view.dart';
import '../recovery/slips_view.dart';
import '../reports/commission_view.dart';
import '../reports/performance_view.dart';
import '../reports/salesman_report_view.dart';
import '../returns/returns_view.dart';

class ScreenDef {
  final String key;
  final IconData icon;
  final String group;
  final Widget Function() builder;
  const ScreenDef(this.key, this.icon, this.group, this.builder);

  String get title => Scr.titles[key] ?? key;
}

class Groups {
  static const overview = 'Overview';
  static const stock = 'Stock & Inventory';
  static const booking = 'Booker & Shops';
  static const dispatch = 'Dispatch & Invoicing';
  static const returns = 'Returns';
  static const recovery = 'Recovery';
  static const accounts = 'Accounts';
  static const reports = 'Salesman Reports';
  static const gps = 'GPS Tracking';
  static const admin = 'Admin';
}

final List<ScreenDef> screens = [
  ScreenDef(Scr.dashboard, Icons.space_dashboard_rounded, Groups.overview, () => const DashboardView()),
  // Booking
  ScreenDef(Scr.booking, Icons.add_shopping_cart_rounded, Groups.booking, () => const BookOrderView()),
  ScreenDef(Scr.shops, Icons.storefront_rounded, Groups.booking, () => const ShopsView()),
  ScreenDef(Scr.routes, Icons.alt_route_rounded, Groups.booking, () => const RoutesView()),
  ScreenDef(Scr.schemes, Icons.local_offer_rounded, Groups.booking, () => const SchemesView()),
  // Dispatch
  ScreenDef(Scr.orders, Icons.receipt_long_rounded, Groups.dispatch, () => const OrdersView()),
  ScreenDef(Scr.loadSheets, Icons.local_shipping_rounded, Groups.dispatch, () => const LoadSheetsView()),
  ScreenDef(Scr.delivery, Icons.delivery_dining_rounded, Groups.dispatch, () => const DeliveryView()),
  // Recovery
  ScreenDef(Scr.recovery, Icons.payments_rounded, Groups.recovery, () => const RecoveryView()),
  ScreenDef(Scr.slips, Icons.fact_check_rounded, Groups.recovery, () => const SlipsView()),
  ScreenDef(Scr.outstanding, Icons.account_balance_wallet_rounded, Groups.recovery, () => const OutstandingView()),
  // Returns
  ScreenDef(Scr.returns, Icons.assignment_return_rounded, Groups.returns, () => const ReturnsView()),
  // Stock
  ScreenDef(Scr.products, Icons.cookie_rounded, Groups.stock, () => const ProductsView()),
  ScreenDef(Scr.companies, Icons.factory_rounded, Groups.stock, () => const CompaniesView()),
  ScreenDef(Scr.purchases, Icons.inventory_rounded, Groups.stock, () => const PurchasesView()),
  ScreenDef(Scr.stock, Icons.warehouse_rounded, Groups.stock, () => const StockView()),
  ScreenDef(Scr.vanStock, Icons.airport_shuttle_rounded, Groups.stock, () => const VanStockView()),
  ScreenDef(Scr.adjust, Icons.tune_rounded, Groups.stock, () => const AdjustView()),
  ScreenDef(Scr.alerts, Icons.notification_important_rounded, Groups.stock, () => const AlertsView()),
  // Accounts
  ScreenDef(Scr.cashbook, Icons.menu_book_rounded, Groups.accounts, () => const CashBookView()),
  ScreenDef(Scr.expenses, Icons.money_off_rounded, Groups.accounts, () => const ExpensesView()),
  ScreenDef(Scr.vouchers, Icons.receipt_rounded, Groups.accounts, () => const VouchersView()),
  ScreenDef(Scr.ledgers, Icons.library_books_rounded, Groups.accounts, () => const LedgersView()),
  ScreenDef(Scr.finReports, Icons.query_stats_rounded, Groups.accounts, () => const FinReportsView()),
  ScreenDef(Scr.chartAccounts, Icons.account_tree_rounded, Groups.accounts, () => const ChartView()),
  // Reports
  ScreenDef(Scr.salesmanReport, Icons.assignment_ind_rounded, Groups.reports, () => const SalesmanReportView()),
  ScreenDef(Scr.performance, Icons.emoji_events_rounded, Groups.reports, () => const PerformanceView()),
  ScreenDef(Scr.commission, Icons.percent_rounded, Groups.reports, () => const CommissionView()),
  // GPS
  ScreenDef(Scr.liveMap, Icons.my_location_rounded, Groups.gps, () => const LiveMapView()),
  ScreenDef(Scr.routeHistory, Icons.timeline_rounded, Groups.gps, () => const RouteHistoryView()),
  // Admin
  ScreenDef(Scr.users, Icons.manage_accounts_rounded, Groups.admin, () => const UsersView()),
  ScreenDef(Scr.activityLog, Icons.history_rounded, Groups.admin, () => const ActivityLogView()),
  ScreenDef(Scr.settings, Icons.settings_rounded, Groups.admin, () => const SettingsView()),
];

ScreenDef screenOf(String key) => screens.firstWhere((s) => s.key == key);

/// Bottom navigation favourites per role.
List<String> quickScreens(UserRole r) {
  switch (r) {
    case UserRole.owner:
    case UserRole.manager:
      return [Scr.dashboard, Scr.orders, Scr.slips, Scr.outstanding];
    case UserRole.accountant:
      return [Scr.dashboard, Scr.vouchers, Scr.ledgers, Scr.finReports];
    case UserRole.cashier:
      return [Scr.dashboard, Scr.slips, Scr.cashbook, Scr.expenses];
    case UserRole.storekeeper:
      return [Scr.dashboard, Scr.stock, Scr.loadSheets, Scr.purchases];
    case UserRole.booker:
      return [Scr.dashboard, Scr.booking, Scr.orders, Scr.shops];
    case UserRole.salesman:
      return [Scr.dashboard, Scr.delivery, Scr.recovery, Scr.vanStock];
  }
}
