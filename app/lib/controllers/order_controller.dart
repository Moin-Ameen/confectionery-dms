import '../config/app_config.dart';
import '../models/base_model.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/tracking.dart';
import '../models/user.dart';
import '../services/local_db.dart';
import 'accounts_controller.dart';
import 'base_controller.dart';
import 'inventory_controller.dart';
import 'shop_controller.dart';
import 'tracking_controller.dart';

class OrderController extends BaseController {
  final InventoryController inv;
  final AccountsController accounts;
  final ShopController shops;
  final TrackingController tracking;

  OrderController(this.inv, this.accounts, this.shops, this.tracking);

  String _money(double v) => '${AppConfig.currency} ${v.toStringAsFixed(0)}';

  // ---------------- Queries ----------------
  List<SaleOrder> get orders {
    final l = db.all(Col.orders).map(SaleOrder.fromMap).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  SaleOrder? byId(String id) {
    final m = db.get(Col.orders, id);
    return m == null ? null : SaleOrder.fromMap(m);
  }

  List<SaleOrder> byStatus(String status) => orders.where((o) => o.status == status).toList();

  /// Orders visible to the current user (field users see only their own).
  List<SaleOrder> get visibleOrders {
    final u = Session.user;
    if (u == null) return [];
    if (u.role == UserRole.booker) return orders.where((o) => o.bookerId == u.id).toList();
    if (u.role == UserRole.salesman) return orders.where((o) => o.salesmanId == u.id).toList();
    return orders;
  }

  List<SaleOrder> deliveriesFor(String salesmanId) =>
      orders.where((o) => o.salesmanId == salesmanId && o.status == OrderStatus.loaded).toList();

  List<SaleOrder> invoicesOn(DateTime day, {String? salesmanId}) {
    final k = dayKey(day);
    return orders
        .where((o) =>
            o.status == OrderStatus.delivered &&
            dayKey(o.invoicedAt ?? o.date) == k &&
            (salesmanId == null || o.salesmanId == salesmanId))
        .toList();
  }

  // ---------------- Booking ----------------
  /// Builds an order line using TP and active schemes.
  OrderItem buildItem(Product p, int qty) {
    final (free, pct) = shops.applySchemes(p.id, qty);
    return OrderItem(productId: p.id, qty: qty, freeQty: free, rate: p.tp, discountPct: pct);
  }

  Future<String?> book({
    required String shopId,
    required List<OrderItem> items,
    String notes = '',
    bool requestOverride = false,
  }) async {
    final lines = items.where((i) => i.qty > 0).toList();
    if (shopId.isEmpty) return 'Select a shop';
    if (lines.isEmpty) return 'Add at least one item';
    final shop = shops.shop(shopId);
    if (shop == null) return 'Shop not found';

    final o = SaleOrder(
      id: newId(),
      no: db.nextNo(Col.orders),
      shopId: shopId,
      bookerId: Session.userId,
      routeId: shop.routeId,
      items: lines,
      bookedItems: lines.map((e) => e.copy()).toList(),
      notes: notes,
    );
    final cc = shops.creditCheck(shopId, o.net);
    if (cc.exceeds) {
      if (!requestOverride) return 'CREDIT_LIMIT';
      o.creditHold = true;
    }
    final loc = await tracking.checkIn(PingKind.orderCheckIn, o.id, 'Order #${o.no} – ${shop.name}');
    if (loc != null) {
      o.lat = loc.$1;
      o.lng = loc.$2;
    }
    await db.put(Col.orders, o.toMap());
    await log('created', 'Order', refId: o.id,
        details: '#${o.no} ${shop.name} ${_money(o.net)}${o.creditHold ? ' (credit limit crossed – override requested)' : ''}');
    changed();
    return null;
  }

  /// Booker / admin edit before approval.
  Future<String?> updatePending(SaleOrder o, List<OrderItem> items, {String notes = ''}) async {
    if (o.status != OrderStatus.pending) return 'Only pending orders can be edited';
    final lines = items.where((i) => i.qty > 0).toList();
    if (lines.isEmpty) return 'Add at least one item';
    o.items = lines;
    o.bookedItems = lines.map((e) => e.copy()).toList();
    o.notes = notes;
    final cc = shops.creditCheck(o.shopId, o.net);
    o.creditHold = cc.exceeds;
    await db.put(Col.orders, o.toMap());
    await log('edited', 'Order', refId: o.id, details: '#${o.no} ${_money(o.net)}');
    changed();
    return null;
  }

  // ---------------- Approval ----------------
  Future<String?> approve(SaleOrder o, {bool override = false}) async {
    if (o.status != OrderStatus.pending) return 'Order is not pending';
    final cc = shops.creditCheck(o.shopId, o.net);
    if (cc.exceeds && !override) return 'CREDIT_LIMIT';
    o.status = OrderStatus.approved;
    o.approvedBy = Session.userId;
    if (cc.exceeds) o.creditOverridden = true;
    o.creditHold = false;
    await db.put(Col.orders, o.toMap());
    await log('approved', 'Order', refId: o.id,
        details: '#${o.no} ${shops.shopName(o.shopId)}${o.creditOverridden ? ' (credit limit override)' : ''}');
    changed();
    return null;
  }

  Future<void> reject(SaleOrder o, String reason) async {
    o.status = OrderStatus.rejected;
    o.notes = reason.isEmpty ? o.notes : '${o.notes}\nRejected: $reason'.trim();
    await db.put(Col.orders, o.toMap());
    await log('rejected', 'Order', refId: o.id, details: '#${o.no} $reason');
    changed();
  }

  // ---------------- Load sheet & dispatch ----------------
  List<LoadSheet> get loadSheets {
    final l = db.all(Col.loadSheets).map(LoadSheet.fromMap).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  LoadSheet? loadSheet(String id) {
    final m = db.get(Col.loadSheets, id);
    return m == null ? null : LoadSheet.fromMap(m);
  }

  /// Aggregated pieces (qty + free) per product for a set of orders.
  Map<String, int> aggregate(List<SaleOrder> list) {
    final m = <String, int>{};
    for (final o in list) {
      for (final i in o.items) {
        m[i.productId] = (m[i.productId] ?? 0) + i.qty + i.freeQty;
      }
    }
    return m;
  }

  Future<String?> createLoadSheet(String salesmanId, List<SaleOrder> list, {String routeId = ''}) async {
    if (salesmanId.isEmpty) return 'Select a salesman';
    if (list.isEmpty) return 'Select at least one approved order';
    final items = aggregate(list);
    final short = <String>[];
    items.forEach((pid, q) {
      final have = inv.warehouseQty(pid);
      if (have < q) short.add('${inv.productName(pid)} (need $q, have $have)');
    });
    if (short.isNotEmpty) return 'Short stock in warehouse:\n${short.join('\n')}';

    final ls = LoadSheet(
      id: newId(),
      no: db.nextNo(Col.loadSheets),
      routeId: routeId,
      salesmanId: salesmanId,
      orderIds: list.map((o) => o.id).toList(),
      items: items,
      createdBy: Session.userId,
    );
    await db.put(Col.loadSheets, ls.toMap());
    await inv.loadOut(salesmanId, items, ls.id);
    for (final o in list) {
      o.status = OrderStatus.loaded;
      o.salesmanId = salesmanId;
      o.loadSheetId = ls.id;
      await db.put(Col.orders, o.toMap());
    }
    await log('created', 'Load Sheet', refId: ls.id, details: '#${ls.no} – ${list.length} orders');
    changed();
    return null;
  }

  /// Returns remaining van stock to warehouse and closes the sheet.
  Future<String?> closeLoadSheet(LoadSheet ls) async {
    if (ls.status == 'closed') return 'Already closed';
    final pendingDeliveries = ls.orderIds.map(byId).whereType<SaleOrder>().where((o) => o.status == OrderStatus.loaded);
    if (pendingDeliveries.isNotEmpty) {
      return '${pendingDeliveries.length} orders still not invoiced / cancelled';
    }
    await inv.loadIn(ls.salesmanId, ls.id);
    ls.status = 'closed';
    ls.closedAt = DateTime.now();
    await db.put(Col.loadSheets, ls.toMap());
    await log('closed', 'Load Sheet', refId: ls.id, details: '#${ls.no}');
    changed();
    return null;
  }

  // ---------------- Delivery: salesman edit, invoice ----------------
  /// Salesman changes quantities / removes items at the shop. Every change is logged.
  Future<String?> deliveryEdit(SaleOrder o, List<OrderItem> newItems, String reason) async {
    if (o.status != OrderStatus.loaded) return 'Only loaded orders can be edited';
    final before = {for (final i in o.items) i.productId: i};
    final after = {for (final i in newItems.where((x) => x.qty > 0)) i.productId: i};
    final changes = <String>[];
    for (final pid in {...before.keys, ...after.keys}) {
      final b = before[pid]?.qty ?? 0;
      final a = after[pid]?.qty ?? 0;
      if (a == b) continue;
      final name = inv.productName(pid);
      if (a == 0) {
        changes.add('Removed $name ($b pcs)');
      } else if (b == 0) {
        changes.add('Added $name ($a pcs)');
      } else {
        changes.add('$name $b → $a pcs');
      }
      // stock check on van for increases
      final vanHave = inv.qty(pid, 'van:${o.salesmanId}');
      final newTotal = a + (after[pid]?.freeQty ?? 0);
      final extra = newTotal - (b + (before[pid]?.freeQty ?? 0));
      if (extra > 0 && vanHave - _reservedOnVan(o, pid) < newTotal) {
        return 'Not enough $name on van';
      }
    }
    if (changes.isEmpty) return 'No changes made';
    o.items = after.values.toList();
    o.editLog.add(EditLog(userId: Session.userId, text: '${changes.join(', ')}${reason.isEmpty ? '' : ' – $reason'}'));
    await db.put(Col.orders, o.toMap());
    await log('edited', 'Order (delivery)', refId: o.id, details: '#${o.no}: ${changes.join(', ')} $reason');
    changed();
    return null;
  }

  /// Pieces of [pid] reserved by other loaded (not invoiced) orders of the same salesman.
  int _reservedOnVan(SaleOrder except, String pid) {
    var r = 0;
    for (final o in deliveriesFor(except.salesmanId)) {
      if (o.id == except.id) continue;
      for (final i in o.items) {
        if (i.productId == pid) r += i.qty + i.freeQty;
      }
    }
    return r;
  }

  Future<String?> invoice(SaleOrder o, {double extraDiscount = 0}) async {
    if (o.status != OrderStatus.loaded) return 'Order must be loaded on van first';
    if (o.items.isEmpty) return 'Order has no items – cancel it instead';
    o.extraDiscount = extraDiscount;
    o.invoiceNo = o.no; // bill no. = order no.
    o.invoicedAt = DateTime.now();
    o.status = OrderStatus.delivered;

    var cost = 0.0;
    for (final i in o.items) {
      final p = inv.product(i.productId);
      final pcs = i.qty + i.freeQty;
      cost += pcs * (p?.costPrice ?? 0);
      await inv.consume(i.productId, 'van:${o.salesmanId}', pcs, 'sale', o.id);
    }
    await db.put(Col.orders, o.toMap());
    await accounts.postSale(
      refId: o.id,
      shopId: o.shopId,
      net: o.net,
      cost: cost,
      narration: 'Invoice #${o.invoiceNo} – ${shops.shopName(o.shopId)}',
    );
    await tracking.checkIn(PingKind.visit, o.id, 'Delivered #${o.invoiceNo}');
    await log('invoiced', 'Order', refId: o.id, details: '#${o.invoiceNo} ${shops.shopName(o.shopId)} ${_money(o.net)}');
    changed();
    return null;
  }

  Future<void> cancelDelivery(SaleOrder o, String reason) async {
    o.status = OrderStatus.cancelled;
    o.editLog.add(EditLog(userId: Session.userId, text: 'Cancelled at delivery – $reason'));
    await db.put(Col.orders, o.toMap());
    await log('cancelled', 'Order', refId: o.id, details: '#${o.no} $reason');
    changed();
  }
}
