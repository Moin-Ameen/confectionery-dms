import 'base_model.dart';

class OrderStatus {
  static const pending = 'pending'; // booked, waiting approval
  static const approved = 'approved'; // approved, waiting load sheet
  static const rejected = 'rejected';
  static const loaded = 'loaded'; // on salesman's van
  static const delivered = 'delivered'; // invoiced
  static const cancelled = 'cancelled'; // shop refused at delivery

  static const all = [pending, approved, loaded, delivered, rejected, cancelled];
}

class OrderItem {
  String productId;
  int qty; // pieces
  int freeQty; // scheme free pieces
  double rate; // per piece TP
  double discountPct;

  OrderItem({
    required this.productId,
    this.qty = 0,
    this.freeQty = 0,
    this.rate = 0,
    this.discountPct = 0,
  });

  double get gross => qty * rate;
  double get discount => gross * discountPct / 100;
  double get amount => gross - discount;

  OrderItem copy() =>
      OrderItem(productId: productId, qty: qty, freeQty: freeQty, rate: rate, discountPct: discountPct);

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'qty': qty,
        'freeQty': freeQty,
        'rate': rate,
        'discountPct': discountPct,
      };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: toS(m['productId']),
        qty: toI(m['qty']),
        freeQty: toI(m['freeQty']),
        rate: toD(m['rate']),
        discountPct: toD(m['discountPct']),
      );
}

/// Log of every change a salesman makes before invoicing.
class EditLog {
  String userId;
  DateTime time;
  String text;

  EditLog({required this.userId, required this.text, DateTime? time}) : time = time ?? DateTime.now();

  Map<String, dynamic> toMap() => {'userId': userId, 'time': time.toIso8601String(), 'text': text};

  factory EditLog.fromMap(Map<String, dynamic> m) =>
      EditLog(userId: toS(m['userId']), text: toS(m['text']), time: toDt(m['time']));
}

class SaleOrder implements BaseModel {
  @override
  final String id;
  int no; // order / bill no.
  String shopId;
  String bookerId;
  String salesmanId;
  String routeId;
  DateTime date;
  String status;
  List<OrderItem> items;

  /// Original booked items (kept for comparison after salesman edit)
  List<OrderItem> bookedItems;
  double extraDiscount;
  String notes;
  double? lat;
  double? lng;
  bool creditHold; // exceeded credit limit, needs admin override
  bool creditOverridden;
  String approvedBy;
  String loadSheetId;
  int invoiceNo;
  DateTime? invoicedAt;
  List<EditLog> editLog;

  SaleOrder({
    required this.id,
    required this.no,
    required this.shopId,
    this.bookerId = '',
    this.salesmanId = '',
    this.routeId = '',
    DateTime? date,
    this.status = OrderStatus.pending,
    List<OrderItem>? items,
    List<OrderItem>? bookedItems,
    this.extraDiscount = 0,
    this.notes = '',
    this.lat,
    this.lng,
    this.creditHold = false,
    this.creditOverridden = false,
    this.approvedBy = '',
    this.loadSheetId = '',
    this.invoiceNo = 0,
    this.invoicedAt,
    List<EditLog>? editLog,
  })  : date = date ?? DateTime.now(),
        items = items ?? [],
        bookedItems = bookedItems ?? [],
        editLog = editLog ?? [];

  double get gross => items.fold(0, (s, i) => s + i.gross);
  double get itemDiscount => items.fold(0, (s, i) => s + i.discount);
  double get net => gross - itemDiscount - extraDiscount;
  int get totalPieces => items.fold(0, (s, i) => s + i.qty + i.freeQty);
  bool get isInvoiced => status == OrderStatus.delivered;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'no': no,
        'shopId': shopId,
        'bookerId': bookerId,
        'salesmanId': salesmanId,
        'routeId': routeId,
        'date': date.toIso8601String(),
        'status': status,
        'items': items.map((e) => e.toMap()).toList(),
        'bookedItems': bookedItems.map((e) => e.toMap()).toList(),
        'extraDiscount': extraDiscount,
        'notes': notes,
        'lat': lat,
        'lng': lng,
        'creditHold': creditHold,
        'creditOverridden': creditOverridden,
        'approvedBy': approvedBy,
        'loadSheetId': loadSheetId,
        'invoiceNo': invoiceNo,
        'invoicedAt': invoicedAt?.toIso8601String(),
        'editLog': editLog.map((e) => e.toMap()).toList(),
      };

  factory SaleOrder.fromMap(Map<String, dynamic> m) => SaleOrder(
        id: toS(m['id']),
        no: toI(m['no']),
        shopId: toS(m['shopId']),
        bookerId: toS(m['bookerId']),
        salesmanId: toS(m['salesmanId']),
        routeId: toS(m['routeId']),
        date: toDt(m['date']),
        status: toS(m['status']).isEmpty ? OrderStatus.pending : toS(m['status']),
        items: toMapList(m['items']).map(OrderItem.fromMap).toList(),
        bookedItems: toMapList(m['bookedItems']).map(OrderItem.fromMap).toList(),
        extraDiscount: toD(m['extraDiscount']),
        notes: toS(m['notes']),
        lat: m['lat'] == null ? null : toD(m['lat']),
        lng: m['lng'] == null ? null : toD(m['lng']),
        creditHold: m['creditHold'] == true,
        creditOverridden: m['creditOverridden'] == true,
        approvedBy: toS(m['approvedBy']),
        loadSheetId: toS(m['loadSheetId']),
        invoiceNo: toI(m['invoiceNo']),
        invoicedAt: toDtN(m['invoicedAt']),
        editLog: toMapList(m['editLog']).map(EditLog.fromMap).toList(),
      );
}

class LoadSheet implements BaseModel {
  @override
  final String id;
  int no;
  DateTime date;
  String routeId;
  String salesmanId;
  List<String> orderIds;

  /// productId -> pieces loaded on van
  Map<String, int> items;
  String status; // loaded, closed
  String createdBy;
  DateTime? closedAt;

  LoadSheet({
    required this.id,
    required this.no,
    DateTime? date,
    this.routeId = '',
    required this.salesmanId,
    List<String>? orderIds,
    Map<String, int>? items,
    this.status = 'loaded',
    this.createdBy = '',
    this.closedAt,
  })  : date = date ?? DateTime.now(),
        orderIds = orderIds ?? [],
        items = items ?? {};

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'no': no,
        'date': date.toIso8601String(),
        'routeId': routeId,
        'salesmanId': salesmanId,
        'orderIds': orderIds,
        'items': items,
        'status': status,
        'createdBy': createdBy,
        'closedAt': closedAt?.toIso8601String(),
      };

  factory LoadSheet.fromMap(Map<String, dynamic> m) => LoadSheet(
        id: toS(m['id']),
        no: toI(m['no']),
        date: toDt(m['date']),
        routeId: toS(m['routeId']),
        salesmanId: toS(m['salesmanId']),
        orderIds: toSList(m['orderIds']),
        items: (m['items'] is Map)
            ? (m['items'] as Map).map((k, v) => MapEntry(k.toString(), toI(v)))
            : <String, int>{},
        status: toS(m['status']).isEmpty ? 'loaded' : toS(m['status']),
        createdBy: toS(m['createdBy']),
        closedAt: toDtN(m['closedAt']),
      );
}
