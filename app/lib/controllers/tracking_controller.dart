import 'dart:async';

import '../config/app_config.dart';
import '../models/base_model.dart';
import '../models/tracking.dart';
import '../services/gps_service.dart';
import '../services/local_db.dart';
import '../services/settings_service.dart';
import 'base_controller.dart';

class TrackingController extends BaseController {
  Timer? _timer;
  final _gps = GpsService.instance;
  final _s = SettingsService.instance;

  bool get onDuty => _s.onDuty;
  DateTime? lastPingAt;

  /// Start / stop duty tracking (bookers & salesmen).
  Future<String?> setDuty(bool on) async {
    if (on) {
      final ok = await _gps.ensurePermission();
      if (!ok) return 'Please turn on location and allow permission';
      _s.onDuty = true;
      await log('duty-on', 'GPS');
      _start();
      await ping();
    } else {
      _s.onDuty = false;
      _timer?.cancel();
      _timer = null;
      await log('duty-off', 'GPS');
    }
    notifyListeners();
    return null;
  }

  /// Call on app start to resume tracking if duty was on.
  void resume() {
    if (_s.onDuty && Session.user != null && Session.isField) _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.gpsInterval, (_) => ping());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> ping() async {
    if (Session.user == null) return;
    final pos = await _gps.current();
    if (pos == null) return;
    await db.put(
      Col.pings,
      LocationPing(id: newId(), userId: Session.userId, lat: pos.latitude, lng: pos.longitude).toMap(),
    );
    lastPingAt = DateTime.now();
    notifyListeners();
  }

  /// GPS check-in on order / recovery / visit. Returns (lat, lng) or null.
  Future<(double, double)?> checkIn(String kind, String refId, String label) async {
    final pos = await _gps.current();
    if (pos == null) return null;
    await db.put(
      Col.pings,
      LocationPing(
        id: newId(),
        userId: Session.userId,
        lat: pos.latitude,
        lng: pos.longitude,
        kind: kind,
        refId: refId,
        label: label,
      ).toMap(),
    );
    return (pos.latitude, pos.longitude);
  }

  List<LocationPing> get pings => db.all(Col.pings).map(LocationPing.fromMap).toList();

  /// Latest known position of each user (for the live map).
  Map<String, LocationPing> latestByUser() {
    final out = <String, LocationPing>{};
    for (final p in pings) {
      final cur = out[p.userId];
      if (cur == null || p.time.isAfter(cur.time)) out[p.userId] = p;
    }
    return out;
  }

  List<LocationPing> history(String userId, DateTime day) {
    final k = dayKey(day);
    final l = pings.where((p) => p.userId == userId && dayKey(p.time) == k).toList();
    l.sort((a, b) => a.time.compareTo(b.time));
    return l;
  }

  double distanceKm(List<LocationPing> path) {
    var d = 0.0;
    for (var i = 1; i < path.length; i++) {
      d += GpsService.distanceMeters(path[i - 1].lat, path[i - 1].lng, path[i].lat, path[i].lng);
    }
    return d / 1000;
  }

  // ---------------- Activity log ----------------
  List<ActivityLog> logs({String? userId, DateTime? day}) {
    var l = db.all(Col.logs).map(ActivityLog.fromMap);
    if (userId != null && userId.isNotEmpty) l = l.where((x) => x.userId == userId);
    if (day != null) {
      final k = dayKey(day);
      l = l.where((x) => dayKey(x.time) == k);
    }
    final list = l.toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
