import '../models/user.dart';

/// Screen keys (used for role permissions and navigation).
class Scr {
  static const dashboard = 'dashboard';
  // Stock & inventory
  static const products = 'products';
  static const companies = 'companies';
  static const purchases = 'purchases';
  static const stock = 'stock';
  static const vanStock = 'vanStock';
  static const adjust = 'adjust';
  static const alerts = 'alerts';
  // Booker, shops
  static const routes = 'routes';
  static const shops = 'shops';
  static const booking = 'booking';
  static const schemes = 'schemes';
  // Dispatch
  static const orders = 'orders';
  static const loadSheets = 'loadSheets';
  static const delivery = 'delivery';
  // Returns
  static const returns = 'returns';
  // Recovery
  static const recovery = 'recovery';
  static const slips = 'slips';
  static const outstanding = 'outstanding';
  // Accounts
  static const chartAccounts = 'chartAccounts';
  static const vouchers = 'vouchers';
  static const ledgers = 'ledgers';
  static const cashbook = 'cashbook';
  static const expenses = 'expenses';
  static const finReports = 'finReports';
  // Reports
  static const salesmanReport = 'salesmanReport';
  static const performance = 'performance';
  static const commission = 'commission';
  // GPS
  static const liveMap = 'liveMap';
  static const routeHistory = 'routeHistory';
  // Admin
  static const users = 'users';
  static const activityLog = 'activityLog';
  static const settings = 'settings';

  static const all = [
    dashboard, products, companies, purchases, stock, vanStock, adjust, alerts,
    routes, shops, booking, schemes, orders, loadSheets, delivery, returns,
    recovery, slips, outstanding, chartAccounts, vouchers, ledgers, cashbook, expenses, finReports,
    salesmanReport, performance, commission, liveMap, routeHistory, users, activityLog, settings,
  ];

  static const titles = {
    dashboard: 'Dashboard',
    products: 'Products',
    companies: 'Companies',
    purchases: 'Purchases',
    stock: 'Warehouse Stock',
    vanStock: 'Van Stock',
    adjust: 'Stock Count / Adjust',
    alerts: 'Stock Alerts',
    routes: 'Routes',
    shops: 'Shops & Credit',
    booking: 'Book Order',
    schemes: 'Schemes',
    orders: 'Orders & Approval',
    loadSheets: 'Load Sheets',
    delivery: 'Delivery & Invoice',
    returns: 'Returns',
    recovery: 'Recovery Entry',
    slips: 'Recovery Slips',
    outstanding: 'Outstanding',
    chartAccounts: 'Chart of Accounts',
    vouchers: 'Vouchers',
    ledgers: 'Ledgers',
    cashbook: 'Cash Book',
    expenses: 'Expenses',
    finReports: 'Financial Reports',
    salesmanReport: 'Salesman Daily Report',
    performance: 'Performance',
    commission: 'Commission',
    liveMap: 'Live Location',
    routeHistory: 'Route History',
    users: 'Users & Roles',
    activityLog: 'Activity Log',
    settings: 'Settings & Sync',
  };
}

Set<String> _grant(Map<String, List<String>> m) {
  final s = <String>{};
  m.forEach((screen, actions) {
    for (final a in actions) {
      s.add('$screen:$a');
    }
  });
  return s;
}

const _v = [PermAction.view];
const _va = [PermAction.view, PermAction.add];
const _vae = [PermAction.view, PermAction.add, PermAction.edit];
const _vap = [PermAction.view, PermAction.approve];
const _full = PermAction.all;

Set<String> defaultPermissions(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return _grant({for (final s in Scr.all) s: _full});
    case UserRole.manager:
      final m = {for (final s in Scr.all) s: _full};
      m[Scr.users] = _v;
      m[Scr.settings] = _v;
      return _grant(m);
    case UserRole.accountant:
      return _grant({
        Scr.dashboard: _v,
        Scr.chartAccounts: _full,
        Scr.vouchers: _full,
        Scr.ledgers: _v,
        Scr.cashbook: _va,
        Scr.expenses: _full,
        Scr.finReports: _v,
        Scr.outstanding: _v,
        Scr.slips: _vap,
        Scr.purchases: _v,
        Scr.returns: _v,
        Scr.salesmanReport: _v,
        Scr.performance: _v,
        Scr.commission: _v,
        Scr.settings: _v,
      });
    case UserRole.cashier:
      return _grant({
        Scr.dashboard: _v,
        Scr.slips: _vap,
        Scr.cashbook: _va,
        Scr.expenses: _va,
        Scr.outstanding: _v,
        Scr.ledgers: _v,
        Scr.salesmanReport: _v,
        Scr.settings: _v,
      });
    case UserRole.storekeeper:
      return _grant({
        Scr.dashboard: _v,
        Scr.products: _vae,
        Scr.companies: _vae,
        Scr.purchases: _full,
        Scr.stock: _v,
        Scr.vanStock: _va,
        Scr.adjust: _va,
        Scr.alerts: _v,
        Scr.orders: _v,
        Scr.loadSheets: _vae,
        Scr.returns: _vap,
        Scr.settings: _v,
      });
    case UserRole.booker:
      return _grant({
        Scr.dashboard: _v,
        Scr.routes: _v,
        Scr.shops: _vae,
        Scr.booking: _va,
        Scr.orders: [PermAction.view, PermAction.edit],
        Scr.schemes: _v,
        Scr.outstanding: _v,
        Scr.settings: _v,
      });
    case UserRole.salesman:
      return _grant({
        Scr.dashboard: _v,
        Scr.shops: _v,
        Scr.delivery: _vae,
        Scr.vanStock: _v,
        Scr.recovery: _vae,
        Scr.returns: _va,
        Scr.outstanding: _v,
        Scr.salesmanReport: _v,
        Scr.settings: _v,
      });
  }
}
