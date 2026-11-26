import '../config/app_config.dart';
import '../models/base_model.dart';
import '../models/recovery.dart';
import '../models/tracking.dart';
import '../services/local_db.dart';
import 'accounts_controller.dart';
import 'base_controller.dart';
import 'shop_controller.dart';
import 'tracking_controller.dart';

class SlipSummary {
  final RecoverySlip slip;
  final List<Recovery> lines;
  SlipSummary(this.slip, this.lines);

  int get bills => lines.length;
  double get totalBill => lines.fold(0, (s, r) => s + r.billAmount);
  double get totalRecovered => lines.fold(0, (s, r) => s + r.amount);
  double get pending => lines.fold(0, (s, r) => s + r.pending);
  double get cash => slip.status == SlipStatus.approved ? slip.cashReceived : slip.cashHanded;

  /// + short, - excess
  double get shortExcess => totalRecovered - cash;
}

class AgingRow {
  final String shopId;
  final double balance;
  final double d0to7;
  final double d8to15;
  final double d16to30;
  final double d30plus;
  final int bills;
  AgingRow(this.shopId, this.balance, this.d0to7, this.d8to15, this.d16to30, this.d30plus, this.bills);
}

class RecoveryController extends BaseController {
  final AccountsController accounts;
  final ShopController shops;
  final TrackingController tracking;
  RecoveryController(this.accounts, this.shops, this.tracking);

  List<Recovery> get recoveries => db.all(Col.recoveries).map(Recovery.fromMap).toList();

  List<RecoverySlip> get slips {
    final l = db.all(Col.slips).map(RecoverySlip.fromMap).toList();
    l.sort((a, b) => b.day.compareTo(a.day));
    return l;
  }

  RecoverySlip? slip(String id) {
    final m = db.get(Col.slips, id);
    return m == null ? null : RecoverySlip.fromMap(m);
  }

  RecoverySlip? slipFor(String salesmanId, DateTime day) {
    final k = dayKey(day);
    for (final s in slips) {
      if (s.salesmanId == salesmanId && s.day == k) return s;
    }
    return null;
  }

  /// Today's slip for the salesman (created on first use).
  Future<RecoverySlip> todaySlip(String salesmanId) async {
    final existing = slipFor(salesmanId, DateTime.now());
    if (existing != null) return existing;
    final s = RecoverySlip(id: newId(), salesmanId: salesmanId, day: dayKey(DateTime.now()));
    await db.put(Col.slips, s.toMap());
    return s;
  }

  List<Recovery> linesOf(String slipId) {
    final l = recoveries.where((r) => r.slipId == slipId).toList();
    l.sort((a, b) => a.date.compareTo(b.date));
    return l;
  }

  SlipSummary summary(RecoverySlip s) => SlipSummary(s, linesOf(s.id));

  Future<String?> add({
    required String shopId,
    required String orderId,
    required int billNo,
    required double billAmount,
    required double amount,
  }) async {
    if (amount < 0) return 'Amount cannot be negative';
    if (amount > billAmount + 0.5) return 'Amount is more than bill pending';
    final slip = await todaySlip(Session.userId);
    if (slip.status != SlipStatus.open) return 'Today\'s slip is already submitted';
    if (linesOf(slip.id).any((r) => r.orderId == orderId && orderId.isNotEmpty)) {
      return 'Bill #$billNo is already on today\'s slip';
    }
    final shop = shops.shop(shopId);
    final r = Recovery(
      id: newId(),
      salesmanId: Session.userId,
      shopId: shopId,
      orderId: orderId,
      billNo: billNo,
      khataNo: shop?.khataNo ?? '',
      billAmount: billAmount,
      amount: amount,
      slipId: slip.id,
    );
    final loc = await tracking.checkIn(PingKind.recoveryCheckIn, r.id, 'Recovery bill #$billNo – ${shop?.name ?? ''}');
    if (loc != null) {
      r.lat = loc.$1;
      r.lng = loc.$2;
    }
    await db.put(Col.recoveries, r.toMap());
    await log('created', 'Recovery', refId: r.id,
        details: 'Bill #$billNo ${shop?.name ?? ''} ${AppConfig.currency} ${amount.toStringAsFixed(0)} (${r.status})');
    changed();
    return null;
  }

  Future<String?> remove(Recovery r) async {
    final s = slip(r.slipId);
    if (s != null && s.status != SlipStatus.open) return 'Slip already submitted';
    await db.delete(Col.recoveries, r.id);
    await log('deleted', 'Recovery', refId: r.id, details: 'Bill #${r.billNo}');
    changed();
    return null;
  }

  Future<String?> submit(RecoverySlip s, double cashHanded) async {
    if (s.status != SlipStatus.open) return 'Slip already submitted';
    if (linesOf(s.id).isEmpty) return 'No recovery on this slip';
    s.cashHanded = cashHanded;
    s.status = SlipStatus.submitted;
    s.submittedAt = DateTime.now();
    await db.put(Col.slips, s.toMap());
    await log('submitted', 'Recovery Slip', refId: s.id, details: '${s.day} cash ${cashHanded.toStringAsFixed(0)}');
    changed();
    return null;
  }

  /// Reopen a submitted slip for corrections (admin / cashier).
  Future<String?> reopen(RecoverySlip s) async {
    if (s.status != SlipStatus.submitted) return 'Only submitted slips can be reopened';
    s.status = SlipStatus.open;
    await db.put(Col.slips, s.toMap());
    await log('reopened', 'Recovery Slip', refId: s.id, details: s.day);
    changed();
    return null;
  }

  /// Cashier / admin counts cash & approves. Khata updates only now.
  Future<String?> approve(RecoverySlip s, double cashReceived, {String note = ''}) async {
    if (s.status != SlipStatus.submitted) return 'Slip must be submitted by salesman first';
    final sum = summary(s);
    final perShop = <String, double>{};
    for (final r in sum.lines) {
      if (r.amount <= 0) continue;
      perShop[r.shopId] = (perShop[r.shopId] ?? 0) + r.amount;
    }
    s.cashReceived = cashReceived;
    s.status = SlipStatus.approved;
    s.approvedBy = Session.userId;
    s.approvedAt = DateTime.now();
    s.note = note;
    await accounts.postRecovery(
      refId: s.id,
      salesmanId: s.salesmanId,
      shopAmounts: perShop,
      cashReceived: cashReceived,
      narration: 'Recovery slip ${s.day}',
    );
    await db.put(Col.slips, s.toMap());
    final diff = sum.totalRecovered - cashReceived;
    await log('approved', 'Recovery Slip', refId: s.id,
        details: '${s.day} recovered ${sum.totalRecovered.toStringAsFixed(0)}, cash ${cashReceived.toStringAsFixed(0)}'
            '${diff.abs() > 0.5 ? (diff > 0 ? ', short ${diff.toStringAsFixed(0)}' : ', excess ${(-diff).toStringAsFixed(0)}') : ''}');
    changed();
    return null;
  }

  double recoveredOn(DateTime day, {String? salesmanId}) {
    final k = dayKey(day);
    return recoveries
        .where((r) => dayKey(r.date) == k && (salesmanId == null || r.salesmanId == salesmanId))
        .fold(0.0, (s, r) => s + r.amount);
  }

  // ---------------- Outstanding & aging ----------------
  List<AgingRow> aging() {
    final balances = accounts.allShopBalances();
    final rows = <AgingRow>[];
    for (final shop in shops.shops) {
      final bal = balances[shop.id] ?? 0;
      final bills = shops.pendingBills(shop.id);
      if (bal.abs() < 0.5 && bills.isEmpty) continue;
      double a = 0, b = 0, c = 0, d = 0;
      for (final pb in bills) {
        final age = pb.ageDays;
        if (age <= 7) {
          a += pb.pending;
        } else if (age <= 15) {
          b += pb.pending;
        } else if (age <= 30) {
          c += pb.pending;
        } else {
          d += pb.pending;
        }
      }
      rows.add(AgingRow(shop.id, bal, a, b, c, d, bills.length));
    }
    rows.sort((x, y) => y.balance.compareTo(x.balance));
    return rows;
  }
}
