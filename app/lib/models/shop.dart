import 'base_model.dart';

const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class RouteModel implements BaseModel {
  @override
  final String id;
  String name;
  String area;
  List<String> days; // e.g. ['Mon','Thu']
  bool active;

  RouteModel({required this.id, required this.name, this.area = '', List<String>? days, this.active = true})
      : days = days ?? [];

  bool isToday() => days.contains(weekDays[DateTime.now().weekday - 1]);

  @override
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'area': area, 'days': days, 'active': active};

  factory RouteModel.fromMap(Map<String, dynamic> m) => RouteModel(
        id: toS(m['id']),
        name: toS(m['name']),
        area: toS(m['area']),
        days: toSList(m['days']),
        active: m['active'] != false,
      );
}

class Shop implements BaseModel {
  @override
  final String id;
  String name;
  String owner;
  String phone;
  String area;
  String khataNo;
  String routeId;
  double creditLimit;
  double? lat;
  double? lng;
  bool active;
  DateTime createdAt;

  Shop({
    required this.id,
    required this.name,
    this.owner = '',
    this.phone = '',
    this.area = '',
    this.khataNo = '',
    this.routeId = '',
    this.creditLimit = 0,
    this.lat,
    this.lng,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner': owner,
        'phone': phone,
        'area': area,
        'khataNo': khataNo,
        'routeId': routeId,
        'creditLimit': creditLimit,
        'lat': lat,
        'lng': lng,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Shop.fromMap(Map<String, dynamic> m) => Shop(
        id: toS(m['id']),
        name: toS(m['name']),
        owner: toS(m['owner']),
        phone: toS(m['phone']),
        area: toS(m['area']),
        khataNo: toS(m['khataNo']),
        routeId: toS(m['routeId']),
        creditLimit: toD(m['creditLimit']),
        lat: m['lat'] == null ? null : toD(m['lat']),
        lng: m['lng'] == null ? null : toD(m['lng']),
        active: m['active'] != false,
        createdAt: toDt(m['createdAt']),
      );
}

enum SchemeType { free, slab, discount }

class Scheme implements BaseModel {
  @override
  final String id;
  String name;
  SchemeType type;

  /// Empty = applies to all products
  String productId;
  int minQty; // pieces
  int freeQty; // for free type: per minQty
  double percent; // for slab / discount
  bool active;

  Scheme({
    required this.id,
    required this.name,
    this.type = SchemeType.free,
    this.productId = '',
    this.minQty = 0,
    this.freeQty = 0,
    this.percent = 0,
    this.active = true,
  });

  String get description {
    switch (type) {
      case SchemeType.free:
        return 'Buy $minQty get $freeQty free';
      case SchemeType.slab:
        return '${percent.toStringAsFixed(1)}% off on $minQty+ pcs';
      case SchemeType.discount:
        return '${percent.toStringAsFixed(1)}% trade discount';
    }
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'productId': productId,
        'minQty': minQty,
        'freeQty': freeQty,
        'percent': percent,
        'active': active,
      };

  factory Scheme.fromMap(Map<String, dynamic> m) => Scheme(
        id: toS(m['id']),
        name: toS(m['name']),
        type: SchemeType.values.firstWhere((t) => t.name == toS(m['type']), orElse: () => SchemeType.free),
        productId: toS(m['productId']),
        minQty: toI(m['minQty']),
        freeQty: toI(m['freeQty']),
        percent: toD(m['percent']),
        active: m['active'] != false,
      );
}
