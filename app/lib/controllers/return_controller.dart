import '../config/app_config.dart';
import '../models/base_model.dart';
import '../models/product.dart';
import '../models/sale_return.dart';
import '../models/user.dart';
import '../services/local_db.dart';
import 'accounts_controller.dart';
import 'base_controller.dart';
import 'inventory_controller.dart';
import 'shop_controller.dart';

class ReturnController extends BaseController {
  final InventoryController inv;
  final AccountsController accounts;
  final ShopController shops;
  ReturnController(this.inv, this.accounts, this.shops);

  List<SaleReturn> get returns {
    final l = db.all(Col.returns).map(SaleReturn.fromMap).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  List<SaleReturn> get visibleReturns {
    final u = Session.user;
    if (u != null && u.role.isField) return returns.where((r) => r.userId == u.id).toList();
    return returns;
  }

  List<SaleReturn> get pending => returns.where((r) => r.status == 'pending').toList();

  Future<String?> create(String shopId, List<ReturnItem> items, String note) async {
    if (shopId.isEmpty) return 'Select a shop';
    final lines = items.where((i) => i.qty > 0).toList();
    if (lines.isEmpty) return 'Add at least one item';
    final r = SaleReturn(
      id: newId(),
      no: db.nextNo(Col.returns),
      shopId: shopId,
      userId: Session.userId,
      items: lines,
      note: note,
    );
    await db.put(Col.returns, r.toMap());
    await log('created', 'Sale Return', refId: r.id,
        details: '#${r.no} ${shops.shopName(shopId)} ${AppConfig.currency} ${r.total.toStringAsFixed(0)}');
    changed();
    return null;
  }

  /// Approval moves stock (fresh → warehouse, damaged/expired → damaged store) and credits shop khata.
  Future<String?> approve(SaleReturn r) async {
    if (r.status != 'pending') return 'Already processed';
    var freshCost = 0.0;
    for (final i in r.items) {
      final p = inv.product(i.productId);
      if (i.condition == 'fresh') {
        await inv.receive(i.productId, StockLoc.warehouse, i.qty, 'saleReturn', r.id, note: 'Fresh return');
        freshCost += i.qty * (p?.costPrice ?? 0);
      } else {
        await inv.receive(i.productId, StockLoc.damaged, i.qty, 'saleReturn', r.id, note: i.condition);
      }
    }
    await accounts.postSaleReturn(
      refId: r.id,
      shopId: r.shopId,
      amount: r.total,
      freshCost: freshCost,
      narration: 'Sale return #${r.no} – ${shops.shopName(r.shopId)}',
    );
    r.status = 'approved';
    r.approvedBy = Session.userId;
    r.approvedAt = DateTime.now();
    await db.put(Col.returns, r.toMap());
    await log('approved', 'Sale Return', refId: r.id, details: '#${r.no}');
    changed();
    return null;
  }

  Future<void> reject(SaleReturn r, String reason) async {
    r.status = 'rejected';
    r.approvedBy = Session.userId;
    r.approvedAt = DateTime.now();
    r.note = '${r.note}\nRejected: $reason'.trim();
    await db.put(Col.returns, r.toMap());
    await log('rejected', 'Sale Return', refId: r.id, details: '#${r.no} $reason');
    changed();
  }

  double totalOn(DateTime day, {String? userId}) {
    final k = dayKey(day);
    return returns
        .where((r) => r.status != 'rejected' && dayKey(r.date) == k && (userId == null || r.userId == userId))
        .fold(0.0, (s, r) => s + r.total);
  }
}
