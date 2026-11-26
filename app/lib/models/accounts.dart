import 'base_model.dart';

enum AccountType { asset, liability, equity, income, expense }

extension AccountTypeX on AccountType {
  String get label => const {
        AccountType.asset: 'Asset',
        AccountType.liability: 'Liability',
        AccountType.equity: 'Equity',
        AccountType.income: 'Income',
        AccountType.expense: 'Expense',
      }[this]!;

  /// Debit-normal accounts
  bool get debitNormal => this == AccountType.asset || this == AccountType.expense;
}

/// System account keys used for automatic postings.
class SysAcc {
  static const cash = 'cash';
  static const bank = 'bank';
  static const receivable = 'receivable';
  static const salesmanRecv = 'salesmanRecv';
  static const inventory = 'inventory';
  static const payable = 'payable';
  static const capital = 'capital';
  static const sales = 'sales';
  static const otherIncome = 'otherIncome';
  static const salesReturn = 'salesReturn';
  static const cogs = 'cogs';
  static const stockLoss = 'stockLoss';
  static const commission = 'commission';
  static const fuel = 'fuel';
  static const vehicle = 'vehicle';
  static const rent = 'rent';
  static const salaries = 'salaries';
  static const otherExp = 'otherExp';
}

class Account implements BaseModel {
  @override
  final String id;
  String code;
  String name;
  AccountType type;
  String sysKey; // empty for user accounts
  bool isBank;
  bool isCash;
  bool active;

  Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.sysKey = '',
    this.isBank = false,
    this.isCash = false,
    this.active = true,
  });

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'type': type.name,
        'sysKey': sysKey,
        'isBank': isBank,
        'isCash': isCash,
        'active': active,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: toS(m['id']),
        code: toS(m['code']),
        name: toS(m['name']),
        type: AccountType.values.firstWhere((t) => t.name == toS(m['type']), orElse: () => AccountType.asset),
        sysKey: toS(m['sysKey']),
        isBank: m['isBank'] == true,
        isCash: m['isCash'] == true,
        active: m['active'] != false,
      );
}

/// Party types for sub-ledgers.
class PartyType {
  static const shop = 'shop';
  static const company = 'company';
  static const salesman = 'salesman';
}

class VoucherLine {
  String accountId;
  double debit;
  double credit;
  String partyType;
  String partyId;
  String memo;

  VoucherLine({
    required this.accountId,
    this.debit = 0,
    this.credit = 0,
    this.partyType = '',
    this.partyId = '',
    this.memo = '',
  });

  Map<String, dynamic> toMap() => {
        'accountId': accountId,
        'debit': debit,
        'credit': credit,
        'partyType': partyType,
        'partyId': partyId,
        'memo': memo,
      };

  factory VoucherLine.fromMap(Map<String, dynamic> m) => VoucherLine(
        accountId: toS(m['accountId']),
        debit: toD(m['debit']),
        credit: toD(m['credit']),
        partyType: toS(m['partyType']),
        partyId: toS(m['partyId']),
        memo: toS(m['memo']),
      );
}

class VoucherType {
  static const sale = 'Sale';
  static const saleReturn = 'Sale Return';
  static const purchase = 'Purchase';
  static const purchaseReturn = 'Purchase Return';
  static const recovery = 'Recovery';
  static const cashPayment = 'Cash Payment';
  static const cashReceipt = 'Cash Receipt';
  static const bank = 'Bank';
  static const journal = 'Journal';
  static const expense = 'Expense';
  static const stockAdjust = 'Stock Adjustment';

  static const manual = [cashPayment, cashReceipt, bank, journal];
}

class Voucher implements BaseModel {
  @override
  final String id;
  int no;
  String type;
  DateTime date;
  String narration;
  List<VoucherLine> lines;
  String refId;
  String userId;
  bool auto;

  Voucher({
    required this.id,
    required this.no,
    required this.type,
    DateTime? date,
    this.narration = '',
    List<VoucherLine>? lines,
    this.refId = '',
    this.userId = '',
    this.auto = false,
  })  : date = date ?? DateTime.now(),
        lines = lines ?? [];

  double get totalDebit => lines.fold(0, (s, l) => s + l.debit);
  double get totalCredit => lines.fold(0, (s, l) => s + l.credit);
  bool get balanced => (totalDebit - totalCredit).abs() < 0.01;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'no': no,
        'type': type,
        'date': date.toIso8601String(),
        'narration': narration,
        'lines': lines.map((e) => e.toMap()).toList(),
        'refId': refId,
        'userId': userId,
        'auto': auto,
      };

  factory Voucher.fromMap(Map<String, dynamic> m) => Voucher(
        id: toS(m['id']),
        no: toI(m['no']),
        type: toS(m['type']),
        date: toDt(m['date']),
        narration: toS(m['narration']),
        lines: toMapList(m['lines']).map(VoucherLine.fromMap).toList(),
        refId: toS(m['refId']),
        userId: toS(m['userId']),
        auto: m['auto'] == true,
      );
}
