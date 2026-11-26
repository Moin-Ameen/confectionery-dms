import '../config/app_config.dart';
import '../models/base_model.dart';
import '../models/product.dart';
import '../services/local_db.dart';
import 'accounts_controller.dart';
import 'base_controller.dart';

class Batch {
  final String batchNo;
  final DateTime? expiry;
  int qty;
  Batch(this.batchNo, this.expiry, this.qty);

  int? get daysToExpiry => expiry?.difference(DateTime.now()).inDays;
}

class ExpiryAlert {
  final Product product;
  final String location;
  final Batch batch;
  ExpiryAlert(this.product, this.location, this.batch);
}

class InventoryController extends BaseController {
  final AccountsController accounts;
  InventoryController(this.accounts);

  Map<String, Map<String, int>>? _stock; // location -> productId -> pieces
  List<Product>? _products;

  @override
  void invalidate() {
    _stock = null;
    _products = null;
  }

  // ---------------- Companies ----------------
  List<Company> get companies {
    final l = db.all(Col.companies).map(Company.fromMap).toList();
    l.sort((a, b) => a.name.compareTo(b.name));
    return l;
  }

  String companyName(String id) {
    final m = db.get(Col.companies, id);
    return m == null ? '-' : toS(m['name']);
  }

  Future<String?> saveCompany(Company c, {bool isNew = false}) async {
    if (c.name.trim().isEmpty) return 'Company name is required';
    await db.put(Col.companies, c.toMap());
    await log(isNew ? 'created' : 'edited', 'Company', refId: c.id, details: c.name);
    changed();
    return null;
  }

  // ---------------- Products ----------------
  List<Product> get products {
    if (_products != null) return _products!;
    final l = db.all(Col.products).map(Product.fromMap).toList();
    l.sort((a, b) => a.name.compareTo(b.name));
    return _products = l;
  }

  List<Product> get activeProducts => products.where((p) => p.active).toList();

  Product? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  String productName(String id) => product(id)?.name ?? 'Deleted item';

  Future<String?> saveProduct(Product p, {bool isNew = false}) async {
    if (p.name.trim().isEmpty) return 'Product name is required';
    if (p.companyId.isEmpty) return 'Select a company';
    if (p.tp <= 0) return 'Trade price (TP) is required';
    await db.put(Col.products, p.toMap());
    await log(isNew ? 'created' : 'edited', 'Product', refId: p.id, details: p.name);
    changed();
    return null;
  }

  // ---------------- Stock engine ----------------
  List<StockMove> get moves => db.all(Col.stockMoves).map(StockMove.fromMap).toList();

  Map<String, Map<String, int>> get _s {
    if (_stock != null) return _stock!;
    final s = <String, Map<String, int>>{};
    for (final m in db.all(Col.stockMoves)) {
      final loc = toS(m['location']);
      final pid = toS(m['productId']);
      final q = toI(m['qty']);
      final mp = s.putIfAbsent(loc, () => {});
      mp[pid] = (mp[pid] ?? 0) + q;
    }
    return _stock = s;
  }

  int qty(String productId, String location) => _s[location]?[productId] ?? 0;
  int warehouseQty(String productId) => qty(productId, StockLoc.warehouse);
  Map<String, int> locationStock(String location) => Map.of(_s[location] ?? {});
  Map<String, int> vanStock(String salesmanId) =>
      locationStock(StockLoc.van(salesmanId))..removeWhere((k, v) => v == 0);
  List<String> get vanLocations => _s.keys.where(StockLoc.isVan).toList();

  int totalQty(String productId) {
    var t = 0;
    for (final e in _s.entries) {
      if (e.key == StockLoc.damaged) continue;
      t += e.value[productId] ?? 0;
    }
    return t;
  }

  List<Batch> batches(String productId, String location) {
    final map = <String, Batch>{};
    for (final m in db.all(Col.stockMoves)) {
      if (toS(m['productId']) != productId || toS(m['location']) != location) continue;
      final b = toS(m['batchNo']);
      final e = toDtN(m['expiry']);
      final key = '$b|${e?.toIso8601String() ?? ''}';
      map.putIfAbsent(key, () => Batch(b, e, 0)).qty += toI(m['qty']);
    }
    final list = map.values.where((b) => b.qty > 0).toList();
    list.sort((a, b) {
      if (a.expiry == null && b.expiry == null) return 0;
      if (a.expiry == null) return 1;
      if (b.expiry == null) return -1;
      return a.expiry!.compareTo(b.expiry!);
    });
    return list;
  }

  /// FIFO (earliest expiry first) allocation of [qty] from [location].
  List<Batch> _allocate(String productId, String location, int qty) {
    final out = <Batch>[];
    var left = qty;
    for (final b in batches(productId, location)) {
      if (left <= 0) break;
      final take = b.qty < left ? b.qty : left;
      out.add(Batch(b.batchNo, b.expiry, take));
      left -= take;
    }
    if (left > 0) out.add(Batch('', null, left)); // allow negative (un-batched)
    return out;
  }

  StockMove _mv(String productId, String loc, int qty, Batch b, String type, String refId, String note) => StockMove(
        id: newId(),
        productId: productId,
        location: loc,
        qty: qty,
        batchNo: b.batchNo,
        expiry: b.expiry,
        type: type,
        refId: refId,
        note: note,
        userId: Session.userId,
      );

  Future<void> _save(List<StockMove> list) async {
    if (list.isEmpty) return;
    await db.putMany(Col.stockMoves, list.map((m) => m.toMap()).toList());
    _stock = null;
  }

  /// Move stock between locations keeping batch info.
  Future<void> transfer(String productId, String from, String to, int qty, String type, String refId,
      {String note = ''}) async {
    if (qty <= 0) return;
    final list = <StockMove>[];
    for (final b in _allocate(productId, from, qty)) {
      list.add(_mv(productId, from, -b.qty, b, type, refId, note));
      list.add(_mv(productId, to, b.qty, b, type, refId, note));
    }
    await _save(list);
  }

  /// Take stock out of a location (sale, purchase return).
  Future<void> consume(String productId, String location, int qty, String type, String refId,
      {String note = ''}) async {
    if (qty <= 0) return;
    await _save(_allocate(productId, location, qty).map((b) => _mv(productId, location, -b.qty, b, type, refId, note)).toList());
  }

  /// Put stock into a location.
  Future<void> receive(String productId, String location, int qty, String type, String refId,
      {String batchNo = '', DateTime? expiry, String note = ''}) async {
    if (qty <= 0) return;
    await _save([_mv(productId, location, qty, Batch(batchNo, expiry, qty), type, refId, note)]);
  }

  // ---------------- Purchases ----------------
  List<Purchase> get purchases {
    final l = db.all(Col.purchases).map(Purchase.fromMap).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  Future<String?> savePurchase(Purchase p) async {
    if (p.companyId.isEmpty) return 'Select a company';
    p.items.removeWhere((i) => i.qty + i.bonus <= 0);
    if (p.items.isEmpty) return 'Add at least one item';
    p.no = db.nextNo(Col.purchases);
    p.userId = Session.userId;
    await db.put(Col.purchases, p.toMap());

    for (final i in p.items) {
      if (p.isReturn) {
        await consume(i.productId, StockLoc.warehouse, i.qty + i.bonus, 'purchaseReturn', p.id);
      } else {
        await receive(i.productId, StockLoc.warehouse, i.qty + i.bonus, 'purchase', p.id,
            batchNo: i.batchNo, expiry: i.expiry);
        // keep latest cost price (effective cost incl. bonus)
        final prod = product(i.productId);
        if (prod != null && i.rate > 0) {
          final total = i.qty + i.bonus;
          prod.costPrice = total > 0 ? (i.qty * i.rate) / total : i.rate;
          await db.put(Col.products, prod.toMap());
        }
      }
    }
    await accounts.postPurchase(
      refId: p.id,
      companyId: p.companyId,
      amount: p.net,
      isReturn: p.isReturn,
      date: p.date,
      narration: '${p.isReturn ? 'Purchase return' : 'Purchase'} #${p.no} - ${companyName(p.companyId)}',
    );
    await log('created', p.isReturn ? 'Purchase Return' : 'Purchase', refId: p.id,
        details: '#${p.no} ${companyName(p.companyId)} ${AppConfig.currency} ${p.net.toStringAsFixed(0)}');
    changed();
    return null;
  }

  // ---------------- Adjustments ----------------
  Future<String?> adjust(String productId, String location, int delta, String reason) async {
    if (delta == 0) return 'Quantity cannot be zero';
    final p = product(productId);
    if (p == null) return 'Product not found';
    final ref = newId();
    if (delta < 0) {
      await consume(productId, location, -delta, 'adjust', ref, note: reason);
    } else {
      await receive(productId, location, delta, 'adjust', ref, note: reason);
    }
    await accounts.postStockAdjust(
      refId: ref,
      value: delta * p.costPrice,
      narration: 'Stock adjustment ${p.name}: ${p.packLabel(delta)} ($reason)',
    );
    await log('adjusted', 'Stock', refId: productId, details: '${p.name} ${delta > 0 ? '+' : ''}$delta pcs – $reason');
    changed();
    return null;
  }

  Future<String?> stockCount(String productId, String location, int counted) async {
    final diff = counted - qty(productId, location);
    if (diff == 0) return 'Stock already matches';
    return adjust(productId, location, diff, 'Stock count');
  }

  // ---------------- Van load-out / load-in ----------------
  Future<void> loadOut(String salesmanId, Map<String, int> items, String refId) async {
    for (final e in items.entries) {
      await transfer(e.key, StockLoc.warehouse, StockLoc.van(salesmanId), e.value, 'loadOut', refId);
    }
  }

  Future<void> loadIn(String salesmanId, String refId) async {
    final van = vanStock(salesmanId);
    for (final e in van.entries) {
      if (e.value > 0) {
        await transfer(e.key, StockLoc.van(salesmanId), StockLoc.warehouse, e.value, 'loadIn', refId);
      }
    }
    await log('load-in', 'Van Stock', refId: refId, details: '${van.length} items returned to warehouse');
  }

  // ---------------- Alerts & valuation ----------------
  List<Product> get lowStock =>
      activeProducts.where((p) => p.lowStockPieces > 0 && warehouseQty(p.id) <= p.lowStockPieces).toList();

  List<ExpiryAlert> get nearExpiry {
    final out = <ExpiryAlert>[];
    final locs = [StockLoc.warehouse, ...vanLocations];
    for (final p in activeProducts) {
      for (final loc in locs) {
        for (final b in batches(p.id, loc)) {
          final d = b.daysToExpiry;
          if (d != null && d <= AppConfig.nearExpiryDays) out.add(ExpiryAlert(p, loc, b));
        }
      }
    }
    out.sort((a, b) => a.batch.expiry!.compareTo(b.batch.expiry!));
    return out;
  }

  double get stockValue {
    var v = 0.0;
    for (final p in products) {
      v += totalQty(p.id) * p.costPrice;
    }
    return v;
  }
}
