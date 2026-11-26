import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

/// Every entity stored in the local DB implements this.
abstract class BaseModel {
  String get id;
  Map<String, dynamic> toMap();
}

double toD(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int toI(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime toDt(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

DateTime? toDtN(dynamic v) {
  if (v == null || v.toString().isEmpty) return null;
  return DateTime.tryParse(v.toString());
}

String toS(dynamic v) => v == null ? '' : v.toString();

List<String> toSList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

List<Map<String, dynamic>> toMapList(dynamic v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : <Map<String, dynamic>>[];

/// Day key in yyyy-MM-dd, used for daily grouping.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
