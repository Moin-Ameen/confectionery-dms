import 'base_model.dart';

const returnConditions = ['fresh', 'damaged', 'expired'];

class ReturnItem {
  String productId;
  int qty;
  String condition; // fresh / damaged / expired
  double rate;

  ReturnItem({required this.productId, this.qty = 0, this.condition = 'fresh', this.rate = 0});

  double get amount => qty * rate;

  Map<String, dynamic> toMap() => {'productId': productId, 'qty': qty, 'condition': condition, 'rate': rate};

  factory ReturnItem.fromMap(Map<String, dynamic> m) => ReturnItem(
        productId: toS(m['productId']),
        qty: toI(m['qty']),
        condition: toS(m['condition']).isEmpty ? 'fresh' : toS(m['condition']),
        rate: toD(m['rate']),
      );
}

class SaleReturn implements BaseModel {
  @override
  final String id;
  int no;
  String shopId;
  String userId; // entered by
  DateTime date;
  List<ReturnItem> items;
  String status; // pending / approved / rejected
  String approvedBy;
  DateTime? approvedAt;
  String note;

  SaleReturn({
    required this.id,
    required this.no,
    required this.shopId,
    required this.userId,
    DateTime? date,
    List<ReturnItem>? items,
    this.status = 'pending',
    this.approvedBy = '',
    this.approvedAt,
    this.note = '',
  })  : date = date ?? DateTime.now(),
        items = items ?? [];

  double get total => items.fold(0, (s, i) => s + i.amount);

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'no': no,
        'shopId': shopId,
        'userId': userId,
        'date': date.toIso8601String(),
        'items': items.map((e) => e.toMap()).toList(),
        'status': status,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
        'note': note,
      };

  factory SaleReturn.fromMap(Map<String, dynamic> m) => SaleReturn(
        id: toS(m['id']),
        no: toI(m['no']),
        shopId: toS(m['shopId']),
        userId: toS(m['userId']),
        date: toDt(m['date']),
        items: toMapList(m['items']).map(ReturnItem.fromMap).toList(),
        status: toS(m['status']).isEmpty ? 'pending' : toS(m['status']),
        approvedBy: toS(m['approvedBy']),
        approvedAt: toDtN(m['approvedAt']),
        note: toS(m['note']),
      );
}
