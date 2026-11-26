import 'base_model.dart';

class Company implements BaseModel {
  @override
  final String id;
  String name;
  String phone;
  String address;
  bool active;

  Company({required this.id, required this.name, this.phone = '', this.address = '', this.active = true});

  @override
  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'phone': phone, 'address': address, 'active': active};

  factory Company.fromMap(Map<String, dynamic> m) => Company(
        id: toS(m['id']),
        name: toS(m['name']),
        phone: toS(m['phone']),
        address: toS(m['address']),
        active: m['active'] != false,
      );
}

const productCategories = ['Candy', 'Chocolate', 'Biscuit', 'Gum', 'Other'];

/// All quantities are stored in PIECES. Carton/box are for display & entry.
class Product implements BaseModel {
  @override
  final String id;
  String name;
  String companyId;
  String category;
  int piecesPerBox;
  int boxesPerCarton;

  /// Per-piece prices
  double costPrice; // purchase price
  double tp; // trade price (sale to shop)
  double rp; // retail price (printed)
  int lowStockPieces;
  bool active;

  Product({
    required this.id,
    required this.name,
    required this.companyId,
    this.category = 'Candy',
    this.piecesPerBox = 1,
    this.boxesPerCarton = 1,
    this.costPrice = 0,
    this.tp = 0,
    this.rp = 0,
    this.lowStockPieces = 0,
    this.active = true,
  });

  int get piecesPerCarton => piecesPerBox * boxesPerCarton;

  /// Converts pieces to "C-B-P" label e.g. 2 ctn 3 box 5 pcs
  String packLabel(num pieces) {
    var p = pieces.round();
    final neg = p < 0;
    p = p.abs();
    final ctn = piecesPerCarton > 0 ? p ~/ piecesPerCarton : 0;
    p -= ctn * piecesPerCarton;
    final box = piecesPerBox > 0 ? p ~/ piecesPerBox : 0;
    p -= box * piecesPerBox;
    final parts = <String>[];
    if (ctn > 0) parts.add('$ctn ctn');
    if (box > 0) parts.add('$box box');
    if (p > 0 || parts.isEmpty) parts.add('$p pcs');
    return (neg ? '-' : '') + parts.join(' ');
  }

  int toPieces({int cartons = 0, int boxes = 0, int pieces = 0}) =>
      cartons * piecesPerCarton + boxes * piecesPerBox + pieces;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'companyId': companyId,
        'category': category,
        'piecesPerBox': piecesPerBox,
        'boxesPerCarton': boxesPerCarton,
        'costPrice': costPrice,
        'tp': tp,
        'rp': rp,
        'lowStockPieces': lowStockPieces,
        'active': active,
      };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: toS(m['id']),
        name: toS(m['name']),
        companyId: toS(m['companyId']),
        category: toS(m['category']).isEmpty ? 'Candy' : toS(m['category']),
        piecesPerBox: toI(m['piecesPerBox']) <= 0 ? 1 : toI(m['piecesPerBox']),
        boxesPerCarton: toI(m['boxesPerCarton']) <= 0 ? 1 : toI(m['boxesPerCarton']),
        costPrice: toD(m['costPrice']),
        tp: toD(m['tp']),
        rp: toD(m['rp']),
        lowStockPieces: toI(m['lowStockPieces']),
        active: m['active'] != false,
      );
}

/// Locations used by stock movements.
class StockLoc {
  static const warehouse = 'warehouse';
  static const damaged = 'damaged';

  /// Van stock location for a salesman = 'van:<userId>'
  static String van(String userId) => 'van:$userId';
  static bool isVan(String loc) => loc.startsWith('van:');
  static String vanUser(String loc) => loc.substring(4);
}

/// Every stock change is a movement (append-only ledger). Stock = sum(qty).
class StockMove implements BaseModel {
  @override
  final String id;
  String productId;
  String location;
  int qty; // + in, - out (pieces)
  String batchNo;
  DateTime? expiry;
  String type; // purchase, purchaseReturn, loadOut, loadIn, sale, saleReturn, adjust, opening
  String refId;
  String note;
  String userId;
  DateTime date;

  StockMove({
    required this.id,
    required this.productId,
    required this.location,
    required this.qty,
    this.batchNo = '',
    this.expiry,
    required this.type,
    this.refId = '',
    this.note = '',
    this.userId = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'location': location,
        'qty': qty,
        'batchNo': batchNo,
        'expiry': expiry?.toIso8601String(),
        'type': type,
        'refId': refId,
        'note': note,
        'userId': userId,
        'date': date.toIso8601String(),
      };

  factory StockMove.fromMap(Map<String, dynamic> m) => StockMove(
        id: toS(m['id']),
        productId: toS(m['productId']),
        location: toS(m['location']),
        qty: toI(m['qty']),
        batchNo: toS(m['batchNo']),
        expiry: toDtN(m['expiry']),
        type: toS(m['type']),
        refId: toS(m['refId']),
        note: toS(m['note']),
        userId: toS(m['userId']),
        date: toDt(m['date']),
      );
}

class PurchaseItem {
  String productId;
  int qty; // pieces
  int bonus; // free pieces
  double rate; // per piece
  String batchNo;
  DateTime? expiry;

  PurchaseItem({
    required this.productId,
    this.qty = 0,
    this.bonus = 0,
    this.rate = 0,
    this.batchNo = '',
    this.expiry,
  });

  double get amount => qty * rate;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'qty': qty,
        'bonus': bonus,
        'rate': rate,
        'batchNo': batchNo,
        'expiry': expiry?.toIso8601String(),
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
        productId: toS(m['productId']),
        qty: toI(m['qty']),
        bonus: toI(m['bonus']),
        rate: toD(m['rate']),
        batchNo: toS(m['batchNo']),
        expiry: toDtN(m['expiry']),
      );
}

class Purchase implements BaseModel {
  @override
  final String id;
  int no;
  String companyId;
  DateTime date;
  bool isReturn;
  List<PurchaseItem> items;
  double discount;
  String note;
  String userId;

  Purchase({
    required this.id,
    required this.no,
    required this.companyId,
    DateTime? date,
    this.isReturn = false,
    List<PurchaseItem>? items,
    this.discount = 0,
    this.note = '',
    this.userId = '',
  })  : date = date ?? DateTime.now(),
        items = items ?? [];

  double get gross => items.fold(0, (s, i) => s + i.amount);
  double get net => gross - discount;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'no': no,
        'companyId': companyId,
        'date': date.toIso8601String(),
        'isReturn': isReturn,
        'items': items.map((e) => e.toMap()).toList(),
        'discount': discount,
        'note': note,
        'userId': userId,
      };

  factory Purchase.fromMap(Map<String, dynamic> m) => Purchase(
        id: toS(m['id']),
        no: toI(m['no']),
        companyId: toS(m['companyId']),
        date: toDt(m['date']),
        isReturn: m['isReturn'] == true,
        items: toMapList(m['items']).map(PurchaseItem.fromMap).toList(),
        discount: toD(m['discount']),
        note: toS(m['note']),
        userId: toS(m['userId']),
      );
}
