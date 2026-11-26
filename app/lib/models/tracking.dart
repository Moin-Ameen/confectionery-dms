import 'base_model.dart';

class PingKind {
  static const track = 'track';
  static const orderCheckIn = 'order';
  static const recoveryCheckIn = 'recovery';
  static const visit = 'visit';
}

class LocationPing implements BaseModel {
  @override
  final String id;
  String userId;
  double lat;
  double lng;
  DateTime time;
  String kind;
  String refId; // order / recovery / shop id
  String label;

  LocationPing({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    DateTime? time,
    this.kind = PingKind.track,
    this.refId = '',
    this.label = '',
  }) : time = time ?? DateTime.now();

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'lat': lat,
        'lng': lng,
        'time': time.toIso8601String(),
        'kind': kind,
        'refId': refId,
        'label': label,
      };

  factory LocationPing.fromMap(Map<String, dynamic> m) => LocationPing(
        id: toS(m['id']),
        userId: toS(m['userId']),
        lat: toD(m['lat']),
        lng: toD(m['lng']),
        time: toDt(m['time']),
        kind: toS(m['kind']).isEmpty ? PingKind.track : toS(m['kind']),
        refId: toS(m['refId']),
        label: toS(m['label']),
      );
}

class ActivityLog implements BaseModel {
  @override
  final String id;
  String userId;
  String action; // created / edited / deleted / approved / rejected / login ...
  String entity; // Order, Shop, Product ...
  String refId;
  String details;
  DateTime time;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.entity,
    this.refId = '',
    this.details = '',
    DateTime? time,
  }) : time = time ?? DateTime.now();

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'action': action,
        'entity': entity,
        'refId': refId,
        'details': details,
        'time': time.toIso8601String(),
      };

  factory ActivityLog.fromMap(Map<String, dynamic> m) => ActivityLog(
        id: toS(m['id']),
        userId: toS(m['userId']),
        action: toS(m['action']),
        entity: toS(m['entity']),
        refId: toS(m['refId']),
        details: toS(m['details']),
        time: toDt(m['time']),
      );
}
