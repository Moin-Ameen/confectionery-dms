import '../models/base_model.dart';
import '../models/order.dart';
import '../models/shop.dart';
import '../services/local_db.dart';
import 'accounts_controller.dart';
import 'base_controller.dart';

class CreditCheck {
  final double outstanding;
  final double limit;
  final double orderAmount;
  CreditCheck(this.outstanding, this.limit, this.orderAmount);

  bool get hasLimit => limit > 0;
  double get afterOrder => outstanding + orderAmount;
  bool get exceeds => hasLimit && afterOrder > limit;
  bool get nearLimit => hasLimit && !exceeds && afterOrder > limit * 0.85;
  double get available => hasLimit ? (limit - outstanding).clamp(0, double.infinity).toDouble() : double.infinity;
}

class PendingBill {
  final SaleOrder order;
  final double recovered;
  PendingBill(this.order, this.recovered);
  double get pending => order.net - recovered;
  int get ageDays => DateTime.now().difference(order.invoicedAt ?? order.date).inDays;
}

class ShopController extends BaseController {
  final AccountsController accounts;
  ShopController(this.accounts);

  // ---------------- Routes ----------------
  List<RouteModel> get routes {
    final l = db.all(Col.routes).map(RouteModel.fromMap).toList();
    l.sort((a, b) => a.name.compareTo(b.name));
    return l;
  }

  RouteModel? route(String id) {
    final m = db.get(Col.routes, id);
    return m == null ? null : RouteModel.fromMap(m);
  }

  String routeName(String id) => route(id)?.name ?? '-';

  Future<String?> saveRoute(RouteModel r, {bool isNew = false}) async {
    if (r.name.trim().isEmpty) return 'Route name is required';
    await db.put(Col.routes, r.toMap());
    await log(isNew ? 'created' : 'edited', 'Route', refId: r.id, details: r.name);
    changed();
    return null;
  }

  // ---------------- Shops ----------------
  List<Shop> get shops {
    final l = db.all(Col.shops).map(Shop.fromMap).toList();
    l.sort((a, b) => a.name.compareTo(b.name));
    return l;
  }

  List<Shop> get activeShops => shops.where((s) => s.active).toList();

  List<Shop> shopsOnRoute(String routeId) => activeShops.where((s) => s.routeId == routeId).toList();

  Shop? shop(String id) {
    final m = db.get(Col.shops, id);
    return m == null ? null : Shop.fromMap(m);
  }

  String shopName(String id) => shop(id)?.name ?? '-';

  Future<String?> saveShop(Shop s, {bool isNew = false}) async {
    if (s.name.trim().isEmpty) return 'Shop name is required';
    if (s.khataNo.trim().isNotEmpty &&
        shops.any((x) => x.id != s.id && x.khataNo.trim().toLowerCase() == s.khataNo.trim().toLowerCase())) {
      return 'Khata no. already used by another shop';
    }
    final old = isNew ? null : shop(s.id);
    await db.put(Col.shops, s.toMap());
    var details = s.name;
    if (old != null && old.creditLimit != s.creditLimit) {
      details += ' – credit limit ${old.creditLimit.toStringAsFixed(0)} → ${s.creditLimit.toStringAsFixed(0)}';
    }
    await log(isNew ? 'created' : 'edited', 'Shop', refId: s.id, details: details);
    changed();
    return null;
  }

  // ---------------- Credit ----------------
  double outstanding(String shopId) => accounts.shopBalance(shopId);

  CreditCheck creditCheck(String shopId, double orderAmount) {
    final s = shop(shopId);
    return CreditCheck(outstanding(shopId), s?.creditLimit ?? 0, orderAmount);
  }

  /// Delivered bills of a shop that are not fully recovered (bill-wise).
  List<PendingBill> pendingBills(String shopId) {
    final recovered = <String, double>{};
    for (final r in db.all(Col.recoveries)) {
      final oid = toS(r['orderId']);
      if (oid.isEmpty) continue;
      recovered[oid] = (recovered[oid] ?? 0) + toD(r['amount']);
    }
    final out = <PendingBill>[];
    for (final m in db.all(Col.orders)) {
      if (toS(m['shopId']) != shopId || toS(m['status']) != OrderStatus.delivered) continue;
      final o = SaleOrder.fromMap(m);
      final pb = PendingBill(o, recovered[o.id] ?? 0);
      if (pb.pending > 0.5) out.add(pb);
    }
    out.sort((a, b) => a.order.invoiceNo.compareTo(b.order.invoiceNo));
    return out;
  }

  // ---------------- Schemes ----------------
  List<Scheme> get schemes => db.all(Col.schemes).map(Scheme.fromMap).toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<String?> saveScheme(Scheme s, {bool isNew = false}) async {
    if (s.name.trim().isEmpty) return 'Scheme name is required';
    if (s.type != SchemeType.discount && s.minQty <= 0) return 'Minimum quantity is required';
    await db.put(Col.schemes, s.toMap());
    await log(isNew ? 'created' : 'edited', 'Scheme', refId: s.id, details: '${s.name}: ${s.description}');
    changed();
    return null;
  }

  /// Returns (freeQty, discountPct) for a product & quantity.
  (int, double) applySchemes(String productId, int qty) {
    var free = 0;
    var pct = 0.0;
    var slab = 0.0;
    for (final s in schemes.where((s) => s.active && (s.productId.isEmpty || s.productId == productId))) {
      switch (s.type) {
        case SchemeType.free:
          if (s.minQty > 0 && qty >= s.minQty) free += (qty ~/ s.minQty) * s.freeQty;
          break;
        case SchemeType.slab:
          if (qty >= s.minQty && s.percent > slab) slab = s.percent;
          break;
        case SchemeType.discount:
          pct += s.percent;
          break;
      }
    }
    return (free, pct + slab);
  }
}
