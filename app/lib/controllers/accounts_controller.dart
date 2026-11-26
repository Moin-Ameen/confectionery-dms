import '../models/accounts.dart';
import '../models/base_model.dart';
import '../services/local_db.dart';
import 'base_controller.dart';

class LedgerRow {
  final DateTime date;
  final String voucherType;
  final int voucherNo;
  final String narration;
  final double debit;
  final double credit;
  final double balance;
  LedgerRow(this.date, this.voucherType, this.voucherNo, this.narration, this.debit, this.credit, this.balance);
}

class TrialRow {
  final Account account;
  final double debit;
  final double credit;
  TrialRow(this.account, this.debit, this.credit);
}

class PnL {
  final double sales;
  final double salesReturns;
  final double cogs;
  final double otherIncome;
  final Map<String, double> expenses; // account name -> amount
  PnL(this.sales, this.salesReturns, this.cogs, this.otherIncome, this.expenses);

  double get netSales => sales - salesReturns;
  double get grossProfit => netSales - cogs;
  double get totalExpenses => expenses.values.fold(0, (s, v) => s + v);
  double get netProfit => grossProfit + otherIncome - totalExpenses;
}

class AccountsController extends BaseController {
  static const _chart = [
    ['1000', 'Cash in Hand', 'asset', SysAcc.cash],
    ['1010', 'Bank Account', 'asset', SysAcc.bank],
    ['1100', 'Shop Receivables (Khata)', 'asset', SysAcc.receivable],
    ['1150', 'Salesman Receivable (Short)', 'asset', SysAcc.salesmanRecv],
    ['1200', 'Stock / Inventory', 'asset', SysAcc.inventory],
    ['2000', 'Company / Supplier Payable', 'liability', SysAcc.payable],
    ['3000', 'Owner Capital', 'equity', SysAcc.capital],
    ['4000', 'Sales', 'income', SysAcc.sales],
    ['4100', 'Other Income / Cash Excess', 'income', SysAcc.otherIncome],
    ['5000', 'Cost of Goods Sold', 'expense', SysAcc.cogs],
    ['5050', 'Sales Returns', 'expense', SysAcc.salesReturn],
    ['5100', 'Stock Damage / Short', 'expense', SysAcc.stockLoss],
    ['5200', 'Commission', 'expense', SysAcc.commission],
    ['5300', 'Fuel', 'expense', SysAcc.fuel],
    ['5310', 'Vehicle Maintenance', 'expense', SysAcc.vehicle],
    ['5320', 'Rent', 'expense', SysAcc.rent],
    ['5330', 'Salaries', 'expense', SysAcc.salaries],
    ['5390', 'Other Expenses', 'expense', SysAcc.otherExp],
  ];

  Future<void> ensureChart() async {
    final existing = accounts.map((a) => a.sysKey).toSet();
    final toAdd = <Map<String, dynamic>>[];
    for (final c in _chart) {
      if (existing.contains(c[3])) continue;
      toAdd.add(Account(
        id: newId(),
        code: c[0],
        name: c[1],
        type: AccountType.values.byName(c[2]),
        sysKey: c[3],
        isCash: c[3] == SysAcc.cash,
        isBank: c[3] == SysAcc.bank,
      ).toMap());
    }
    if (toAdd.isNotEmpty) await db.putMany(Col.accounts, toAdd);
    _aCache = null;
  }

  // ---------------- Accounts ----------------
  List<Account> get accounts {
    if (_aCache != null) return _aCache!;
    final l = db.all(Col.accounts).map(Account.fromMap).toList();
    l.sort((a, b) => a.code.compareTo(b.code));
    return _aCache = l;
  }

  Account? byId(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Account sys(String key) => accounts.firstWhere((a) => a.sysKey == key);

  List<Account> get cashBankAccounts => accounts.where((a) => a.isCash || a.isBank).toList();
  List<Account> get expenseAccounts =>
      accounts.where((a) => a.type == AccountType.expense && a.sysKey != SysAcc.cogs && a.sysKey != SysAcc.salesReturn).toList();

  Future<String?> saveAccount(Account a, {bool isNew = false}) async {
    if (a.name.trim().isEmpty || a.code.trim().isEmpty) return 'Code and name are required';
    if (accounts.any((x) => x.id != a.id && x.code == a.code)) return 'Account code already exists';
    await db.put(Col.accounts, a.toMap());
    await log(isNew ? 'created' : 'edited', 'Account', refId: a.id, details: '${a.code} ${a.name}');
    changed();
    return null;
  }

  // ---------------- Vouchers ----------------
  List<Voucher>? _vCache;
  List<Account>? _aCache;

  @override
  void invalidate() {
    _vCache = null;
    _aCache = null;
  }

  List<Voucher> get vouchers {
    if (_vCache != null) return _vCache!;
    final l = db.all(Col.vouchers).map(Voucher.fromMap).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return _vCache = l;
  }

  Future<Voucher> post({
    required String type,
    required List<VoucherLine> lines,
    String narration = '',
    String refId = '',
    DateTime? date,
    bool auto = true,
  }) async {
    final v = Voucher(
      id: newId(),
      no: db.nextNo(Col.vouchers),
      type: type,
      date: date ?? DateTime.now(),
      narration: narration,
      lines: lines.where((l) => l.debit.abs() > 0.0001 || l.credit.abs() > 0.0001).toList(),
      refId: refId,
      userId: Session.userId,
      auto: auto,
    );
    await db.put(Col.vouchers, v.toMap());
    _vCache = null;
    return v;
  }

  Future<String?> saveManualVoucher(Voucher v) async {
    if (v.lines.length < 2) return 'At least two lines are required';
    if (!v.balanced) return 'Debit and credit must be equal';
    if (v.totalDebit <= 0) return 'Amount must be greater than zero';
    if (v.no == 0) v.no = db.nextNo(Col.vouchers);
    await db.put(Col.vouchers, v.toMap());
    await log('created', 'Voucher', refId: v.id, details: '${v.type} #${v.no}');
    changed();
    return null;
  }

  Future<String?> deleteVoucher(Voucher v) async {
    if (v.auto) return 'Automatic vouchers cannot be deleted';
    await db.delete(Col.vouchers, v.id);
    await log('deleted', 'Voucher', refId: v.id, details: '${v.type} #${v.no}');
    changed();
    return null;
  }

  Future<void> expense({
    required String expenseAccountId,
    required String payFromAccountId,
    required double amount,
    String narration = '',
    String partyType = '',
    String partyId = '',
    DateTime? date,
  }) async {
    final v = await post(
      type: VoucherType.expense,
      narration: narration,
      date: date,
      auto: false,
      lines: [
        VoucherLine(accountId: expenseAccountId, debit: amount, partyType: partyType, partyId: partyId),
        VoucherLine(accountId: payFromAccountId, credit: amount),
      ],
    );
    await log('created', 'Expense', refId: v.id, details: '$narration ${amount.toStringAsFixed(0)}');
    changed();
  }

  // ---------------- Balances ----------------
  Iterable<MapEntry<Voucher, VoucherLine>> _lines({DateTime? from, DateTime? to}) sync* {
    for (final v in vouchers) {
      if (from != null && v.date.isBefore(from)) continue;
      if (to != null && !v.date.isBefore(to)) continue;
      for (final l in v.lines) {
        yield MapEntry(v, l);
      }
    }
  }

  /// Natural-sign balance (debit-normal accounts positive when Dr > Cr).
  double balance(String accountId, {DateTime? from, DateTime? to}) {
    final acc = byId(accountId);
    var dr = 0.0, cr = 0.0;
    for (final e in _lines(from: from, to: to)) {
      if (e.value.accountId != accountId) continue;
      dr += e.value.debit;
      cr += e.value.credit;
    }
    return (acc?.type.debitNormal ?? true) ? dr - cr : cr - dr;
  }

  double sysBalance(String key, {DateTime? from, DateTime? to}) => balance(sys(key).id, from: from, to: to);

  /// Party balance on a given control account (shop khata = receivable, Dr positive).
  double partyBalance(String partyType, String partyId, {String? accountId}) {
    var dr = 0.0, cr = 0.0;
    for (final e in _lines()) {
      final l = e.value;
      if (l.partyType != partyType || l.partyId != partyId) continue;
      if (accountId != null && l.accountId != accountId) continue;
      dr += l.debit;
      cr += l.credit;
    }
    // shops & salesmen: what they owe us (Dr). companies: what we owe them (Cr).
    return partyType == PartyType.company ? cr - dr : dr - cr;
  }

  double shopBalance(String shopId) => partyBalance(PartyType.shop, shopId, accountId: sys(SysAcc.receivable).id);

  Map<String, double> allShopBalances() {
    final recv = sys(SysAcc.receivable).id;
    final out = <String, double>{};
    for (final e in _lines()) {
      final l = e.value;
      if (l.accountId != recv || l.partyType != PartyType.shop) continue;
      out[l.partyId] = (out[l.partyId] ?? 0) + l.debit - l.credit;
    }
    return out;
  }

  List<LedgerRow> ledger({String? accountId, String? partyType, String? partyId, DateTime? from, DateTime? to}) {
    final acc = accountId == null ? null : byId(accountId);
    final debitNormal = partyType != null ? partyType != PartyType.company : (acc?.type.debitNormal ?? true);
    bool match(VoucherLine l) {
      if (accountId != null && l.accountId != accountId) return false;
      if (partyType != null && (l.partyType != partyType || l.partyId != partyId)) return false;
      return true;
    }

    final all = vouchers.reversed.toList(); // oldest first
    var bal = 0.0;
    final rows = <LedgerRow>[];
    // opening balance
    if (from != null) {
      for (final v in all.where((v) => v.date.isBefore(from))) {
        for (final l in v.lines.where(match)) {
          bal += debitNormal ? l.debit - l.credit : l.credit - l.debit;
        }
      }
      rows.add(LedgerRow(from, 'Opening', 0, 'Opening balance', 0, 0, bal));
    }
    for (final v in all) {
      if (from != null && v.date.isBefore(from)) continue;
      if (to != null && !v.date.isBefore(to)) continue;
      for (final l in v.lines.where(match)) {
        bal += debitNormal ? l.debit - l.credit : l.credit - l.debit;
        rows.add(LedgerRow(v.date, v.type, v.no, l.memo.isNotEmpty ? l.memo : v.narration, l.debit, l.credit, bal));
      }
    }
    return rows;
  }

  // ---------------- Financial reports ----------------
  List<TrialRow> trialBalance({DateTime? to}) {
    final sums = <String, List<double>>{};
    for (final e in _lines(to: to)) {
      final s = sums.putIfAbsent(e.value.accountId, () => [0, 0]);
      s[0] += e.value.debit;
      s[1] += e.value.credit;
    }
    final rows = <TrialRow>[];
    for (final a in accounts) {
      final s = sums[a.id];
      if (s == null) continue;
      final net = s[0] - s[1];
      if (net.abs() < 0.01) continue;
      rows.add(TrialRow(a, net > 0 ? net : 0, net < 0 ? -net : 0));
    }
    return rows;
  }

  PnL profitLoss({DateTime? from, DateTime? to}) {
    double b(String k) => sysBalance(k, from: from, to: to);
    final exp = <String, double>{};
    for (final a in expenseAccounts) {
      final v = balance(a.id, from: from, to: to);
      if (v.abs() > 0.01) exp[a.name] = v;
    }
    // user created income accounts count as other income
    var other = b(SysAcc.otherIncome);
    for (final a in accounts.where((a) => a.type == AccountType.income && a.sysKey.isEmpty)) {
      other += balance(a.id, from: from, to: to);
    }
    return PnL(b(SysAcc.sales), b(SysAcc.salesReturn), b(SysAcc.cogs), other, exp);
  }

  /// Returns {section: {account: amount}} for assets, liabilities, equity.
  Map<String, Map<String, double>> balanceSheet({DateTime? asOf}) {
    final res = <String, Map<String, double>>{'Assets': {}, 'Liabilities': {}, 'Equity': {}};
    for (final a in accounts) {
      if (a.type == AccountType.income || a.type == AccountType.expense) continue;
      final v = balance(a.id, to: asOf);
      if (v.abs() < 0.01) continue;
      final key = a.type == AccountType.asset
          ? 'Assets'
          : a.type == AccountType.liability
              ? 'Liabilities'
              : 'Equity';
      res[key]![a.name] = v;
    }
    final profit = profitLoss(to: asOf).netProfit;
    if (profit.abs() > 0.01) res['Equity']!['Retained Profit'] = profit;
    return res;
  }

  /// Net profit per month for the last [months] months (oldest first).
  List<MapEntry<String, double>> monthlyProfit({int months = 6}) {
    final now = DateTime.now();
    final out = <MapEntry<String, double>>[];
    for (var i = months - 1; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, 1);
      final end = DateTime(start.year, start.month + 1, 1);
      out.add(MapEntry(monthKey(start), profitLoss(from: start, to: end).netProfit));
    }
    return out;
  }

  // ---------------- Automatic postings ----------------
  String _id(String key) => sys(key).id;

  Future<void> postPurchase({
    required String refId,
    required String companyId,
    required double amount,
    required bool isReturn,
    required String narration,
    DateTime? date,
  }) async {
    final inv = VoucherLine(accountId: _id(SysAcc.inventory), debit: isReturn ? 0 : amount, credit: isReturn ? amount : 0);
    final pay = VoucherLine(
      accountId: _id(SysAcc.payable),
      debit: isReturn ? amount : 0,
      credit: isReturn ? 0 : amount,
      partyType: PartyType.company,
      partyId: companyId,
    );
    await post(
      type: isReturn ? VoucherType.purchaseReturn : VoucherType.purchase,
      refId: refId,
      narration: narration,
      date: date,
      lines: [inv, pay],
    );
  }

  Future<void> postSale({
    required String refId,
    required String shopId,
    required double net,
    required double cost,
    required String narration,
  }) async {
    await post(type: VoucherType.sale, refId: refId, narration: narration, lines: [
      VoucherLine(accountId: _id(SysAcc.receivable), debit: net, partyType: PartyType.shop, partyId: shopId),
      VoucherLine(accountId: _id(SysAcc.sales), credit: net),
      VoucherLine(accountId: _id(SysAcc.cogs), debit: cost),
      VoucherLine(accountId: _id(SysAcc.inventory), credit: cost),
    ]);
  }

  Future<void> postSaleReturn({
    required String refId,
    required String shopId,
    required double amount,
    required double freshCost,
    required String narration,
  }) async {
    await post(type: VoucherType.saleReturn, refId: refId, narration: narration, lines: [
      VoucherLine(accountId: _id(SysAcc.salesReturn), debit: amount),
      VoucherLine(accountId: _id(SysAcc.receivable), credit: amount, partyType: PartyType.shop, partyId: shopId),
      VoucherLine(accountId: _id(SysAcc.inventory), debit: freshCost),
      VoucherLine(accountId: _id(SysAcc.cogs), credit: freshCost),
    ]);
  }

  /// Recovery slip approval: cash in, khata credited per shop, short/excess recorded.
  Future<void> postRecovery({
    required String refId,
    required String salesmanId,
    required Map<String, double> shopAmounts,
    required double cashReceived,
    required String narration,
  }) async {
    final total = shopAmounts.values.fold(0.0, (s, v) => s + v);
    final diff = total - cashReceived; // + short, - excess
    final lines = <VoucherLine>[
      VoucherLine(accountId: _id(SysAcc.cash), debit: cashReceived, memo: 'Cash received'),
      for (final e in shopAmounts.entries)
        VoucherLine(
          accountId: _id(SysAcc.receivable),
          credit: e.value,
          partyType: PartyType.shop,
          partyId: e.key,
          memo: 'Recovery',
        ),
    ];
    if (diff > 0.009) {
      lines.add(VoucherLine(
        accountId: _id(SysAcc.salesmanRecv),
        debit: diff,
        partyType: PartyType.salesman,
        partyId: salesmanId,
        memo: 'Cash short',
      ));
    } else if (diff < -0.009) {
      lines.add(VoucherLine(accountId: _id(SysAcc.otherIncome), credit: -diff, memo: 'Cash excess'));
    }
    await post(type: VoucherType.recovery, refId: refId, narration: narration, lines: lines);
  }

  Future<void> postStockAdjust({required String refId, required double value, required String narration}) async {
    if (value.abs() < 0.01) return;
    final loss = value < 0;
    await post(type: VoucherType.stockAdjust, refId: refId, narration: narration, lines: [
      VoucherLine(accountId: _id(SysAcc.stockLoss), debit: loss ? -value : 0, credit: loss ? 0 : value),
      VoucherLine(accountId: _id(SysAcc.inventory), debit: loss ? 0 : value, credit: loss ? -value : 0),
    ]);
  }

  Future<void> postCommission({required String salesmanId, required double amount, required String payFrom, String narration = ''}) async {
    await expense(
      expenseAccountId: _id(SysAcc.commission),
      payFromAccountId: payFrom,
      amount: amount,
      narration: narration,
      partyType: PartyType.salesman,
      partyId: salesmanId,
    );
  }
}
