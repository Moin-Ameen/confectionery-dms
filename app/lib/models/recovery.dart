import 'base_model.dart';

/// One bill-wise recovery entry (one line of the wasooli slip).
class Recovery implements BaseModel {
  @override
  final String id;
  String salesmanId;
  String shopId;
  String orderId; // bill
  int billNo;
  String khataNo;
  double billAmount; // pending on that bill at time of entry
  double amount; // recovered
  DateTime date;
  String slipId;
  double? lat;
  double? lng;

  Recovery({
    required this.id,
    required this.salesmanId,
    required this.shopId,
    this.orderId = '',
    this.billNo = 0,
    this.khataNo = '',
    this.billAmount = 0,
    this.amount = 0,
    DateTime? date,
    this.slipId = '',
    this.lat,
    this.lng,
  }) : date = date ?? DateTime.now();

  String get status {
    if (amount <= 0) return 'Nil';
    if (amount + 0.001 >= billAmount) return 'Paid';
    return 'Partial';
  }

  double get pending => (billAmount - amount) < 0 ? 0 : billAmount - amount;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'salesmanId': salesmanId,
        'shopId': shopId,
        'orderId': orderId,
        'billNo': billNo,
        'khataNo': khataNo,
        'billAmount': billAmount,
        'amount': amount,
        'date': date.toIso8601String(),
        'slipId': slipId,
        'lat': lat,
        'lng': lng,
      };

  factory Recovery.fromMap(Map<String, dynamic> m) => Recovery(
        id: toS(m['id']),
        salesmanId: toS(m['salesmanId']),
        shopId: toS(m['shopId']),
        orderId: toS(m['orderId']),
        billNo: toI(m['billNo']),
        khataNo: toS(m['khataNo']),
        billAmount: toD(m['billAmount']),
        amount: toD(m['amount']),
        date: toDt(m['date']),
        slipId: toS(m['slipId']),
        lat: m['lat'] == null ? null : toD(m['lat']),
        lng: m['lng'] == null ? null : toD(m['lng']),
      );
}

class SlipStatus {
  static const open = 'open'; // salesman still adding
  static const submitted = 'submitted'; // cash handed, waiting approval
  static const approved = 'approved';
}

/// Digital Bazar Wasooli Slip – one per salesman per day.
class RecoverySlip implements BaseModel {
  @override
  final String id;
  String salesmanId;
  String day; // yyyy-MM-dd
  String status;
  double cashHanded; // declared by salesman
  double cashReceived; // counted by cashier
  String approvedBy;
  DateTime? submittedAt;
  DateTime? approvedAt;
  String note;

  RecoverySlip({
    required this.id,
    required this.salesmanId,
    required this.day,
    this.status = SlipStatus.open,
    this.cashHanded = 0,
    this.cashReceived = 0,
    this.approvedBy = '',
    this.submittedAt,
    this.approvedAt,
    this.note = '',
  });

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'salesmanId': salesmanId,
        'day': day,
        'status': status,
        'cashHanded': cashHanded,
        'cashReceived': cashReceived,
        'approvedBy': approvedBy,
        'submittedAt': submittedAt?.toIso8601String(),
        'approvedAt': approvedAt?.toIso8601String(),
        'note': note,
      };

  factory RecoverySlip.fromMap(Map<String, dynamic> m) => RecoverySlip(
        id: toS(m['id']),
        salesmanId: toS(m['salesmanId']),
        day: toS(m['day']),
        status: toS(m['status']).isEmpty ? SlipStatus.open : toS(m['status']),
        cashHanded: toD(m['cashHanded']),
        cashReceived: toD(m['cashReceived']),
        approvedBy: toS(m['approvedBy']),
        submittedAt: toDtN(m['submittedAt']),
        approvedAt: toDtN(m['approvedAt']),
        note: toS(m['note']),
      );
}
